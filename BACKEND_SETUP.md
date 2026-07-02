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

The client talks to Firestore/Storage only through Cloud Functions, so the heavy
FirebaseFirestore SDK is intentionally not linked.

### Apple Sign-In note
The app uses the **native** `ASAuthorization` flow, so it needs only: the Apple
provider enabled in Firebase (done) + the "Sign in with Apple" capability
(entitlement already in `MoomoAI.entitlements`) provisioned by automatic signing
with your team. No Apple Services ID / `.p8` key is required for native iOS.

## Cloud Functions reference

| Function             | Input                     | Output (JSON)                        |
|----------------------|---------------------------|--------------------------------------|
| `generateText`       | `{ prompt }`              | `{ id, type, text, createdAt }`      |
| `editGeneratedText`  | `{ text, instruction }`   | `{ id, type, text, createdAt }`      |
| `generateImage`      | `{ prompt }`              | `{ id, type, url, path, createdAt }` |
| `editGeneratedImage` | `{ path, instruction }`   | `{ id, type, url, path, createdAt }` |

Guests (anonymous) are allowed but rate-limited: **5/day**; signed-in: **100/day**.
History saved to Firestore `generations/{auto}`: `userId, prompt, type, output, createdAt`.

## Security notes — do not regress

- **Never** put the Gemini key in Swift, `Info.plist`, or any committed file. It
  belongs only in Secret Manager (`firebase functions:secrets:set GEMINI_API_KEY`).
- `.env`, `functions/lib`, `functions/node_modules`, and debug logs are gitignored.
- `GoogleService-Info.plist` contains only the app-restricted Firebase iOS API key
  (safe to ship) — not the Gemini key.
- Redeploy functions after backend edits: `firebase deploy --only functions`.
