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
        /// Royal purple — "Moomo" wordmark on the welcome screen.
        static let royalPurple = Color(hex: "432874")
        /// Blue-grey — timestamps and read receipts.
        static let slate = Color(hex: "8C93A3")

        // MARK: - Backgrounds
        static let backgroundPrimary = cream
        static let backgroundSecondary = Color(hex: "F1ECE1")
        static let backgroundTertiary = Color(hex: "EEE8DC")
        static let backgroundHover = Color(hex: "E9E2D3")
        static let backgroundActive = Color(hex: "E2D9C8")

        // MARK: - Borders
        static let borderColor = Color(hex: "ECE6DA")

        // MARK: - Text
        static let textPrimary = ink
        /// Secondary text / placeholders / muted action icons.
        static let textSecondary = Color(hex: "8E8B93")

        // MARK: - Accent (app tint)
        static let accentColor = navy
        static let accentHover = Color(hex: "24386E")

        // MARK: - Message
        static let messageBg = Color(hex: "F1ECE1")
        /// Composer fill.
        static let inputBg = Color.white

        // MARK: - Buttons
        static let sendButton = navy
        static let sendButtonHover = Color(hex: "0E1A30")

        // MARK: - Logo tokens (kept for compatibility; now on-brand)
        static let logoViolet = royalBlue
        static let logoRose = gold
        static let logoAmber = goldSoft
        static let logoTeal = navy
    }
    
    // MARK: - Typography (Exact webapp font sizes & weights)
    struct Typography {
        // Welcome screen
        static let welcomeTitleSize: CGFloat = 32
        static let welcomeTitleWeight: Font.Weight = .semibold
        static let welcomeSubtitleSize: CGFloat = 16
        
        // Message text
        static let messageTextSize: CGFloat = 15
        static let messageLineHeight: CGFloat = 1.6
        
        // Buttons
        static let buttonTextSize: CGFloat = 14
        static let buttonTextWeight: Font.Weight = .medium
        
        // Suggestion cards
        static let suggestionTextSize: CGFloat = 14
        static let suggestionEmojiSize: CGFloat = 20
        
        // Chat items
        static let chatItemTitleSize: CGFloat = 13
        static let chatItemPreviewSize: CGFloat = 11
        
        // Input
        static let inputTextSize: CGFloat = 15
    }
    
    // MARK: - Layout (Exact webapp spacing)
    struct Layout {
        // Corner radius
        static let cornerRadius: CGFloat = 12
        static let mediumCornerRadius: CGFloat = 8
        static let smallCornerRadius: CGFloat = 6
        static let largeCornerRadius: CGFloat = 16
        static let composerCornerRadius: CGFloat = 28
        
        // Padding
        static let padding: CGFloat = 20
        static let mediumPadding: CGFloat = 16
        static let smallPadding: CGFloat = 12
        static let tinyPadding: CGFloat = 8
        
        // Spacing
        static let itemSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 24
        
        // Sidebar
        static let sidebarWidth: CGFloat = 320
        
        // Logo (smaller like webapp)
        static let logoSize: CGFloat = 80  // Exact webapp size
        static let logoBarHeight: CGFloat = 12  // Exact webapp bar height
        static let logoBarWidth: CGFloat = 60  // Exact webapp bar width
        static let logoBarCornerRadius: CGFloat = 6
        static let logoBarSpacing: CGFloat = 6
        static let logoPadding: CGFloat = 12
    }
    
    // MARK: - Suggestions (native chat prompts sent directly to the AI)
    static let suggestions = [
        (icon: "lightbulb.fill", text: "Explain a complex topic simply"),
        (icon: "envelope.fill", text: "Help me write an email"),
        (icon: "sparkles", text: "Brainstorm some ideas"),
        (icon: "text.alignleft", text: "Summarize this text for me")
    ]
}
