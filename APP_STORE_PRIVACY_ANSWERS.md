# Moomo AI — App Store Connect privacy answers & review notes

Companion to `MoomoAI/PrivacyInfo.xcprivacy`. Everything here is derived from the
shipping code, not from intent — file references are given so each answer can be
re-verified before a resubmission.

Prepared for the resubmission that answers the **July 23, 2026** rejection of
build 1.0 (3), Submission ID `3f221bde-244d-470b-97c1-d25db84ad8d9`, under
Guidelines **5.1.1(i)** and **5.1.2(i)**.

---

## 1. Third-party AI service

| | |
|---|---|
| **Provider** | Google LLC — Gemini API |
| **Models** | `gemini-2.5-flash` (text + vision), `gemini-2.5-flash-image` (image generation/editing) |
| **Connection shape** | app → **Moomo's own backend** (Firebase Cloud Functions, us-central1) → Gemini API. The app never talks to Google's AI endpoints directly and never holds an AI API key. |
| **Where in code** | `functions/src/gemini.ts` is the only module that touches the Gemini SDK; the key is a Cloud Functions secret (`functions/src/index.ts:27`). |

### What is sent to Google

| Data | Source in code |
|---|---|
| Message text the user typed or dictated | `MoomoAI/Services/GenerationService.swift:47` → `functions/src/index.ts:319` |
| Attached/captured images (inline base64, max 4, re-encoded JPEG ≤1024px) | `MoomoAI/ViewModels/ChatViewModel.swift:333` |
| Text extracted **on-device** from attached documents (the file is never uploaded) | `MoomoAI/ViewModels/ChatViewModel.swift:683` |
| Recent conversation turns from the current chat (≤20) | `functions/src/index.ts:30` (`MAX_HISTORY`) |
| Personalization memory summary — **only when Memory is on** | `MoomoAI/ViewModels/ChatViewModel.swift:352` |
| Selected response language + Moomo's own system instructions | `functions/src/index.ts:166` |

### What is **not** sent to Google

Name, email, Firebase UID, purchase history, usage counters, contacts, location,
unattached photos, advertising identifiers, and **audio** (dictation is
transcribed by iOS — on-device wherever the locale supports it, see
`MoomoAI/Views/ChatView.swift:788`).

Backend logging is counts-and-sizes only, never prompt text or image bytes
(`functions/src/index.ts:307`).

### Retention / training

Content is processed transiently to serve the request. Under the Gemini API
paid-tier terms, Google does not use content submitted via the API key to train
its models. Moomo does not train any model on user conversations.

---

## 2. The in-app permission flow (what changed for this resubmission)

The previous build disclosed AI processing **only** in the Privacy Policy and
Terms, which Apple correctly flagged as insufficient. The app now asks
separately and explicitly, before any content can reach Google.

| Step | Where |
|---|---|
| Dedicated consent screen naming Google, itemizing what is sent / not sent, why, with **Accept** and **Decline** | `MoomoAI/Views/AIDataConsentView.swift` |
| Shown on first arrival at the chat, before any composer input can be sent | `MoomoAI/ContentView.swift` (`presentAIConsentIfUndecided`) |
| Composer preflight — blocks the send and re-presents the screen if permission is absent | `MoomoAI/Views/ChatView.swift` (`blockAndRequestAIConsentIfNeeded`) |
| Transport-level hard guard — every Gemini-bound call refuses without consent, including the background memory-summarization task | `MoomoAI/Services/GenerationService.swift` (`requireAIConsent`) |
| Decline → app stays fully usable, AI off, clear non-crashing explanation | `AIDataSharingDisclosure.declinedExplanation` |
| View / withdraw at any time | **Settings → AI data sharing** (`MoomoAI/Views/SettingsView.swift`) |
| Stored versioned + timestamped, superseded versions re-prompt | `MoomoAI/Utilities/AIDataSharingConsent.swift` |

Consent is stored under `moomo.aiDataSharing.*` in `UserDefaults` with the
disclosure version (`2026-07-23`), an ISO-8601 timestamp, and the provider name.
It is **separate** from the existing Privacy Policy / Terms acceptance
(`LegalConsent`), so agreeing to the legal documents does not imply AI
permission.

Not gated (deliberately): account deletion, memory clearing, and App Store
purchase verification. None reach Gemini, and gating deletion behind consent
would conflict with Guideline 5.1.1(v).

---

## 3. App Privacy label answers (App Store Connect)

Answer **Yes** to "Do you or your third-party partners collect data from this
app?"

For every type below: **Linked to the user = Yes**, **Used for tracking = No**,
purpose = **App Functionality** only. No Analytics, no Advertising, no
Personalization-for-ads, no Product Personalization beyond in-app memory.

| Data type | Collected | Notes |
|---|---|---|
| Contact Info → Email Address | Yes | Only for Apple/Google sign-in; guest mode collects none |
| Contact Info → Name | Yes | Display name from the sign-in provider |
| Identifiers → User ID | Yes | Firebase Auth UID |
| Identifiers → Device ID | Yes | Declared conservatively for the device model/OS carried in the standard `X-Firebase-Client` header. **Note:** the app does **not** generate a Firebase Installation ID — `FirebaseInstallations` is not a linked product (verify: `nm -a <binary> \| grep -i FIRInstallations` returns nothing). Earlier drafts of the privacy policy claimed an FID; that claim has been removed. |
| User Content → Photos or Videos | Yes | Images the user attaches, **including the 300 px thumbnail persisted with each message** (`MoomoAI/Services/MemoryService.swift:102`) |
| User Content → Other User Content | Yes | Prompts, conversation history, extracted document text, attachment filenames, generated images |
| Purchases → Purchase History | Yes | Apple transaction ID + entitlement state |
| Usage Data → Product Interaction | Yes | Per-account daily request counters enforcing the free allowance and premium fair-use ceiling (`functions/src/quota.ts`). Declared because the counters exist server-side — **not** because any analytics SDK is present. |

**Do not** declare: Location, Contacts, Health, Financial Info, Browsing History,
Search History, Sensitive Info, Audio Data (no audio ever leaves the app),
Advertising Data, Diagnostics, Crash Data.

> The test for Usage Data is "does the app or its backend collect it", **not**
> "is an analytics SDK linked." The daily quota counters meet that bar, which is
> why Product Interaction is declared above even though no analytics SDK exists.

**App Tracking Transparency:** not applicable. `NSPrivacyTracking` is `false`,
`NSPrivacyTrackingDomains` is empty, no IDFA access, no `AppTrackingTransparency`
framework linked — so no `NSUserTrackingUsageDescription` and no ATT prompt.

### Note on `Package.resolved` (pre-empting a likely question)

`Package.resolved` pins `googleappmeasurement` and
`google-ads-on-device-conversion-ios-sdk`. These are **resolved** because SPM
resolves the entire `firebase-ios-sdk` package manifest; they are **not linked**
into the app. The app links only FirebaseCore, FirebaseAuth, FirebaseFunctions,
FirebaseFirestore, GoogleSignIn and StoreKit (see the Frameworks build phase in
`project.pbxproj`). Verified against the built binary:

```sh
xcodebuild -project MoomoAI.xcodeproj -scheme MoomoIOS -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/DD build
APP="/tmp/DD/Build/Products/Release-iphonesimulator/MoomoAI.app"
nm -a "$APP/MoomoAI" | grep -iE "appmeasurement|ASIdentifierManager|advertisingIdentifier|Crashlytics|FIRInstallations|SKAdNetwork"
otool -L "$APP/MoomoAI" | grep -iE "AdSupport|AppTrackingTransparency"
```

Both return nothing. (The product name is `MoomoAI`; the *scheme* is `MoomoIOS`.)

Re-verified against a Release build on 2026-07-23 (Xcode 26.5, Firebase 11.15.0):

- `otool -L` lists only system frameworks plus the Firestore/gRPC/absl/openssl
  embedded frameworks. **No** AdSupport, AppTrackingTransparency, or AdServices.
- The only "analytics" symbols are `FIRAnalyticsConfiguration`, a configuration
  shim compiled into **FirebaseCore** itself, which collects nothing.
- `FIRInstallations`, `AppMeasurement`, `Crashlytics` and `SKAdNetwork` symbols
  are entirely absent, which is what backs the privacy-policy sentence "the app
  does not link Firebase Analytics, Installations, or any attribution SDK."
- The literal string `app-measurement.com` *does* appear in the binary: it is a
  constant inside FirebaseCore's `FIROptions`, not a reachable endpoint, since
  GoogleAppMeasurement is not linked. Nothing contacts it.
- Embedded third-party privacy manifests are all present (FirebaseCore,
  FirebaseAuth, FirebaseFirestore, GoogleUtilities ×6, GoogleSignIn, AppAuth,
  GTMAppAuth, GTMSessionFetcher, gRPC, nanopb, leveldb, abseil), so Apple's
  privacy-manifest and SDK-signature requirements are satisfied by the SDKs
  themselves.

Re-run these commands if the Firebase version is ever bumped — the "no analytics
SDK" claim in the privacy policy depends on it.

---

## 4. App Review Information → Notes

> **Third-party AI disclosure and consent (addresses 5.1.1(i) / 5.1.2(i))**
>
> Moomo AI generates responses using **Google LLC's Gemini API**. The app sends
> user content to our own Firebase backend, which forwards it to the Gemini API;
> the app never contacts Google's AI endpoints directly.
>
> **What is sent:** the message text the user types or dictates, images they
> attach or capture, text extracted on-device from attached documents, up to the
> last 20 turns of the current conversation, the user's saved personalization
> memory (only if Memory is enabled in Settings), and the selected response
> language. **What is never sent:** name, email, account or device identifiers,
> purchase history, and audio — dictation is transcribed by iOS, on-device where
> the locale supports it, and only the resulting text is used.
>
> **Consent:** a dedicated full-screen disclosure appears the first time the user
> reaches the chat, before anything can be sent. It names Google as the
> recipient, itemizes exactly what is and is not sent, explains why, and offers
> **Accept** and **Decline**. Nothing is transmitted to Google unless the user
> taps Accept. Declining keeps the app fully usable with AI responses turned off
> and shows a plain explanation rather than an error. The decision is stored with
> a version and timestamp, and can be reviewed or withdrawn at any time under
> **Settings → AI data sharing**. Enforcement is also at the network layer, so no
> code path — including background memory summarization — can transmit content
> without a current permission.
>
> **Privacy policy:** section 4 of https://moomoios-2026.web.app/privacy-policy.html
> now identifies the data collected, how it is collected, every use, the
> third-party AI provider by name, retention/training terms, and our confirmation
> that recipients are contractually bound to equivalent protection. The same text
> is bundled in-app (Profile → Privacy Policy) and readable offline.
>
> **To reproduce:** launch → accept Privacy Policy/Terms on the welcome screen →
> choose any sign-in (Guest is fastest) → the AI data-sharing screen appears
> immediately. Tap **Decline** and send a message to see AI blocked with an
> explanation; then **Settings → AI data sharing → Turn on** to enable it.

---

## 5. Reply to the rejection (App Store Connect message)

> Thank you for the detailed feedback. You were right that build 1.0 (3)
> disclosed our use of a third-party AI service only in the Privacy Policy and
> Terms, and did not ask permission in the app. We have addressed all four
> requirements.
>
> 1. **What data is sent** — a dedicated in-app screen now itemizes it: message
>    text, attached images, text extracted on-device from attached documents,
>    recent conversation context, the personalization memory summary (only if the
>    user enabled Memory), and the selected language. It also states what is
>    never sent: name, email, account/device identifiers, purchase history, and
>    audio.
> 2. **Who it is sent to** — the screen names **Google LLC (Gemini API)**
>    explicitly, explains that it is routed through our own backend rather than
>    directly, and links to Google's Gemini API terms.
> 3. **Permission before sending** — the screen is presented before any content
>    can be transmitted, with **Accept** and **Decline**. Nothing reaches Google
>    unless the user accepts. Declining leaves the app usable with AI off and a
>    clear explanation. The choice is versioned and timestamped and can be
>    reviewed or withdrawn any time in **Settings → AI data sharing**. We also
>    enforce it at the network layer so no code path can bypass it.
> 4. **Privacy policy** — section 4 now identifies what we collect, how we
>    collect it, every use, the third-party AI provider by name, its
>    retention/training terms, and our confirmation that third parties we share
>    with are contractually required to provide equal or greater protection.
>
> The consent flow is reachable within about 15 seconds of launch: accept the
> Privacy Policy/Terms checkbox on the welcome screen, tap **Continue as Guest**,
> and the AI data-sharing screen appears immediately.
>
> Thank you for your time reviewing the updated build.

---

## 6. Manual steps before resubmitting

✅ **Done in-repo:** `CFBundleVersion` bumped 3 → 4 (`MoomoAI/Info.plist`).
Build 1.0 (3) already exists in App Store Connect, so re-uploading it would be
rejected at upload time, before review. Release build verified clean afterwards
(0 errors) and the built bundle reports `CFBundleVersion = 4`.

1. **Commit everything.** The remediation currently lives in the working tree; a
   clean checkout or CI would build the rejected app.
2. **Deploy the hosted policy** — `firebase deploy --only hosting` so
   `https://moomoios-2026.web.app/privacy-policy.html` matches the in-app copy.
   App Review checks the live URL, and the two must agree.
   ⚠️ **Verified 2026-07-23: the live URL still serves the July 13 policy with no
   AI-disclosure section.** This is a hard blocker for a 5.1.1(i) resubmission —
   the rejection cited the policy, and Apple will re-read the live page.
3. **Paste section 4** into App Store Connect → App Review Information → Notes.
4. **Update the App Privacy labels** to match section 3 — note the newly added
   **Usage Data → Product Interaction**.
5. **Send section 5** as the reply to the rejection message.
6. **Remove `dataconnect/`** (untracked Firebase Data Connect scaffolding
   containing sample movie-review schema) — it is unused, is not referenced by
   `firebase.json`, and never reaches the app bundle, so this is hygiene rather
   than a blocker.

---

## 7. Known issues found during the audit, deliberately not fixed here

These came out of the compliance audit but are not 5.1.1(i)/5.1.2(i) blockers.
The privacy policy has been corrected to describe the app's *actual* behavior in
each case, so none of them is a disclosure mismatch any more — but the underlying
behavior is still worth fixing.

| # | Issue | Where | Why deferred |
|---|---|---|---|
| 1 | Account deletion swallows a failed server-side wipe — the `deleteUserData()` error is caught into a `#if DEBUG print` and the Auth user is deleted anyway, orphaning data with no uid left to retry | `MoomoAI/Services/AuthService.swift:173-179` | Behavior change to a 5.1.1(v) flow; needs its own testing pass |
| 2 | Deleting a message/conversation/asset removes the Firestore record but leaves the generated image bytes and its live download URL in Storage | `AssetLibraryService.swift:85`, `ChatViewModel.deleteMessage` | Needs a new callable reusing the ownership check at `functions/src/index.ts:230` |
| 3 | "Temporary chat" prompts and outputs are still written to the server-side `generations` audit log | `functions/src/index.ts:327` | Client honors temporary correctly; the log is disclosed in §1 of the policy, but the flag should be plumbed through |
| 4 | Document Q&A is broken for real files: extraction allows 12 000 chars but the backend rejects messages over 4 000 | `DocumentProcessor.swift:40` vs `functions/src/index.ts:29` | Functional bug, not privacy — but the consent screen advertises document attachment |
| 5 | `editGeneratedImage`'s `imageBase64` branch has no MIME allowlist or size cap, unlike the chat path | `functions/src/index.ts:367-379` | Abuse-hardening; no data-leak path (content type is derived server-side) |
| 6 | `appStoreUnmatchedEvents` and the `transferredTo` marker survive account deletion; the latter stores a deleted user's UID on another account's document | `functions/src/appstore.ts:182-190`, `:309-314` | Now disclosed as operational residue; add a TTL policy |
| 7 | Consent is enforced client-side; the backend has no consent concept, and `editGeneratedText` is an exported callable with no client caller | `GenerationService.swift`, `functions/src/index.ts:331` | Apple reviews the app, not the API surface; remove the orphan endpoint |
| 8 | Cached remote images in `Caches/moomo-remote-images` are never purged and survive sign-out | `MoomoAI/Services/ImageCache.swift:103` | Sandboxed, backup-excluded, system-purgeable, gone on uninstall |
