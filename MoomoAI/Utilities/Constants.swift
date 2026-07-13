//
//  Constants.swift
//  MoomoAI
//
//  App-wide constants — luxury "warm white + navy + gold" design system.
//  Colors are a fixed, deliberately branded light canvas (no dark-mode variants);
//  the app pins itself to light mode so the palette always renders as designed.
//

import SwiftUI

struct K {
    // MARK: - Colors (Luxury warm-white + navy + gold)
    struct Colors {
        // MARK: - Brand palette (semantic anchors)
        /// Warm white canvas.
        static let cream = Color(hex: "F7F4EE")
        /// Deep navy — send button, primary interactive ink.
        static let navy = Color(hex: "16233F")
        /// Royal navy — user message text.
        static let navyText = Color(hex: "27407C")
        /// Near-black navy — assistant body text.
        static let ink = Color(hex: "1B2333")
        /// Brand gold — "LAB AI", sparkles, accents.
        static let gold = Color(hex: "C2A878")
        /// Softer gold for hairlines and glows.
        static let goldSoft = Color(hex: "D8C6A6")
        /// Royal blue — "Moomo" wordmark on the chat home.
        static let royalBlue = Color(hex: "2A3E86")
        /// Primary brand navy — welcome-screen wordmark, inline-code ink.
        static let brandNavy = Color(hex: "253B86")
        /// Blue-grey — timestamps and read receipts.
        static let slate = Color(hex: "8C93A3")

        // MARK: - Backgrounds
        static let backgroundPrimary = cream
        static let backgroundSecondary = Color(hex: "F1ECE1")
        static let backgroundTertiary = Color(hex: "EEE8DC")

        // MARK: - Borders
        static let borderColor = Color(hex: "ECE6DA")

        // MARK: - Text
        static let textPrimary = ink
        /// Secondary text / placeholders / muted action icons.
        static let textSecondary = Color(hex: "8E8B93")

        // MARK: - Accent (app tint)
        static let accentColor = navy
    }
    
    // MARK: - Layout (Exact webapp spacing)
    struct Layout {
        static let smallCornerRadius: CGFloat = 6
        static let composerCornerRadius: CGFloat = 28
        static let padding: CGFloat = 20
    }

    // MARK: - Legal (shown on the Premium paywall; required by App Review)
    // Hosted on this app's own Firebase project (moomoios-2026); the same
    // documents are bundled in-app via LegalDocuments. Keep these URLs in sync
    // with the App Store Connect privacy-policy field and public/*.html.
    struct Legal {
        /// Moomo Terms of Service — also serves as the EULA for auto-renewable
        /// subscriptions per App Review Guideline 3.1.2 (includes renewal,
        /// cancellation, restore, and fair-use terms).
        static let termsOfUseURL = URL(string: "https://moomoios-2026.web.app/terms-of-service.html")!
        /// Hosted Moomo privacy policy.
        static let privacyPolicyURL = URL(string: "https://moomoios-2026.web.app/privacy-policy.html")!
    }
}
