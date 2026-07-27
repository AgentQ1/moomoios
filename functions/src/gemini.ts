/**
 * Shared, reusable Gemini client wrapper.
 *
 * All Gemini access in the backend goes through this module — there is no other
 * place the API key is read, and the key is NEVER shipped to the client.
 */
import { GoogleGenAI } from "@google/genai";

const TEXT_MODEL = "gemini-2.5-flash";
const IMAGE_MODEL = "gemini-2.5-flash-image";

/** One client per process, created lazily from the injected secret. */
let client: GoogleGenAI | null = null;
function ai(apiKey: string): GoogleGenAI {
  if (!client) client = new GoogleGenAI({ apiKey });
  return client;
}

/** Upstream statuses that mean "busy, try again" rather than "your request is wrong". */
const RETRYABLE_STATUS = new Set([429, 500, 502, 503, 504]);
const MAX_ATTEMPTS = 4;

/**
 * Dig the HTTP status out of a @google/genai failure. Its ServerError carries
 * the code only inside the message (`got status: 503 Service Unavailable. {…}`),
 * so parse that first and fall back to a numeric `status` field.
 */
function statusOf(err: unknown): number | null {
  const message = err instanceof Error ? err.message : String(err);
  const parsed = /got status:\s*(\d{3})/.exec(message);
  if (parsed) return Number(parsed[1]);
  const status = (err as { status?: unknown } | null)?.status;
  return typeof status === "number" ? status : null;
}

const sleep = (ms: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Gemini returns a transient 503 ("this model is currently experiencing high
 * demand") often enough that a single unguarded call surfaces as a user-facing
 * failure. Retry only the statuses that indicate upstream capacity, with
 * exponential backoff plus jitter so retries don't align across instances.
 * Worst case adds ~3.5s of waiting, well inside the 60s callable timeout.
 */
async function withRetry<T>(label: string, call: () => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await call();
    } catch (err) {
      const status = statusOf(err);
      if (attempt >= MAX_ATTEMPTS || status === null || !RETRYABLE_STATUS.has(status)) throw err;
      const backoffMs = 500 * 2 ** (attempt - 1) + Math.floor(Math.random() * 250);
      console.warn({ message: "gemini retry", label, status, attempt, backoffMs });
      await sleep(backoffMs);
    }
  }
}

export interface GeneratedImage {
  data: Buffer;
  mimeType: string;
}

/** An image attached to a chat message, sent inline as base64. */
export interface InlineImage {
  data: string; // base64 (no data: prefix)
  mimeType: string;
}

/** One prior conversation turn, already validated by the caller. */
export interface ChatTurn {
  role: "user" | "assistant";
  text: string;
}

/**
 * Chat generation, optionally multimodal. The system prompt travels as a real
 * `systemInstruction` (not pasted into the conversation text), history turns
 * map to role-tagged contents, and attached images ride in the SAME final
 * user turn as the message text — the multimodal input structure Gemini
 * expects for image understanding. An image URL or path embedded in prompt
 * text would give the model no visual access.
 */
export async function chat(
  apiKey: string,
  args: {
    system: string;
    history: ChatTurn[];
    message: string;
    images: InlineImage[];
  }
): Promise<string> {
  const contents = [
    ...args.history.map((turn) => ({
      role: turn.role === "assistant" ? ("model" as const) : ("user" as const),
      parts: [{ text: turn.text }],
    })),
    {
      role: "user" as const,
      parts: [
        ...args.images.map((img) => ({ inlineData: { data: img.data, mimeType: img.mimeType } })),
        { text: args.message },
      ],
    },
  ];
  const res = await withRetry("chat", () =>
    ai(apiKey).models.generateContent({
      model: TEXT_MODEL,
      contents,
      config: { systemInstruction: args.system },
    })
  );
  const text = res.text?.trim();
  if (!text) throw new Error("Empty text response from Gemini");
  return text;
}

/** Plain single-prompt text generation (utility calls: text edit, memory). */
export async function generateText(apiKey: string, prompt: string): Promise<string> {
  const res = await withRetry("generateText", () =>
    ai(apiKey).models.generateContent({
      model: TEXT_MODEL,
      contents: prompt,
    })
  );
  const text = res.text?.trim();
  if (!text) throw new Error("Empty text response from Gemini");
  return text;
}

/**
 * Rewrite/regenerate existing text given a change instruction.
 * Reuses the same text model with a focused prompt.
 */
export function editText(apiKey: string, current: string, instruction: string): Promise<string> {
  const prompt =
    `Revise the following text according to the instruction. ` +
    `Return ONLY the revised text with no preamble.\n\n` +
    `INSTRUCTION: ${instruction}\n\nTEXT:\n${current}`;
  return generateText(apiKey, prompt);
}

// ---- user memory ----------------------------------------------------------

export interface MemoryProfile {
  summary: string;
  preferences: string[];
  importantFacts: string[];
  projects: string[];
}

/**
 * Merge a new conversation into the user's long-term memory profile and return
 * the updated profile. Privacy-aware: the model is told not to store sensitive
 * data unless the user explicitly asked it to remember it.
 */
export async function extractMemory(
  apiKey: string,
  existing: MemoryProfile,
  conversation: string
): Promise<MemoryProfile> {
  const prompt =
    `You maintain a concise long-term memory profile about a user to personalize future help. ` +
    `Update the EXISTING profile using the NEW conversation. Keep it short and factual, merge new info, and avoid duplicates. ` +
    `Do NOT store sensitive data (passwords, financial or credit-card numbers, government IDs, health details, exact home address) unless the user explicitly asked you to remember it. ` +
    `Return ONLY valid minified JSON with exactly these keys: ` +
    `summary (string, <= 600 chars), preferences (string[]), importantFacts (string[]), projects (string[]). ` +
    `No markdown fences, no preamble.\n\n` +
    `EXISTING PROFILE JSON:\n${JSON.stringify(existing)}\n\n` +
    `NEW CONVERSATION:\n${conversation}`;
  const raw = await generateText(apiKey, prompt);
  return parseMemory(raw, existing);
}

/** Parse the model's JSON memory, falling back to the existing profile on error. */
function parseMemory(raw: string, fallback: MemoryProfile): MemoryProfile {
  try {
    const cleaned = raw
      .trim()
      .replace(/^```(?:json)?/i, "")
      .replace(/```$/, "")
      .trim();
    const obj = JSON.parse(cleaned) as Record<string, unknown>;
    const toStrArray = (v: unknown): string[] =>
      Array.isArray(v)
        ? v.filter((x): x is string => typeof x === "string").map((x) => x.trim()).filter(Boolean).slice(0, 50)
        : [];
    return {
      summary: typeof obj.summary === "string" ? obj.summary.slice(0, 600) : fallback.summary,
      preferences: toStrArray(obj.preferences),
      importantFacts: toStrArray(obj.importantFacts),
      projects: toStrArray(obj.projects),
    };
  } catch {
    return fallback;
  }
}

/** Pull the first inline image out of a Gemini response. */
function extractImage(res: { candidates?: Array<{ content?: { parts?: Array<{ inlineData?: { data?: string; mimeType?: string } }> } }> }): GeneratedImage {
  const parts = res.candidates?.[0]?.content?.parts ?? [];
  for (const part of parts) {
    if (part.inlineData?.data) {
      return {
        data: Buffer.from(part.inlineData.data, "base64"),
        mimeType: part.inlineData.mimeType ?? "image/png",
      };
    }
  }
  throw new Error("No image returned from Gemini");
}

/** Text -> image. */
export async function generateImage(apiKey: string, prompt: string): Promise<GeneratedImage> {
  const res = await withRetry("generateImage", () =>
    ai(apiKey).models.generateContent({
      model: IMAGE_MODEL,
      contents: prompt,
    })
  );
  return extractImage(res);
}

/** Image + instruction -> edited image. */
export async function editImage(
  apiKey: string,
  source: { data: Buffer; mimeType: string },
  instruction: string
): Promise<GeneratedImage> {
  const res = await withRetry("editImage", () =>
    ai(apiKey).models.generateContent({
      model: IMAGE_MODEL,
      contents: [
        { inlineData: { data: source.data.toString("base64"), mimeType: source.mimeType } },
        { text: instruction },
      ],
    })
  );
  return extractImage(res);
}
