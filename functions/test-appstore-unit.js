/**
 * Direct unit tests of the App Store verification surface using
 * firebase-functions v2 test hooks (`.run()` for callables, plain (req,res)
 * for onRequest). Exercises the REAL Apple root-cert loading and
 * SignedDataVerifier paths without the functions emulator. Firestore is only
 * reached after a JWS verifies, so no emulator is needed for rejection paths.
 * Run:  node test-appstore-unit.js
 */
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-moomo-test";
const admin = require("firebase-admin");
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const { verifyAppStorePurchase, appStoreNotifications } = require("./lib/appstore");

let passed = 0;
let failed = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.log(`  ✗ ${name} ${extra}`); }
};

function mockRes() {
  const res = { statusCode: null, body: null };
  res.status = (code) => { res.statusCode = code; return res; };
  res.send = (body) => { res.body = body; return res; };
  res.on = () => res; // v2 wrapper subscribes to lifecycle events
  return res;
}

async function main() {
  console.log("verifyAppStorePurchase (callable .run)");

  // Unauthenticated → unauthenticated HttpsError.
  let err = null;
  try { await verifyAppStorePurchase.run({ data: { jws: "x.y.z" }, rawRequest: {} }); }
  catch (e) { err = e; }
  ok("rejects unauthenticated", err?.code === "unauthenticated", String(err?.code));

  // Missing jws → invalid-argument.
  err = null;
  try { await verifyAppStorePurchase.run({ data: {}, auth: { uid: "u1", token: {} }, rawRequest: {} }); }
  catch (e) { err = e; }
  ok("requires jws", err?.code === "invalid-argument", String(err?.code));

  // Garbage JWS → invalid-argument. This path constructs the SignedDataVerifier,
  // i.e. loads + parses the Apple root certificates from functions/certs/.
  err = null;
  try { await verifyAppStorePurchase.run({ data: { jws: "not.a.real-jws" }, auth: { uid: "u1", token: {} }, rawRequest: {} }); }
  catch (e) { err = e; }
  ok("rejects garbage JWS (certs loaded, verifier ran)", err?.code === "invalid-argument", String(err?.code ?? err));

  // Oversized JWS → invalid-argument without touching the verifier.
  err = null;
  try { await verifyAppStorePurchase.run({ data: { jws: "a".repeat(30000) }, auth: { uid: "u1", token: {} }, rawRequest: {} }); }
  catch (e) { err = e; }
  ok("rejects oversized jws", err?.code === "invalid-argument");

  console.log("appStoreNotifications (onRequest handler)");

  let res = mockRes();
  await appStoreNotifications({ method: "GET", body: {} }, res);
  ok("GET → 405", res.statusCode === 405, String(res.statusCode));

  res = mockRes();
  await appStoreNotifications({ method: "POST", body: {} }, res);
  ok("missing signedPayload → 400", res.statusCode === 400, String(res.statusCode));

  res = mockRes();
  await appStoreNotifications({ method: "POST", body: { signedPayload: "garbage.unsigned.payload" } }, res);
  ok("unsigned payload → 401 (never 500/crash)", res.statusCode === 401, String(res.statusCode));

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
