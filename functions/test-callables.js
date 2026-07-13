/**
 * End-to-end smoke test of the callable/HTTP surface on the LOCAL emulators
 * (auth + functions + firestore). Verifies auth enforcement, requestId quota
 * wiring, Apple root-cert loading, and the notification endpoint — without
 * touching production. Run via:
 *   firebase emulators:exec --only auth,functions,firestore --project demo-moomo-test "node test-callables.js"
 */
const PROJECT = process.env.GCLOUD_PROJECT || "demo-moomo-test";
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
const AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";

let passed = 0;
let failed = 0;
const ok = (name, cond, extra = "") => {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.log(`  ✗ ${name} ${extra}`); }
};

async function anonToken() {
  const res = await fetch(`${AUTH}/accounts:signUp?key=fake-api-key`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  const body = await res.json();
  return body.idToken;
}

async function callable(name, data, token) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${FN}/${name}`, {
    method: "POST",
    headers,
    body: JSON.stringify({ data }),
  });
  return { status: res.status, body: await res.json().catch(() => ({})) };
}

async function main() {
  console.log("callable surface (emulator)");

  // Unauthenticated calls are rejected.
  let r = await callable("generateText", { message: "hi", requestId: "e2e-noauth-1" });
  ok("generateText without auth → unauthenticated", r.status === 401 || r.body?.error?.status === "UNAUTHENTICATED");

  const token = await anonToken();
  ok("anonymous auth token issued", typeof token === "string" && token.length > 100);

  // Gemini key is a dummy in the emulator, so generation fails upstream —
  // which is exactly what we want: the reservation must be RELEASED and the
  // error mapped to a safe HttpsError (never a stack trace).
  r = await callable("generateText", { message: "hello", requestId: "e2e-fail-1" }, token);
  const errStatus = r.body?.error?.status;
  ok("failed generation returns mapped HttpsError", ["INTERNAL", "UNAVAILABLE", "RESOURCE_EXHAUSTED"].includes(errStatus), JSON.stringify(r.body).slice(0, 200));
  ok("failed generation leaks no stack trace", !JSON.stringify(r.body).includes("at "));

  // Retry with the SAME requestId is accepted again (reservation was released).
  r = await callable("generateText", { message: "hello", requestId: "e2e-fail-1" }, token);
  ok("same requestId retry accepted after failure", ["INTERNAL", "UNAVAILABLE", "RESOURCE_EXHAUSTED"].includes(r.body?.error?.status));

  // verifyAppStorePurchase: garbage JWS must be rejected as invalid-argument —
  // this also proves the Apple root certificates load correctly at runtime.
  r = await callable("verifyAppStorePurchase", { jws: "not.a.jws" }, token);
  ok("verifyAppStorePurchase rejects garbage JWS", r.body?.error?.status === "INVALID_ARGUMENT", JSON.stringify(r.body).slice(0, 200));

  r = await callable("verifyAppStorePurchase", {}, token);
  ok("verifyAppStorePurchase requires jws", r.body?.error?.status === "INVALID_ARGUMENT");

  r = await callable("verifyAppStorePurchase", { jws: "x" }, null);
  ok("verifyAppStorePurchase requires auth", r.status === 401 || r.body?.error?.status === "UNAUTHENTICATED");

  // App Store notification endpoint: bad payloads are rejected, not crashed.
  let res = await fetch(`${FN}/appStoreNotifications`, { method: "GET" });
  ok("notifications endpoint rejects GET", res.status === 405);

  res = await fetch(`${FN}/appStoreNotifications`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  });
  ok("notifications endpoint rejects missing signedPayload", res.status === 400);

  res = await fetch(`${FN}/appStoreNotifications`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ signedPayload: "garbage.payload.here" }),
  });
  ok("notifications endpoint rejects unsigned payload", res.status === 401);

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((err) => { console.error(err); process.exit(1); });
