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

// Quota (reserve → commit/release) and App Store subscription verification.
// admin.initializeApp() must run before these modules touch Firestore — they
// only call admin.firestore() lazily, so the import order here is safe.
import { withQuota, sanitizeRequestId } from "./quota";
export { verifyAppStorePurchase, appStoreNotifications } from "./appstore";

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const MAX_PROMPT_LEN = 4000;
const MAX_HISTORY = 20;
const MAX_MEMORY_LEN = 4000;

// Inline chat-image limits. Callable payloads cap at 10 MB total, so each image
// and the combined total must stay comfortably below that.
const MAX_CHAT_IMAGES = 4;
const MAX_IMAGE_BASE64_LEN = 5_500_000; // ~4 MB binary per image
const MAX_TOTAL_IMAGE_BASE64_LEN = 8_000_000;
const ALLOWED_IMAGE_MIMES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);

/**
 * System prompt, assembled per request by buildSystemInstruction and sent as
 * Gemini's `systemInstruction` (see gemini.chat) — never pasted into the
 * user-visible conversation text.
 */
const BASE_SYSTEM =
  "You are Moomo, an intelligent AI assistant. Be accurate and direct: answer the user's actual question " +
  "first, and add background only when it changes what the user should do next. " +
  "Write in clean Markdown — short paragraphs, numbered steps for procedures, '-' bullets for lists, " +
  "**bold** for key terms, and fenced code blocks for code. Avoid tables unless the user asks for one.";
const GROUNDED_HELP_DIRECTIVE =
  "When helping someone operate an app, website, or device: give the exact next actions (usually 2-6 short " +
  "steps), not generic possibilities. Never invent UI elements — do not mention checkboxes, buttons, menus, " +
  "or navigation paths unless you can see them or know for certain they exist in that product. If you don't " +
  "know the exact control, say so plainly. Skip introductions, 'common scenarios', speculative alternatives, " +
  "and repeated warnings. If one missing detail blocks a precise answer, ask exactly one targeted clarifying " +
  "question instead of listing guesses.";
const VISION_DIRECTIVE =
  "The latest user message includes attached image(s). Inspect them before answering. Resolve references " +
  "like 'this', 'that', 'these', 'the second one', or 'the other three' against what is actually visible. " +
  "First identify what the image shows (which app or screen, which items, how many), then answer for that " +
  "exact interface — never for a generic version of it. Mention only elements you can actually see there; " +
  "if the control the user needs is not visible, say what you do see and either give a path you are certain " +
  "of or ask one brief clarifying question. If the image is unreadable or ambiguous, say exactly that " +
  "instead of answering from assumptions.";
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

/**
 * Validate client-supplied inline chat images. Rejects (rather than silently
 * drops) anything malformed — a message the user attached an image to must
 * never be answered as if the image wasn't there.
 */
function sanitizeImages(raw: unknown): gemini.InlineImage[] {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw)) {
    throw new HttpsError("invalid-argument", '"images" must be an array.');
  }
  if (raw.length > MAX_CHAT_IMAGES) {
    throw new HttpsError("invalid-argument", `At most ${MAX_CHAT_IMAGES} images per message.`);
  }
  const images: gemini.InlineImage[] = [];
  let total = 0;
  for (const item of raw) {
    const obj = (item ?? {}) as Record<string, unknown>;
    const data = typeof obj.data === "string" ? obj.data : "";
    const mimeType = typeof obj.mimeType === "string" ? obj.mimeType.trim().toLowerCase() : "";
    if (data.length === 0) {
      throw new HttpsError("invalid-argument", "An attached image is empty.");
    }
    if (!ALLOWED_IMAGE_MIMES.has(mimeType)) {
      throw new HttpsError("invalid-argument", "Unsupported image type. Use JPEG, PNG, WebP, or HEIC.");
    }
    if (data.length > MAX_IMAGE_BASE64_LEN) {
      throw new HttpsError("invalid-argument", "An attached image is too large.");
    }
    total += data.length;
    if (total > MAX_TOTAL_IMAGE_BASE64_LEN) {
      throw new HttpsError("invalid-argument", "The attached images are too large altogether.");
    }
    if (Buffer.from(data, "base64").length === 0) {
      throw new HttpsError("invalid-argument", "An attached image is not valid base64.");
    }
    images.push({ data, mimeType });
  }
  return images;
}

/** Assemble the per-request system instruction (behavior + language + memory).
 *  Conversation history and the current message do NOT go here — they travel
 *  as role-tagged contents in gemini.chat. */
function buildSystemInstruction(args: {
  memory: string;
  language: string;
  languageCode: string;
  hasImages: boolean;
}): string {
  const { memory, language, languageCode, hasImages } = args;
  const sections: string[] = [BASE_SYSTEM, GROUNDED_HELP_DIRECTIVE];

  if (hasImages) {
    sections.push(VISION_DIRECTIVE);
  }

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

  return sections.join("\n\n");
}

/** Append a history record and return its id + timestamp. `requestId` links the
 *  record to its quota reservation so retries can replay the stored result;
 *  `path` (images) lets a replay return the Storage path alongside the URL. */
async function saveHistory(entry: {
  userId: string;
  prompt: string;
  type: GenType;
  output: string;
  requestId: string;
  path?: string;
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

/** Map an upstream Gemini/API failure to a meaningful HttpsError so the app can
 *  show the real reason (out of credits, outage) instead of a generic message.
 *  The @google/genai SDK throws ApiError carrying the upstream HTTP status. */
function toHttpsError(err: unknown): HttpsError {
  const status = (err as { status?: unknown })?.status;
  if (typeof status === "number") {
    if (status === 429) {
      return new HttpsError(
        "resource-exhausted",
        "The AI service is out of credits or capacity. Please try again later."
      );
    }
    if (status >= 500) {
      return new HttpsError("unavailable", "The AI service is temporarily unavailable. Please try again.");
    }
    // 400/401/403 = key or request misconfiguration — server-side problem, keep
    // the client message generic (details are in the function logs).
  }
  return new HttpsError("internal", "Something went wrong. Please try again.");
}

/** Wrap a handler so unexpected errors never leak stack traces to the client. */
function safe<T>(fn: (request: CallableRequest) => Promise<T>) {
  return async (request: CallableRequest): Promise<T> => {
    try {
      return await fn(request);
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("Unhandled function error", err);
      throw toHttpsError(err);
    }
  };
}

const opts: CallableOptions = { secrets: [GEMINI_API_KEY], cors: true };

// ---- callable functions ---------------------------------------------------

export const generateText = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  const requestId = sanitizeRequestId(request.data?.requestId);

  return withQuota(caller.uid, requestId, async () => {
    // Structured form: message + history + memory + language + optional inline
    // images (multimodal). The single-string `prompt` form is still accepted
    // for backward compatibility.
    const rawMessage = typeof request.data?.message === "string" ? request.data.message.trim() : "";
    const images = sanitizeImages(request.data?.images);
    const history = sanitizeHistory(request.data?.history);

    let text: string;
    let recordedPrompt: string;
    if (rawMessage.length > 0 || images.length > 0) {
      if (rawMessage.length > MAX_PROMPT_LEN) {
        throw new HttpsError("invalid-argument", '"message" is too long.');
      }
      // Image with no text is a valid message ("what is this?" implied).
      const message = rawMessage.length > 0 ? rawMessage : "Describe the attached image(s).";
      const memory = typeof request.data?.memory === "string" ? request.data.memory.trim() : "";
      const language = typeof request.data?.language === "string" ? request.data.language.trim() : "";
      const languageCode = typeof request.data?.languageCode === "string" ? request.data.languageCode.trim() : "en";
      const system = buildSystemInstruction({ memory, language, languageCode, hasImages: images.length > 0 });
      recordedPrompt = message;

      // Safe diagnostics: counts and sizes only, never image bytes or prompt text.
      logger.info("generateText", {
        uid: caller.uid,
        imageCount: images.length,
        imageBase64Lengths: images.map((img) => img.data.length),
        mimeTypes: images.map((img) => img.mimeType),
        historyCount: history.length,
        messageLen: message.length,
      });

      // ONE multimodal request: systemInstruction + role-tagged history + the
      // current turn carrying both image parts and the message text. There is
      // no separate text-only fallback model.
      text = await gemini.chat(GEMINI_API_KEY.value(), { system, history, message, images });
    } else {
      const prompt = requireString(request.data?.prompt, "prompt");
      recordedPrompt = prompt;
      logger.info("generateText", { uid: caller.uid, legacyPrompt: true, messageLen: prompt.length });
      text = await gemini.generateText(GEMINI_API_KEY.value(), prompt);
    }

    const meta = await saveHistory({ userId: caller.uid, prompt: recordedPrompt, type: "text", output: text, requestId });
    return { id: meta.id, type: "text", text, createdAt: meta.createdAt };
  });
}));

export const editGeneratedText = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  const current = requireString(request.data?.text, "text");
  const instruction = requireString(request.data?.instruction, "instruction");
  const requestId = sanitizeRequestId(request.data?.requestId);

  return withQuota(caller.uid, requestId, async () => {
    const text = await gemini.editText(GEMINI_API_KEY.value(), current, instruction);
    const meta = await saveHistory({ userId: caller.uid, prompt: instruction, type: "text_edit", output: text, requestId });
    return { id: meta.id, type: "text_edit", text, createdAt: meta.createdAt };
  });
}));

export const generateImage = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  const prompt = requireString(request.data?.prompt, "prompt");
  const requestId = sanitizeRequestId(request.data?.requestId);

  return withQuota(caller.uid, requestId, async () => {
    const img = await gemini.generateImage(GEMINI_API_KEY.value(), prompt);
    const { url, path } = await uploadImage(caller.uid, img);
    const meta = await saveHistory({ userId: caller.uid, prompt, type: "image", output: url, requestId, path });
    return { id: meta.id, type: "image", url, path, createdAt: meta.createdAt };
  });
}));

export const editGeneratedImage = onCall(opts, safe(async (request) => {
  const caller = requireAuth(request);
  const instruction = requireString(request.data?.instruction, "instruction");
  const requestId = sanitizeRequestId(request.data?.requestId);

  return withQuota(caller.uid, requestId, async () => {
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
    const meta = await saveHistory({ userId: caller.uid, prompt: instruction, type: "image_edit", output: out.url, requestId, path: out.path });
    return { id: meta.id, type: "image_edit", url: out.url, path: out.path, createdAt: meta.createdAt };
  });
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

/**
 * Wipe ALL of the caller's server-side data: the users/{uid} tree
 * (conversations, messages, assets, memory), the usage counter, the generation
 * audit log, and generated images in Storage. Called by the app right before
 * the Firebase Auth account is deleted (Apple Guideline 5.1.1(v)) — without
 * this, deleting the Auth user silently orphaned every byte of user data.
 */
export const deleteUserData = onCall({ cors: true }, safe(async (request) => {
  const caller = requireAuth(request);
  const uid = caller.uid;

  // Firestore user tree (recursive: conversations/messages, assets, memory,
  // usage counters, entitlements).
  await db.recursiveDelete(db.collection("users").doc(uid));

  // Legacy usage counter (pre-subscription schema).
  await db.collection("usage").doc(uid).delete();

  // App Store transaction → uid mappings. The subscription itself lives with
  // the Apple ID; a later Restore Purchases re-creates the mapping.
  {
    const page = await db.collection("appStoreTransactions").where("uid", "==", uid).limit(100).get();
    if (!page.empty) {
      const batch = db.batch();
      page.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }

  // Generation audit log (flat collection keyed by userId field).
  for (;;) {
    const page = await db.collection("generations").where("userId", "==", uid).limit(250).get();
    if (page.empty) break;
    const batch = db.batch();
    page.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    if (page.size < 250) break;
  }

  // Generated/edited images in Storage.
  await bucket.deleteFiles({ prefix: `generations/${uid}/` });

  logger.info("Deleted all data for user", { uid });
  return { ok: true };
}));
