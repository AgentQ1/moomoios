/**
 * Server-side daily query quota with atomic reserve → commit/release.
 *
 * Free users get FREE_DAILY_LIMIT successful AI queries per UTC day; Premium
 * users bypass the free limit (a high invisible fair-use cap still applies).
 * Every AI request carries a client-generated requestId so retries, rapid
 * taps, and multi-device races can never consume more than one unit:
 *
 *   1. reserve  — transaction: reject when successful + reserved ≥ limit,
 *                 otherwise record the requestId as reserved. Re-reserving the
 *                 same requestId is a no-op (idempotent).
 *   2. commit   — on a usable AI response: reservation → successfulQueryCount.
 *   3. release  — on failure/cancel: the reservation is dropped and the unit
 *                 is never counted.
 *
 * A requestId that already committed is served as a REPLAY: the stored result
 * is returned without consuming another unit and without calling the AI
 * provider again. Day boundaries use server time (UTC) only — device clocks
 * and timezones cannot reset the allowance.
 *
 * Usage doc: users/{uid}/usage/current
 *   dayKey                 "YYYY-MM-DD" (UTC)
 *   successfulQueryCount   committed queries today
 *   reservations           { requestId: reservedAtMs } (in-flight, TTL-pruned)
 *   completedRequestIds    { requestId: committedAtMs } (today only, capped)
 *   updatedAt              server timestamp
 */
import { HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
import { isPremiumUid } from "./appstore";

export const FREE_DAILY_LIMIT = 10;
/** Invisible anti-abuse ceiling for Premium; never surfaced as a "plan limit". */
export const PREMIUM_FAIR_USE_LIMIT = 500;
/** Crashed/never-settled reservations expire so they can't wedge the quota. */
const RESERVATION_TTL_MS = 10 * 60 * 1000;
const COMPLETED_CAP = 40;

const db = () => admin.firestore();

/** Usage-doc transactions can collide when several requests land at once
 *  (multi-device bursts); allow more optimistic retries than the default 5. */
const TXN_OPTS = { maxAttempts: 15 };

const usageRef = (uid: string) => db().doc(`users/${uid}/usage/current`);

/** UTC day key from server time — device clocks never participate. */
function todayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

/** Bound + validate the client-supplied request id; fall back to a server one
 *  (no cross-retry idempotency, but everything else still works). */
export function sanitizeRequestId(raw: unknown): string {
  if (typeof raw === "string" && /^[A-Za-z0-9-]{8,64}$/.test(raw)) return raw;
  return `srv-${randomUUID()}`;
}

type ReserveOutcome = "reserved" | "replay";

async function reserve(uid: string, requestId: string, limit: number, quotaCode: string, quotaMessage: string): Promise<ReserveOutcome> {
  const now = Date.now();
  const today = todayKey();
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(usageRef(uid));
    const data = snap.data() ?? {};
    const sameDay = data.dayKey === today;
    const successCount: number = sameDay && typeof data.successfulQueryCount === "number" ? data.successfulQueryCount : 0;
    const completed: Record<string, number> = sameDay && data.completedRequestIds ? { ...data.completedRequestIds } : {};

    // Reservations survive day rollover only within their TTL.
    const reservations: Record<string, number> = {};
    for (const [id, at] of Object.entries<number>(data.reservations ?? {})) {
      if (typeof at === "number" && now - at < RESERVATION_TTL_MS) reservations[id] = at;
    }

    if (completed[requestId] !== undefined) return "replay";

    if (reservations[requestId] === undefined) {
      if (successCount + Object.keys(reservations).length >= limit) {
        throw new HttpsError("resource-exhausted", quotaMessage, { moomoCode: quotaCode });
      }
      reservations[requestId] = now;
    }

    tx.set(usageRef(uid), {
      dayKey: today,
      successfulQueryCount: successCount,
      reservedQueryCount: Object.keys(reservations).length,
      reservations,
      completedRequestIds: completed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return "reserved";
  }, TXN_OPTS);
}

/** Convert the reservation into one successful query; returns today's count. */
async function commit(uid: string, requestId: string): Promise<number> {
  const today = todayKey();
  const now = Date.now();
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(usageRef(uid));
    const data = snap.data() ?? {};
    const sameDay = data.dayKey === today;
    const successCount: number = sameDay && typeof data.successfulQueryCount === "number" ? data.successfulQueryCount : 0;
    let completed: Record<string, number> = sameDay && data.completedRequestIds ? { ...data.completedRequestIds } : {};
    const reservations: Record<string, number> = { ...(data.reservations ?? {}) };
    delete reservations[requestId];

    // Idempotent: a requestId that already committed (e.g. two racing calls
    // that both passed reserve) never increments the counter twice.
    const alreadyCommitted = completed[requestId] !== undefined;
    completed[requestId] = alreadyCommitted ? completed[requestId] : now;
    // Cap the map so the doc can't grow unbounded (oldest entries drop first).
    const entries = Object.entries(completed).sort((a, b) => b[1] - a[1]).slice(0, COMPLETED_CAP);
    completed = Object.fromEntries(entries);

    const newCount = alreadyCommitted ? successCount : successCount + 1;
    tx.set(usageRef(uid), {
      dayKey: today,
      successfulQueryCount: newCount,
      reservedQueryCount: Object.keys(reservations).length,
      reservations,
      completedRequestIds: completed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return newCount;
  }, TXN_OPTS);
}

/** Drop the reservation — failed/canceled requests never count. Best-effort. */
async function release(uid: string, requestId: string): Promise<void> {
  try {
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(usageRef(uid));
      const data = snap.data();
      if (!data?.reservations || data.reservations[requestId] === undefined) return;
      const reservations: Record<string, number> = { ...data.reservations };
      delete reservations[requestId];
      tx.update(usageRef(uid), {
        reservations,
        reservedQueryCount: Object.keys(reservations).length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }, TXN_OPTS);
  } catch (err) {
    logger.warn("Quota release failed", { uid, requestId, err });
  }
}

/** Fetch the stored result for an already-committed requestId (replay). */
async function storedResult(uid: string, requestId: string): Promise<Record<string, unknown> | null> {
  const page = await db()
    .collection("generations")
    .where("userId", "==", uid)
    .where("requestId", "==", requestId)
    .limit(1)
    .get();
  if (page.empty) return null;
  const doc = page.docs[0];
  const d = doc.data();
  const base = { id: doc.id, type: d.type, createdAt: new Date().toISOString(), replayed: true };
  if (d.type === "image" || d.type === "image_edit") {
    return { ...base, url: d.output, path: d.path ?? null };
  }
  return { ...base, text: d.output };
}

export interface QuotaResult<T> {
  result: T;
  /** Committed free-query count for today; null for Premium (unlimited). */
  freeQueriesUsedToday: number | null;
}

/**
 * Run one AI generation under quota control. Premium bypasses the free limit
 * (fair-use cap only); free users go through reserve → commit/release. A
 * replayed requestId returns the stored result without another reservation.
 */
export async function withQuota<T extends Record<string, unknown>>(
  uid: string,
  requestId: string,
  fn: () => Promise<T>
): Promise<Record<string, unknown>> {
  const premium = await isPremiumUid(uid);
  const limit = premium ? PREMIUM_FAIR_USE_LIMIT : FREE_DAILY_LIMIT;
  const quotaCode = premium ? "FAIR_USE_EXHAUSTED" : "FREE_QUOTA_EXHAUSTED";
  const quotaMessage = premium
    ? "You've reached today's usage limit. Please try again tomorrow."
    : "You've reached today's free limit. Upgrade to Moomo Premium for unlimited access.";

  const outcome = await reserve(uid, requestId, limit, quotaCode, quotaMessage);
  if (outcome === "replay") {
    const stored = await storedResult(uid, requestId);
    if (stored) {
      logger.info("Quota replay served", { uid, requestId });
      return stored;
    }
    // The generation record vanished (e.g. pruned). Falling through WITHOUT a
    // reservation would be a free-query hole, so reserve under a variant id.
    await reserve(uid, `${requestId}-r`, limit, quotaCode, quotaMessage);
    requestId = `${requestId}-r`;
  }

  try {
    const result = await fn();
    const count = await commit(uid, requestId);
    return premium ? { ...result } : { ...result, freeQueriesUsedToday: count, freeDailyLimit: FREE_DAILY_LIMIT };
  } catch (err) {
    await release(uid, requestId);
    throw err;
  }
}
