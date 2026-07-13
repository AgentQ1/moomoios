/**
 * Quota + entitlement integration tests against the Firestore EMULATOR.
 * Run:  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node test-quota.js
 * (started via `firebase emulators:exec --only firestore "node test-quota.js"`)
 */
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-moomo-test";
const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const { withQuota, FREE_DAILY_LIMIT } = require("./lib/quota");
const { entitlementIsActive } = require("./lib/appstore");

const db = admin.firestore();
let passed = 0;
let failed = 0;

function ok(name, cond) {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.log(`  ✗ ${name}`); }
}

async function usage(uid) {
  const snap = await db.doc(`users/${uid}/usage/current`).get();
  return snap.data() ?? {};
}

/** Mirrors the real callables: a successful generation persists a
 *  `generations` record carrying the requestId (saveHistory) before commit. */
const genFor = (uid, requestId, n) => async () => {
  await db.collection("generations").add({
    userId: uid, requestId, type: "text", output: `answer ${n}`, prompt: "p",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { id: `gen-${n}`, type: "text", text: `answer ${n}`, createdAt: "now" };
};
const genFail = async () => { throw new Error("upstream boom"); };

async function main() {
  // ---- 1. Free user: 10 succeed, 11th blocked BEFORE the provider runs ----
  console.log("free user daily limit");
  const uid = "free-user-1";
  for (let i = 1; i <= FREE_DAILY_LIMIT; i++) {
    const res = await withQuota(uid, `req-${i}`, genFor(uid, `req-${i}`, i));
    if (i === FREE_DAILY_LIMIT) {
      ok("response carries usage echo", res.freeQueriesUsedToday === FREE_DAILY_LIMIT && res.freeDailyLimit === FREE_DAILY_LIMIT);
    }
  }
  ok("10 queries committed", (await usage(uid)).successfulQueryCount === 10);

  let providerCalled = false;
  let blocked = null;
  try {
    await withQuota(uid, "req-11", async () => { providerCalled = true; return { type: "text" }; });
  } catch (err) {
    blocked = err;
  }
  ok("query 11 rejected", blocked !== null && String(blocked.code).includes("resource-exhausted"));
  ok("query 11 carries paywall code", blocked?.details?.moomoCode === "FREE_QUOTA_EXHAUSTED");
  ok("AI provider NOT called for query 11", providerCalled === false);
  ok("query 11 consumed nothing", (await usage(uid)).successfulQueryCount === 10 && (await usage(uid)).reservedQueryCount === 0);

  // ---- 2. Failed generation releases the reservation --------------------
  console.log("failure releases reservation");
  const uid2 = "free-user-2";
  try { await withQuota(uid2, "req-f1", genFail); } catch { /* expected */ }
  let u = await usage(uid2);
  ok("failure consumed nothing", (u.successfulQueryCount ?? 0) === 0 && (u.reservedQueryCount ?? 0) === 0);

  // Retry same requestId after failure succeeds and counts ONCE.
  await withQuota(uid2, "req-f1", genFor(uid2, "req-f1", 1));
  u = await usage(uid2);
  ok("retry after failure counts once", u.successfulQueryCount === 1);

  // ---- 3. Replay: same requestId after success does not double-count ----
  console.log("idempotent replay");
  let replayProviderCalled = false;
  const replay = await withQuota(uid2, "req-f1", async () => { replayProviderCalled = true; return { type: "text" }; });
  u = await usage(uid2);
  ok("replay served from store", replay.replayed === true && replay.text === "answer 1");
  ok("replay did not call provider", replayProviderCalled === false);
  ok("replay did not consume", u.successfulQueryCount === 1);

  // ---- 4. Rapid concurrent taps: same requestId consumes at most once ----
  console.log("concurrency");
  const uid3 = "free-user-3";
  const results = await Promise.allSettled([
    withQuota(uid3, "tap-1", genFor(uid3, "tap-1", 1)),
    withQuota(uid3, "tap-1", genFor(uid3, "tap-1", 1)),
    withQuota(uid3, "tap-1", genFor(uid3, "tap-1", 1)),
  ]);
  u = await usage(uid3);
  void results;
  ok("same requestId x3 concurrent consumes exactly 1", u.successfulQueryCount === 1);
  ok("no stuck reservations", (u.reservedQueryCount ?? 0) === 0);

  // Distinct requestIds concurrently: all count, never exceeding the limit.
  const uid4 = "free-user-4";
  const burst = Array.from({ length: 14 }, (_, i) => withQuota(uid4, `burst-${i}`, genFor(uid4, `burst-${i}`, i)));
  const settled = await Promise.allSettled(burst);
  const okCount = settled.filter((s) => s.status === "fulfilled").length;
  u = await usage(uid4);
  ok(`burst of 14 → exactly ${FREE_DAILY_LIMIT} succeed (got ${okCount})`, okCount === FREE_DAILY_LIMIT);
  ok("burst commits equal limit", u.successfulQueryCount === FREE_DAILY_LIMIT);

  // ---- 5. Premium bypasses the free limit -------------------------------
  console.log("premium bypass");
  const uid5 = "premium-user-1";
  await db.doc(`users/${uid5}/entitlements/premium`).set({
    isActive: true, revoked: false, expiresDateMs: Date.now() + 86400_000,
    productId: "com.moomolab.moomo.premium.monthly",
  });
  for (let i = 1; i <= FREE_DAILY_LIMIT + 2; i++) {
    await withQuota(uid5, `p-${i}`, genFor(uid5, `p-${i}`, i));
  }
  const premiumRes = await withQuota(uid5, "p-echo", genFor(uid5, "p-echo", 99));
  ok("premium not blocked past 10", true);
  ok("premium response has NO usage counter", premiumRes.freeQueriesUsedToday === undefined);

  // ---- 6. Expired / revoked entitlements are not premium ----------------
  console.log("entitlement edge cases");
  ok("expired entitlement inactive", entitlementIsActive({ isActive: true, revoked: false, expiresDateMs: Date.now() - 1000 }) === false);
  ok("grace period keeps premium", entitlementIsActive({ isActive: true, revoked: false, expiresDateMs: Date.now() - 1000, graceUntilMs: Date.now() + 1000 }) === true);
  ok("revoked kills premium", entitlementIsActive({ isActive: true, revoked: true, expiresDateMs: Date.now() + 86400_000 }) === false);
  ok("missing doc is not premium", entitlementIsActive(undefined) === false);
  ok("retired product ID never unlocks premium", entitlementIsActive({ isActive: true, revoked: false, productId: "com.moomo.io.premium.monthly", expiresDateMs: Date.now() + 86400_000 }) === false);
  ok("current product ID unlocks premium", entitlementIsActive({ isActive: true, revoked: false, productId: "com.moomolab.moomo.premium.monthly", expiresDateMs: Date.now() + 86400_000 }) === true);
  ok("transferred-away entitlement inactive despite valid dates", entitlementIsActive({ isActive: false, revoked: false, transferredTo: "other-uid", expiresDateMs: Date.now() + 86400_000 }) === false);

  const uid6 = "expired-user-1";
  await db.doc(`users/${uid6}/entitlements/premium`).set({
    isActive: true, revoked: false, expiresDateMs: Date.now() - 60_000,
  });
  for (let i = 1; i <= FREE_DAILY_LIMIT; i++) await withQuota(uid6, `e-${i}`, genFor(uid6, `e-${i}`, i));
  let expiredBlocked = false;
  try { await withQuota(uid6, "e-11", genFor(uid6, "e-11", 11)); } catch (err) { expiredBlocked = err?.details?.moomoCode === "FREE_QUOTA_EXHAUSTED"; }
  ok("expired subscriber is limited like free", expiredBlocked);

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((err) => { console.error(err); process.exit(1); });
