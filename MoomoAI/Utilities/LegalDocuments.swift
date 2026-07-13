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
    static let privacyPolicyVersion = "2026-07-13"
    /// Bump when the Terms of Service materially change (same re-accept rule).
    static let termsOfServiceVersion = "2026-07-13"

    static let privacyPolicyTitle = "Privacy Policy"
    static let termsOfServiceTitle = "Terms of Service"

    static let privacyPolicy = """
    Moomo AI — Privacy Policy
    Effective date: July 13, 2026 · Moomolab LLC

    SUMMARY

    • Moomo AI shows no advertisements and contains no advertising or analytics SDKs.
    • We do not use Google Analytics, Firebase Analytics, Google Ads, AdMob, or any conversion-measurement or attribution technology.
    • We do not track you across apps or websites, do not access the advertising identifier (IDFA), and never show an App Tracking Transparency prompt because there is nothing to track.
    • We do not sell your personal information, and we do not share it for advertising or marketing.
    • Data we do collect exists only to run the service: your account, your conversations, your generated images, your subscription status, and daily usage counts.

    1. INFORMATION WE COLLECT

    • Account information. If you sign in with Apple or Google: your email address and display name, held in Firebase Authentication. Guest mode requires no email or name.
    • User ID. A Firebase Authentication user ID (UID) that keys your data and enforces per-account quotas (all modes, including guest).
    • Device / installation identifier. Firebase issues a Firebase Installation ID (FID) per app install. It is used solely for service infrastructure and security — never for advertising or tracking.
    • Prompts and conversations. Text you send to the AI, stored on your device and, server-side, in our generation log and your account's memory so the service can function and abuse can be audited.
    • Photos you attach. Sent transiently to generate a response; attached input photos are not persisted on our servers.
    • Generated images. Stored in your account's private storage area until you delete your account.
    • Purchase history. If you subscribe, Apple transaction identifiers and entitlement state, used only to grant premium access. Payments are handled entirely by Apple; we never see payment card details.
    • Usage counters. Daily request counts per account, used to enforce free-tier limits and premium fair-use limits.
    • Voice dictation. Dictation is performed by Apple's on-device/OS speech service. The app never uploads or stores audio; only recognized text is used, and only if you send it.

    2. WHAT WE DO NOT COLLECT

    • No advertising data, no analytics events, no crash/diagnostics SDK data.
    • No location, contacts, browsing history, health, or financial data.
    • No advertising identifier (IDFA) and no cross-app or cross-site tracking of any kind.

    3. HOW WE USE INFORMATION

    Only to operate the service: authenticate you, generate AI responses, store your content, enforce quotas, grant subscription entitlements, prevent fraud and abuse, and comply with law. We do not use your data for advertising, ad targeting, or marketing, and we do not use your conversations to train AI models.

    4. AI PROCESSING DISCLOSURE

    Your prompts and attached images are processed by Google's Gemini API through our secure backend (Firebase Cloud Functions) solely to generate the response you requested. API keys stay on the server; your content is transmitted over TLS.

    5. SERVICE PROVIDERS

    • Google LLC — Firebase (Authentication, Firestore, Cloud Functions, Storage, App Check, Installations): hosting and infrastructure, US region (us-central1).
    • Google LLC — Gemini API: AI model provider (prompts and attached images, processed transiently).
    • Apple Inc.: payments (App Store / StoreKit), Sign in with Apple, OS dictation service.
    • Google Sign-In / Sign in with Apple: authentication only (email, name).

    None of these integrations are used for advertising, analytics, attribution, or conversion measurement in Moomo AI.

    6. DATA STORAGE AND SECURITY

    Data is stored in Moomolab's Firebase project in the United States. Access is restricted by default-deny security rules: your data is readable and writable only by your authenticated account, and sensitive records are writable only by our server code. All traffic is encrypted in transit.

    7. DATA RETENTION AND DELETION

    Your data is retained until you delete your account. Deleting your account in the app (Profile → Delete Account) removes your authentication record and wipes your server-side data: profile, conversations/memory, generation log, generated images, usage counters, and purchase-entitlement mappings. Apple retains its own transaction records under its policies. You can also delete conversations locally at any time.

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
    Effective date: July 13, 2026 · Moomolab LLC

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

    5. YOUR CONTENT AND LICENSE

    You retain rights in the prompts and images you submit. You grant Moomolab the limited license needed to operate the Service (process, store, and transmit your content to our AI provider to generate responses). Subject to applicable law and the AI provider's terms, you may use generated output for personal or commercial purposes; you are responsible for verifying that a given use is lawful.

    6. PRIVACY

    Our Privacy Policy describes what we collect and how we use it. In short: no ads, no analytics SDKs, no tracking, no sale of data.

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
