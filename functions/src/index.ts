/**
 * Moomo iOS — Cloud Functions (callable).
 *
 * Four callable functions: generateText, generateImage, editGeneratedImage,
 * editGeneratedText. Callable functions automatically verify the Firebase Auth
 * token and expose the decoded identity as `request.auth` — so every function
 * here is authenticated by construction. Guests (anonymous auth) are allowed but
 * rate-limited. The Gemini key is injected as a secret and never reaches the client.
 */
import { onCall, HttpsError, CallableRequest, CallableOptions } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
import * as gemini from "./gemini";

admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// Daily generation caps (per user, resets each calendar day, UTC).
const GUEST_DAILY_LIMIT = 5;
const USER_DAILY_LIMIT = 100;
const MAX_PROMPT_LEN = 4000;
const MAX_HISTORY = 20;
const MAX_MEMORY_LEN = 4000;

const BASE_SYSTEM =
  "You are Moomo, an intelligent AI assistant. Provide accurate, comprehensive, and well-structured " +
  "responses. Be direct and to the point while remaining helpful and informative.";
const MEMORY_DIRECTIVE =
  "Use memory only to personalize helpful responses. Do not expose hidden memory unless the user asks.";

type GenType = "text" | "image" | "image_edit" | "text_edit";

interface HistoryTurn {
  role: "user" | "assistant";
  text: string;
}

// ---- shared helpers -------------------------------------------------------

interface Caller {
  uid: string;
  isGuest: boolean;
}

/** Callable already verified the token; this just narrows + reports guest status. */
function requireAuth(request: CallableRequest): Caller {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const provider = request.auth.token.firebase?.sign_in_provider;
  return { uid: request.auth.uid, isGuest: provider === "anonymous" };
}

/** Validate a required, non-empty, bounded string. */
function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `"${field}" is required.`);
  }
  if (value.length > MAX_PROMPT_LEN) {
    throw new HttpsError("invalid-argument", `"${field}" is too long.`);
  }
  return value.trim();
}

/** Coerce client-supplied conversation history into a safe, bounded shape. */
function sanitizeHistory(raw: unknown): HistoryTurn[] {
  if (!Array.isArray(raw)) return [];
  const turns: HistoryTurn[] = [];
  for (const item of raw.slice(-MAX_HISTORY)) {
    if (item && typeof item === "object") {
      const obj = item as Record<string, unknown>;
      const role: HistoryTurn["role"] = obj.role === "assistant" ? "assistant" : "user";
      const text = typeof obj.text === "string" ? obj.text.trim() : "";
      if (text.length > 0) turns.push({ role, text: text.slice(0, MAX_PROMPT_LEN) });
    }
  }
  return turns;
}

/** Assemble the full chat prompt: system instruction + memory + history + message. */
function buildChatPrompt(args: {
  message: string;
  history: HistoryTurn[];
  memory: string;
  language: string;
  languageCode: string;
}): string {
  const { message, history, memory, language, languageCode } = args;
  const sections: string[] = [BASE_SYSTEM];

  if (languageCode && languageCode !== "en" && language) {
    sections.push(
      `CRITICAL: The user has selected ${language} as their preferred language. ` +
      `You MUST respond entirely in ${language}. Never respond in English unless the user explicitly asks for translation.`
    );
  }

  sections.push(MEMORY_DIRECTIVE);

  if (memory) {
    sections.push(`User memory (for personalization only):\n${memory.slice(0, MAX_MEMORY_LEN)}`);
  }

  let convo = "";
  for (const turn of history) {
    convo += `${turn.role === "user" ? "User" : "Assistant"}: ${turn.text}\n`;
  }
  convo += `User: ${message}\nAssistant:`;

  return `${sections.join("\n\n")}\n\n${convo}`;
}

/** Atomic per-user daily rate limit using a usage/{uid} counter document. */
async function enforceLimit(caller: Caller): Promise<void> {
  const limit = caller.isGuest ? GUEST_DAILY_LIMIT : USER_DAILY_LIMIT;
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
  const ref = db.collection("usage").doc(caller.uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const count = data?.date === today ? (data.count as number) : 0;
    if (count >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        caller.isGuest
          ? "Guest daily limit reached. Sign in to continue."
          : "Daily generation limit reached. Try again tomorrow."
      );
    }
    tx.set(ref, { date: today, count: count + 1 }, { merge: true });
  });
}

/** Append a history record and return its id + timestamp. */
async function saveHistory(entry: {
  userId: string;
  prompt: string;
  type: GenType;
  output: string;
}): Promise<{ id: string; createdAt: string }> {
  const createdAt = admin.firestore.FieldValue.serverTimestamp();
  const ref = await db.collection("generations").add({ ...entry, createdAt });
  return { id: ref.id, createdAt: new Date().toISOString() };
}

/** Upload an image to Storage and return a download URL + its path.
 *  Uses a Firebase download token (no IAM signBlob permission required). */
async function uploadImage(uid: string, img: gemini.GeneratedImage): Promise<{ url: string; path: string }> {
  const ext = img.mimeType.includes("jpeg") ? "jpg" : "png";
  const path = `generations/${uid}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const token = randomUUID();
  const file = bucket.file(path);
  await file.save(img.data, {
    contentType: img.mimeType,
    resumable: false,
    metadata: { metadata: { firebaseStorageDownloadTokens: token } },
  });
  const url =
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(path)}?alt=media&token=${token}`;
  return { url, path };
}

/** Download a previously generated image the caller owns. */
async function downloadOwnedImage(uid: string, path: string): Promise<gemini.GeneratedImage> {
  if (!path.startsWith(`generations/${uid}/`)) {
    throw new HttpsError("permission-denied", "Image not found.");
  }
  const file = bucket.file(path);
  const [exists] = await file.exists();
  if (!exists) throw new HttpsError("not-found", "Image not found.");
  const [data] = await file.download();
  const [meta] = await file.getMetadata();
  return { data, mimeType: meta.contentType ?? "image/png" };
}

/** Wrap a handler so unexpected errors never leak stack traces to the client. */
function safe<T>(fn: (request: CallableRequest) => Promise<T>) {
  return async (request: CallableRequest): Promise<T> => {
    try {
      return await fn(request);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("Unhandled function error", err);
      throw new HttpsError("internal", "Something went wrong. Please try again.");
    }
  };
}

const opts: CallableOptions = { secrets: [GEMINI_API_KEY], cors: true };

// ---- callable functions ---------------------------------------------------

export const generateText = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  await enforceLimit(caller);

  // Structured form: message + history + memory + language. The single-string
  // `prompt` form is still accepted for backward compatibility.
  const rawMessage = typeof request.data?.message === "string" ? request.data.message.trim() : "";

  let prompt: string;
  let recordedPrompt: string;
  if (rawMessage.length > 0) {
    if (rawMessage.length > MAX_PROMPT_LEN) {
      throw new HttpsError("invalid-argument", '"message" is too long.');
    }
    const history = sanitizeHistory(request.data?.history);
    const memory = typeof request.data?.memory === "string" ? request.data.memory.trim() : "";
    const language = typeof request.data?.language === "string" ? request.data.language.trim() : "";
    const languageCode = typeof request.data?.languageCode === "string" ? request.data.languageCode.trim() : "en";
    prompt = buildChatPrompt({ message: rawMessage, history, memory, language, languageCode });
    recordedPrompt = rawMessage;
  } else {
    prompt = requireString(request.data?.prompt, "prompt");
    recordedPrompt = prompt;
  }

  const text = await gemini.generateText(GEMINI_API_KEY.value(), prompt);
  const meta = await saveHistory({ userId: caller.uid, prompt: recordedPrompt, type: "text", output: text });
  return { id: meta.id, type: "text", text, createdAt: meta.createdAt };
}));

export const editGeneratedText = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  const current = requireString(request.data?.text, "text");
  const instruction = requireString(request.data?.instruction, "instruction");
  await enforceLimit(caller);

  const text = await gemini.editText(GEMINI_API_KEY.value(), current, instruction);
  const meta = await saveHistory({ userId: caller.uid, prompt: instruction, type: "text_edit", output: text });
  return { id: meta.id, type: "text_edit", text, createdAt: meta.createdAt };
}));

export const generateImage = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  const prompt = requireString(request.data?.prompt, "prompt");
  await enforceLimit(caller);

  const img = await gemini.generateImage(GEMINI_API_KEY.value(), prompt);
  const { url, path } = await uploadImage(caller.uid, img);
  const meta = await saveHistory({ userId: caller.uid, prompt, type: "image", output: url });
  return { id: meta.id, type: "image", url, path, createdAt: meta.createdAt };
}));

export const editGeneratedImage = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  const instruction = requireString(request.data?.instruction, "instruction");
  await enforceLimit(caller);

  // Source image can come from either a previously generated image the caller
  // owns (`path`) OR an inline base64 image the user attached (`imageBase64`).
  let source: gemini.GeneratedImage;
  const path = request.data?.path;
  const imageBase64 = request.data?.imageBase64;
  if (typeof path === "string" && path.trim().length > 0) {
    source = await downloadOwnedImage(caller.uid, path.trim());
  } else if (typeof imageBase64 === "string" && imageBase64.trim().length > 0) {
    const mimeType =
      typeof request.data?.mimeType === "string" && request.data.mimeType.trim().length > 0
        ? request.data.mimeType
        : "image/jpeg";
    source = { data: Buffer.from(imageBase64, "base64"), mimeType };
  } else {
    throw new HttpsError("invalid-argument", '"path" or "imageBase64" is required.');
  }

  const img = await gemini.editImage(GEMINI_API_KEY.value(), source, instruction);
  const out = await uploadImage(caller.uid, img);
  const meta = await saveHistory({ userId: caller.uid, prompt: instruction, type: "image_edit", output: out.url });
  return { id: meta.id, type: "image_edit", url: out.url, path: out.path, createdAt: meta.createdAt };
}));

/**
 * Fold a recent conversation into the user's long-term memory profile at
 * users/{uid}/memory/profile. Written by the Admin SDK (bypasses rules). Skipped
 * for anonymous guests so we don't build durable profiles for throwaway sessions.
 */
export const updateMemory = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  if (caller.isGuest) return { ok: false };

  const history = sanitizeHistory(request.data?.history);
  if (history.length === 0) return { ok: false };

  const ref = db.collection("users").doc(caller.uid).collection("memory").doc("profile");
  const snap = await ref.get();
  const existing = snap.data();

  const updated = await gemini.extractMemory(
    GEMINI_API_KEY.value(),
    {
      summary: typeof existing?.summary === "string" ? existing.summary : "",
      preferences: Array.isArray(existing?.preferences) ? existing.preferences : [],
      importantFacts: Array.isArray(existing?.importantFacts) ? existing.importantFacts : [],
      projects: Array.isArray(existing?.projects) ? existing.projects : [],
    },
    history.map((t) => `${t.role}: ${t.text}`).join("\n")
  );

  await ref.set(
    {
      summary: updated.summary,
      preferences: updated.preferences,
      importantFacts: updated.importantFacts,
      projects: updated.projects,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { ok: true, summary: updated.summary };
}));

/**
 * Delete the caller's long-term memory profile at users/{uid}/memory/profile.
 * Written by the Admin SDK so the client never needs write access to memory —
 * the Firestore rules keep memory client-read-only. (Settings → Clear memory.)
 */
export const clearMemory = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  await db.collection("users").doc(caller.uid).collection("memory").doc("profile").delete();
  return { ok: true };
}));
