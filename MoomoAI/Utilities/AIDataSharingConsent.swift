//
//  AIDataSharingConsent.swift
//  MoomoAI
//
//  Explicit, versioned permission to send the user's content to the third-party
//  AI provider (App Review Guidelines 5.1.1(i) and 5.1.2(i)).
//
//  Apple's position is that a Privacy Policy / Terms acceptance is NOT sufficient
//  on its own: before any personal data reaches a third-party AI service the app
//  must separately disclose WHAT is sent, WHO receives it, and obtain the user's
//  permission. The welcome-screen legal checkbox (LegalConsent) covers the
//  documents; this type covers the AI data-sharing permission itself, and the two
//  are stored and versioned independently.
//
//  This file is the single source of truth for the provider identity and the
//  disclosure copy — AIDataConsentView, SettingsView, the bundled Privacy Policy
//  and the hosted policy all speak with one voice because they read from here.
//

import Foundation
import Combine

// MARK: - Provider identity

/// The third-party AI service that actually processes user content. Naming it in
/// exactly one place keeps the consent screen, the settings screen and the
/// privacy policy from drifting apart as providers change.
enum AIProvider {
    /// Legal entity receiving the data.
    static let company = "Google LLC"
    /// Product name users will recognize, used inside sentences.
    static let service = "Google's Gemini API"
    /// Short form for buttons, titles and tight labels.
    static let shortName = "Google"
    /// Provider's own privacy documentation, linked from the consent screen so
    /// the user can read the recipient's terms before accepting.
    static let privacyURL = URL(string: "https://ai.google.dev/gemini-api/terms")!
}

// MARK: - Disclosure copy

/// The exact user-facing disclosure. Kept as data (not inlined in the view) so
/// the same wording can be reused in Settings and asserted in tests.
enum AIDataSharingDisclosure {
    static let title = "How Moomo uses AI"

    /// One-sentence summary shown at the top of the consent screen.
    static let summary =
        "Moomo AI sends the text you enter, any images or documents you attach, and recent " +
        "conversation context from the current chat to \(AIProvider.service) to generate AI responses."

    /// Itemized "what is sent" list — Apple asks for specificity, not a gesture.
    static let itemsSent: [String] = [
        "The text of the messages you send",
        "Images you attach or capture, and text extracted from documents you attach",
        "Recent messages from the current conversation, for context",
        "Your saved personalization memory, if you have Memory turned on",
        "Your chosen response language",
    ]

    /// Explicitly what is NOT sent — reviewers look for this boundary.
    static let itemsNotSent: [String] = [
        "Your name, email address or account identifier",
        "Voice recordings — dictation is transcribed by iOS, on your device where your language supports it, and only the resulting text is ever sent",
        "Your contacts, location, photos you did not attach, or advertising identifiers",
    ]

    /// Who receives it and why.
    static let recipient =
        "Your content is sent over an encrypted connection to Moomo's backend, which forwards it to " +
        "\(AIProvider.company) (\(AIProvider.service)) purely to generate the response you asked for. " +
        "Google processes it as our service provider under the Gemini API terms and does not use it to " +
        "train its models. Moomo does not sell your data or share it for advertising."

    /// Guidance + the consent sentence itself.
    static let caution =
        "Do not include sensitive personal information unless you choose to share it."

    static let consentSentence =
        "By tapping Accept, you consent to this data being sent to \(AIProvider.company) for processing."

    /// Shown after a decline, and in Settings when sharing is off.
    static let declinedExplanation =
        "AI responses are turned off. Moomo can't answer messages, analyze images or create images " +
        "without sending your content to \(AIProvider.company). You can turn this on any time in " +
        "Settings → AI data sharing."

    /// Short message surfaced in the chat when a request is blocked.
    static let blockedMessage =
        "AI responses are off because you haven't allowed Moomo to send your content to " +
        "\(AIProvider.company). Turn on AI data sharing to continue."

    /// The whole disclosure as plain text, for the read-only view in Settings
    /// (rendered through LegalDocumentSheet) and for the bundled privacy policy.
    /// Assembled from the same constants the consent screen renders, so the two
    /// can never say different things.
    static var plainText: String {
        var lines: [String] = [
            title.uppercased(),
            "",
            summary,
            "",
            "WHAT IS SENT",
            "",
        ]
        lines += itemsSent.map { "• \($0)" }
        lines += ["", "WHAT IS NEVER SENT", ""]
        lines += itemsNotSent.map { "• \($0)" }
        lines += [
            "",
            "WHO RECEIVES IT",
            "",
            recipient,
            "",
            "IMPORTANT",
            "",
            caution,
            "",
            "You can turn AI data sharing on or off at any time in Settings → AI data sharing. " +
            "With it off, Moomo cannot generate responses, analyze images, or create images, and no " +
            "content is sent to \(AIProvider.company).",
        ]
        return lines.joined(separator: "\n")
    }
}

// MARK: - Consent record

/// Versioned, timestamped record of the user's AI data-sharing decision.
///
/// Stored in UserDefaults alongside the version of the disclosure that was shown
/// and the provider it named. If either the disclosure text or the provider
/// materially changes, bump `currentVersion` — every user is then asked again
/// rather than silently inheriting permission for a different arrangement.
final class AIDataSharingConsent: ObservableObject {
    static let shared = AIDataSharingConsent()

    /// Bump when the disclosure copy or the receiving provider materially
    /// changes. Stored decisions from an older version no longer count as
    /// permission, so the consent screen is presented again.
    static let currentVersion = "2026-07-23"

    // UserDefaults keys (namespaced to avoid colliding with LegalConsent).
    static let statusKey = "moomo.aiDataSharing.status"
    static let versionKey = "moomo.aiDataSharing.version"
    static let decidedAtKey = "moomo.aiDataSharing.decidedAt"
    static let providerKey = "moomo.aiDataSharing.provider"

    enum Status: String {
        /// Never asked, or asked under an older disclosure version.
        case undecided
        /// Explicitly allowed — AI requests may proceed.
        case granted
        /// Explicitly refused — AI requests must be blocked, app stays usable.
        case declined
    }

    /// Published so SwiftUI re-renders when the decision changes.
    @Published private(set) var status: Status

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.status = Self.readStatus(from: defaults)
    }

    /// True only for an explicit, current-version acceptance. Everything else —
    /// undecided, declined, or accepted under a superseded disclosure — is false,
    /// so the safe path is also the default path.
    var isGranted: Bool { status == .granted }

    /// The user saw the disclosure and said no. Distinct from `undecided` so the
    /// UI can explain the consequence instead of re-prompting on every tap.
    var isDeclined: Bool { status == .declined }

    /// When the current decision was made, for the audit trail and Settings.
    var decidedAt: Date? {
        guard let raw = defaults.string(forKey: Self.decidedAtKey) else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    /// Provider named in the disclosure the user actually agreed to.
    var recordedProvider: String? { defaults.string(forKey: Self.providerKey) }

    // MARK: - Recording

    /// Persist an explicit Accept.
    func grant() { record(.granted) }

    /// Persist an explicit Decline. AI stays blocked until the user changes it.
    func decline() { record(.declined) }

    /// Withdraw a previously granted permission (Settings → AI data sharing).
    /// Recorded as a decline so the app blocks requests and explains why.
    func revoke() { record(.declined) }

    private func record(_ newStatus: Status) {
        defaults.set(newStatus.rawValue, forKey: Self.statusKey)
        defaults.set(Self.currentVersion, forKey: Self.versionKey)
        defaults.set(ISO8601DateFormatter().string(from: Date()), forKey: Self.decidedAtKey)
        defaults.set(AIProvider.company, forKey: Self.providerKey)
        // @Published must fire on the main actor — callers are UI actions, but a
        // revoke triggered from a background path would otherwise warn.
        if Thread.isMainThread {
            status = newStatus
        } else {
            DispatchQueue.main.async { self.status = newStatus }
        }
    }

    /// Test/support hook: forget the decision entirely (returns to `undecided`).
    func reset() {
        defaults.removeObject(forKey: Self.statusKey)
        defaults.removeObject(forKey: Self.versionKey)
        defaults.removeObject(forKey: Self.decidedAtKey)
        defaults.removeObject(forKey: Self.providerKey)
        if Thread.isMainThread {
            status = .undecided
        } else {
            DispatchQueue.main.async { self.status = .undecided }
        }
    }

    // MARK: - Storage

    /// A stored decision only counts while it matches the current disclosure
    /// version — a superseded acceptance reads back as `undecided`, which forces
    /// a fresh ask instead of assuming permission carries over.
    private static func readStatus(from defaults: UserDefaults) -> Status {
        guard defaults.string(forKey: versionKey) == currentVersion,
              let raw = defaults.string(forKey: statusKey),
              let stored = Status(rawValue: raw) else {
            return .undecided
        }
        return stored
    }

    /// Non-observing check for callers that cannot hold the object (the
    /// generation transport guard). Reads the same keys and applies the same
    /// version rule, so it can never disagree with `isGranted`.
    static var isGrantedSnapshot: Bool {
        readStatus(from: .standard) == .granted
    }
}
