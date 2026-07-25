//
//  LegalDocuments.swift
//  MoomoAI
//
//  Full text of the Privacy Policy and Terms of Service, bundled so users can
//  read both inside the app (welcome-screen consent links, paywall, profile
//  menu) without leaving the app or needing a network connection. Keep in sync
//  with the hosted copies in public/privacy-policy.html and
//  public/terms-of-service.html (same effective date).
//

import Foundation

enum LegalDocuments {
    /// Bump when the Privacy Policy materially changes; users who accepted an
    /// older version are returned to the welcome screen and must re-check the
    /// consent box before entering the app again.
    /// 2026-07-23: expanded third-party AI disclosure (Google / Gemini API),
    /// added the in-app permission flow and the equal-protection commitment.
    static let privacyPolicyVersion = "2026-07-23"
    /// Bump when the Terms of Service materially change (same re-accept rule).
    /// 2026-07-24: added the objectionable-content policy and the in-app content
    /// reporting commitment (App Review Guideline 1.2).
    static let termsOfServiceVersion = "2026-07-24"

    static let privacyPolicyTitle = "Privacy Policy"
    static let termsOfServiceTitle = "Terms of Service"

    static let privacyPolicy = """
    Moomo AI — Privacy Policy
    Effective date: July 23, 2026 · Moomolab LLC

    SUMMARY

    • Moomo AI uses a third-party AI service — Google LLC's Gemini API — to generate responses. Your messages, attachments and recent conversation context are sent there for processing. The app asks your explicit permission before sending anything, and you can withdraw it at any time in Settings → AI data sharing. See section 4.
    • Moomo AI shows no advertisements and contains no advertising or analytics SDKs.
    • We do not use Google Analytics, Firebase Analytics, Google Ads, AdMob, or any conversion-measurement or attribution technology.
    • We do not track you across apps or websites, do not access the advertising identifier (IDFA), and never show an App Tracking Transparency prompt because there is nothing to track.
    • We do not sell your personal information, and we do not share it for advertising or marketing.
    • Data we do collect exists only to run the service: your account, your conversations, your generated images, your subscription status, and daily usage counts.

    1. INFORMATION WE COLLECT

    • Account information. If you sign in with Apple or Google: your email address and display name, held in Firebase Authentication. Guest mode requires no email or name.
    • User ID. A Firebase Authentication user ID (UID) that keys your data and enforces per-account quotas (all modes, including guest).
    • Connection and device metadata. Requests to Firebase carry your IP address and a standard client header identifying the SDK version, OS version, and device model. This is inherent to making a network request, is used only to operate and secure the service, and is never used for advertising or tracking. Moomo does not generate or store an advertising identifier, and the app does not link Firebase Analytics, Installations, or any attribution SDK.
    • Prompts and conversations. Text you send to the AI, collected when you type or dictate it and tap send. Stored on your device and, server-side, in our generation log and your account's memory so the service can function and abuse can be audited. Also sent to Google's Gemini API to generate a response — see section 4.
    • Photos you attach or capture. Collected when you pick a photo or take a picture. The image is sent to Google to generate a response and the full-size copy is not retained on our servers. A small thumbnail (about 300 pixels) IS saved alongside that message in your account so the conversation reloads correctly on your devices and follow-up questions about the image still work. It is deleted when you delete the message, the conversation, or your account. If you ask Moomo to EDIT a photo, the edited result is saved to your account like any other generated image until you delete it.
    • Documents you attach. Text is extracted on your device and only that text is sent — the file itself is never uploaded. The filename, file type, and where you picked it from are saved with your conversation so the document appears in your Library.
    • AI data-sharing decision. Your Accept/Decline choice, the version of the disclosure you saw, and the timestamp, stored locally on your device so we can honor it and prove when it was given.
    • Generated images. Stored in your account's own storage area until you delete your account, and served over unguessable private links (see section 6).
    • Purchase history. If you subscribe, Apple transaction identifiers and entitlement state, used only to grant premium access. Payments are handled entirely by Apple; we never see payment card details.
    • Usage counters. Daily request counts per account, used to enforce free-tier limits and premium fair-use limits.
    • Voice dictation. Dictation is performed by Apple's speech recognition, on your device wherever your language supports on-device recognition. If your language has no on-device model, iOS falls back to Apple's speech service and the audio is processed by Apple under Apple's privacy policy. Moomo itself never receives, uploads, or stores your audio — only the recognized text, and only if you choose to send it.

    2. WHAT WE DO NOT COLLECT

    • No advertising data, no analytics events, no crash/diagnostics SDK data.
    • No location, contacts, browsing history, health, or financial data.
    • No advertising identifier (IDFA) and no cross-app or cross-site tracking of any kind.

    3. HOW WE USE INFORMATION

    Only to operate the service: authenticate you, generate AI responses (which requires sending your content to Google's Gemini API — see section 4), store your content, enforce quotas, grant subscription entitlements, prevent fraud and abuse, and comply with law. We do not use your data for advertising, ad targeting, or marketing, and we do not use your conversations to train AI models.

    How we collect it: directly from you when you type, dictate, attach a photo or document, or make a purchase; from Apple or Google when you choose to sign in with them (email and display name only); and automatically from the app itself for the technical identifiers and usage counters described in section 1. We do not collect anything from third-party data brokers, and we run no tracking or analytics SDKs.

    4. AI PROCESSING DISCLOSURE AND YOUR PERMISSION

    WHO PROCESSES YOUR CONTENT. Moomo AI's responses are generated by Google LLC using the Gemini API. Your content does not go directly from the app to Google: the app sends it over an encrypted (TLS) connection to Moomo's own backend (Firebase Cloud Functions), which forwards it to the Gemini API and returns the response. Our API keys stay on the server and are never shipped to the app.

    EXACTLY WHAT IS SENT TO GOOGLE:
    • The text of the messages you send.
    • Images you attach or capture, and text extracted on your device from documents you attach (the document file itself is never uploaded).
    • Recent messages from the current conversation (up to the last 20 turns), for context.
    • Your saved personalization memory summary, only if Memory is turned on in Settings.
    • Your chosen response language, and Moomo's own system instructions.

    WHAT IS NEVER SENT TO GOOGLE. Your name, email address, account identifier, purchase history, and usage counters are not included in requests to the Gemini API. Voice dictation is transcribed by iOS (on-device where your language supports it) and only the resulting text is ever sent — no audio is ever uploaded to us or to Google. We do not send your contacts, location, photos you did not attach, or any advertising identifier.

    WE ASK YOUR PERMISSION FIRST. Before any of your content is sent to Google, Moomo AI shows a dedicated in-app screen that names Google as the recipient, itemizes what will be sent, and asks you to Accept or Decline. Nothing is sent to the Gemini API unless you accept. If you decline, AI features are switched off and the rest of the app keeps working; you can change your decision at any time in Settings → AI data sharing, which also shows you what is shared and lets you turn it back off. Turning it off stops all further transmission of your content to Google.

    RETENTION AND TRAINING. Google processes this content as our service provider to generate the response you asked for. Under the Gemini API terms that apply to our paid API usage, Google does not use the content submitted through our API key to train its models, and does not retain it beyond the transient processing needed to serve the request (Google may retain content briefly for abuse monitoring as described in its terms). Moomo does not use your conversations to train any AI model.

    EQUAL PROTECTION COMMITMENT. We share personal data only with the service providers listed below, only for the purposes listed, and only under contractual terms (Google Cloud / Gemini API terms and Apple's developer terms) that require them to protect that data to a standard at least equal to the protections described in this policy. None of them is permitted to use your data for their own advertising or profiling.

    5. SERVICE PROVIDERS

    • Google LLC — Gemini API: the third-party AI service that generates responses. Receives prompt text, attached images, on-device-extracted document text, recent conversation context, and your memory summary (if enabled), processed transiently. Reached via our backend, never directly from the app.
    • Google LLC — Firebase (Authentication, Firestore, Cloud Functions, Cloud Storage): hosting and infrastructure, US region (us-central1). Stores your account record, conversations, generated images, entitlements, and usage counters.
    • Apple Inc.: payments (App Store / StoreKit), Sign in with Apple, on-device dictation.
    • Google Sign-In / Sign in with Apple: authentication only (email, name).

    None of these integrations are used for advertising, analytics, attribution, or conversion measurement in Moomo AI. We do not sell personal data or share it for cross-context behavioral advertising.

    6. DATA STORAGE AND SECURITY

    Data is stored in Moomolab's Firebase project in the United States. Your account records, conversations, and messages are protected by default-deny security rules: they are readable and writable only by your authenticated account, and sensitive records are writable only by our server code. All traffic is encrypted in transit.

    Generated and edited images are the one exception to rule-based access: each is served over an unguessable, randomly-generated link (a 122-bit token). The link does not expire, and anyone who obtains it could view that image, so it is only ever delivered to you through your rules-protected conversation. Deleting your account deletes the underlying images and their links.

    7. DATA RETENTION AND DELETION

    Your data is retained until you delete your account. Deleting your account in the app (Profile → Delete Account) removes your authentication record and wipes your server-side data: profile, conversations and messages (including attached-photo thumbnails), memory, generation log, generated images, usage counters, and purchase-entitlement mappings.

    Two things outlive account deletion, neither of which identifies you to a person: (a) operational server logs, which record account identifiers, request counts and sizes — never your prompts, messages, or image content — and are automatically discarded on our hosting provider's standard 30-day schedule; and (b) Apple's own transaction records, retained by Apple under Apple's policies. You can also delete individual conversations, or all of them, at any time.

    8. YOUR RIGHTS

    You may access your content in the app, delete it, or delete your entire account in the app. For any privacy request (access, deletion, correction, complaint), contact us at the address below and we will respond within 30 days. Depending on your jurisdiction (e.g., GDPR, CCPA), you may have additional rights to access, portability, correction, deletion, and objection; we honor these on request.

    9. COOKIES AND LOCAL STORAGE

    The app stores your chat sessions and preferences locally on your device. The app does not use advertising or analytics cookies.

    10. CHILDREN'S PRIVACY

    Moomo AI is not directed at children under 13, and we do not knowingly collect personal information from children under 13. If you believe a child has provided us personal information, contact us and we will delete it.

    11. INTERNATIONAL DATA TRANSFERS

    Data is processed and stored in the United States. By using the service you understand your data is transferred to and processed in the US, subject to the safeguards of our service providers listed above.

    12. CHANGES TO THIS POLICY

    We will post any changes in the app and on our website and update the effective date. Material changes will be highlighted.

    13. CONTACT

    Moomolab LLC — moomolab@gmail.com
    """

    static let termsOfService = """
    Moomo AI — Terms of Service
    Effective date: July 24, 2026 · Moomolab LLC

    These Terms of Service ("Terms") are an agreement between you and Moomolab LLC ("Moomolab", "we") governing your use of the Moomo AI application and related services (the "Service"). By using the Service you agree to these Terms. These Terms also serve as the end-user license agreement (EULA) for the app.

    1. THE SERVICE

    Moomo AI provides AI-powered text conversation and image generation. The Service contains no advertising. AI output is generated by machine-learning models and may be inaccurate, incomplete, or offensive despite our safeguards; it is not professional (medical, legal, financial, or other) advice. You are responsible for evaluating output before relying on it.

    2. ACCOUNTS

    You may use the Service as a guest or sign in with Apple or Google. You are responsible for activity under your account. You must be at least 13 years old (or the minimum age of digital consent in your country) to use the Service.

    3. SUBSCRIPTIONS AND PURCHASES

    • Premium features are offered through auto-renewable subscriptions billed by Apple through your App Store account.
    • Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings. Payment is charged at confirmation of purchase.
    • Use "Restore Purchases" in the app to re-activate an existing subscription on a new device or account session.
    • Fair use: premium tiers described as "unlimited" are subject to a fair-use limit (currently 500 AI requests per day) to prevent abuse and keep the Service available for everyone.
    • Refunds are handled by Apple under Apple's policies.

    4. ACCEPTABLE USE

    You agree not to: violate law; attempt to bypass quotas, security rules, or entitlement checks; probe or disrupt the Service; generate or distribute content that is illegal, infringing, or intended to harm others; misrepresent AI output as human-authored where that matters; or use the Service to develop competing models from our output at scale.

    OBJECTIONABLE CONTENT AND REPORTING. We have zero tolerance for objectionable content, including material that is unlawful, hateful, harassing, sexually explicit, or that promotes violence or harm. You can report objectionable AI output at any time using the Report control available on any AI message or generated image. We review every report and will remove content that violates these Terms and, where warranted, suspend or terminate the accounts responsible.

    5. YOUR CONTENT AND LICENSE

    You retain rights in the prompts and images you submit. You grant Moomolab the limited license needed to operate the Service — specifically, to process, store, and transmit your content to our AI provider, Google LLC (Gemini API), to generate responses. We ask for your permission in the app before sending your content to Google, and you can withdraw it at any time in Settings → AI data sharing; see section 4 of the Privacy Policy. Subject to applicable law and Google's Gemini API terms, you may use generated output for personal or commercial purposes; you are responsible for verifying that a given use is lawful.

    6. PRIVACY

    Our Privacy Policy describes what we collect and how we use it. In short: your messages and attachments are sent to Google LLC (Gemini API) to generate responses, with your permission and never before you grant it; no ads, no analytics SDKs, no tracking, no sale of data.

    7. LICENSE

    We grant you a personal, non-exclusive, non-transferable, revocable license to use the app on Apple-branded devices you own or control, as permitted by the App Store terms. We may update, change, or discontinue features at any time.

    8. TERMINATION

    You may stop using the Service and delete your account in the app at any time. We may suspend or terminate accounts that violate these Terms or abuse the Service. Sections 5, 9, 10, and 11 survive termination.

    9. DISCLAIMERS

    The Service is provided "as is" and "as available", without warranties of any kind, express or implied, including merchantability, fitness for a particular purpose, and non-infringement. We do not warrant that the Service will be uninterrupted, error-free, or that AI output will be accurate.

    10. LIMITATION OF LIABILITY

    To the maximum extent permitted by law, Moomolab's total liability for any claim arising out of the Service is limited to the greater of the amount you paid us in the 12 months before the claim or USD 50. We are not liable for indirect, incidental, special, consequential, or punitive damages. Some jurisdictions do not allow these limitations; in that case they apply to the fullest extent permitted.

    11. GENERAL

    These Terms are governed by the laws applicable where Moomolab LLC is organized, without regard to conflict-of-law rules. If any provision is unenforceable, the rest remains in effect. These Terms plus the Privacy Policy are the entire agreement regarding the Service. Apple is not a party to these Terms and is not responsible for the app or its content, but Apple and its subsidiaries are third-party beneficiaries of Section 7 and may enforce it.

    12. CHANGES

    We may update these Terms; we will post changes in the app and update the effective date. Continued use after changes means you accept them.

    13. CONTACT

    Moomolab LLC — moomolab@gmail.com
    """
}

// MARK: - Consent record

/// Persisted record of the user's explicit agreement to the current legal
/// documents (UserDefaults). Written only after a Google / Apple / Guest
/// continuation actually succeeds — checking the box alone records nothing,
/// and a cancelled or failed sign-in never persists consent. Bumping either
/// document version above invalidates the record, which sends returning users
/// back to the welcome screen for renewed acceptance.
enum LegalConsent {
    static let acceptedPrivacyVersionKey = "acceptedPrivacyVersion"
    static let acceptedTermsVersionKey = "acceptedTermsVersion"
    static let acceptedAtKey = "acceptedAt"
    static let consentMethodKey = "consentMethod"

    /// True when the stored acceptance matches both current document versions.
    static var hasAcceptedCurrentVersions: Bool {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: acceptedPrivacyVersionKey) == LegalDocuments.privacyPolicyVersion
            && defaults.string(forKey: acceptedTermsVersionKey) == LegalDocuments.termsOfServiceVersion
    }

    /// Called by AuthService after a successful sign-in.
    /// `method` is "google", "apple", or "guest".
    static func recordAcceptance(method: String) {
        let defaults = UserDefaults.standard
        defaults.set(LegalDocuments.privacyPolicyVersion, forKey: acceptedPrivacyVersionKey)
        defaults.set(LegalDocuments.termsOfServiceVersion, forKey: acceptedTermsVersionKey)
        defaults.set(ISO8601DateFormatter().string(from: Date()), forKey: acceptedAtKey)
        defaults.set(method, forKey: consentMethodKey)
    }
}
