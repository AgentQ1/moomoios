# Moomo iOS — Setup (backend is live)

Backend: Firebase **Auth + Firestore + Storage + Cloud Functions** on project
**`moomoios-2026`**. All Gemini calls run server-side; the Gemini API key lives
only in Firebase Secret Manager and never ships in the app.

## ✅ Already done (live & verified)

- Cloud Functions deployed & tested end-to-end: `generateText`, `generateImage`,
  `editGeneratedText`, `editGeneratedImage` (all callable, auth-enforced).
- `GEMINI_API_KEY` stored in Secret Manager (verified working for text + image).
- Firestore database, rules, and indexes deployed; generation history writing.
- Storage bucket `moomoios-2026.firebasestorage.app` created + rules deployed.
- Auth providers enabled: **Anonymous, Google, Apple**.
- `GoogleService-Info.plist` (for `moomoios-2026`) added to the Xcode target and
  `Info.plist` patched with the real Google `REVERSED_CLIENT_ID`.

## Remaining: open in Xcode, add packages, run

Swift Package dependencies are added to the project (`firebase-ios-sdk`:
FirebaseCore/FirebaseAuth/FirebaseFunctions, and `GoogleSignIn-iOS`: GoogleSignIn).
If Xcode prompts to resolve packages on first open, let it finish, then:

1. Select the **MoomoIOS** scheme + a simulator (e.g. iPhone 16).
2. **Product → Run** (⌘R).

Generation (Gemini) always goes through Cloud Functions. The client additionally
links FirebaseFirestore for its own data: chat history + conversation metadata
under `users/{uid}/conversations/**` and reading the memory profile
(`users/{uid}/memory/profile` is client-read-only; writes happen server-side).

### Apple Sign-In note
The app uses the **native** `ASAuthorization` flow, so it needs only: the Apple
provider enabled in Firebase (done) + the "Sign in with Apple" capability
(entitlement already in `MoomoAI.entitlements`) provisioned by automatic signing
with your team. No Apple Services ID / `.p8` key is required for native iOS.

## Cloud Functions reference

| Function             | Input                     | Output (JSON)                        |
|----------------------|---------------------------|--------------------------------------|
| `generateText`       | `{ message, history?, memory?, language?, languageCode? }` (legacy `{ prompt }` still accepted) | `{ id, type, text, createdAt }` |
| `editGeneratedText`  | `{ text, instruction }`   | `{ id, type, text, createdAt }`      |
| `generateImage`      | `{ prompt }`              | `{ id, type, url, path, createdAt }` |
| `editGeneratedImage` | `{ path, instruction }`   | `{ id, type, url, path, createdAt }` |
| `verifyAppStorePurchase` | `{ jws }` (StoreKit 2 signed transaction) | `{ isActive, productId, expiresDateMs, environment }` |
| `appStoreNotifications` (HTTPS) | App Store Server Notifications V2 `{ signedPayload }` | `200 OK` |

Every generation call also accepts a client `requestId` (UUID) used for
idempotent quota accounting; free-tier responses additionally echo
`freeQueriesUsedToday` / `freeDailyLimit`.
History saved to Firestore `generations/{auto}`: `userId, prompt, type, output, requestId, path?, createdAt`.

## Freemium quota + Moomo Premium (StoreKit 2)

- **Free users (incl. guests): 10 successful queries per UTC day**, enforced
  server-side in `functions/src/quota.ts` via atomic reserve → commit/release
  transactions on `users/{uid}/usage/current`. Failures/cancellations release
  the reservation; replayed requestIds return the stored result without
  consuming. Query 11 is rejected with `resource-exhausted` +
  `details.moomoCode = "FREE_QUOTA_EXHAUSTED"` **before** the Gemini call —
  the app shows the Premium paywall and preserves the draft.
- **Premium** (`com.moomolab.moomo.premium.monthly`, $4.99/month): entitlement stored
  at `users/{uid}/entitlements/premium`, written ONLY from Apple-signed JWS
  payloads (`functions/src/appstore.ts`, verified against Apple root CAs in
  `functions/certs/`). Premium bypasses the free limit (invisible 500/day
  fair-use cap). `appStoreTransactions/{originalTransactionId}` maps
  transactions → uid for server notifications.
- **APP_APPLE_ID** functions param (the app's numeric Apple ID from App Store
  Connect) must be set before PRODUCTION receipts can verify; sandbox works
  without it. Set it in `functions/.env`: `APP_APPLE_ID=<number>`, then redeploy.
- App Store Server Notifications V2 URL (paste into App Store Connect →
  App Information → App Store Server Notifications, both prod and sandbox):
  `https://us-central1-moomoios-2026.cloudfunctions.net/appStoreNotifications`.
- Backend tests: `cd functions && npm run build && firebase emulators:exec
  --only firestore --project demo-moomo-test "node test-quota.js"` (quota) and
  `--only auth,functions,firestore ... "node test-callables.js"` (callable surface).

## Security notes — do not regress

- **Never** put the Gemini key in Swift, `Info.plist`, or any committed file. It
  belongs only in Secret Manager (`firebase functions:secrets:set GEMINI_API_KEY`).
- `.env`, `functions/lib`, `functions/node_modules`, and debug logs are gitignored.
- `GoogleService-Info.plist` contains only the app-restricted Firebase iOS API key
  (safe to ship) — not the Gemini key.
- Redeploy functions after backend edits: `firebase deploy --only functions`.
