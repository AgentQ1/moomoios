//
//  Constants.swift
//  MoomoAI
//
//  App-wide constants - EXACT match to webapp with Dark/Light mode support
//

import SwiftUI

// MARK: - Adaptive Color Extension
private extension Color {
    /// Creates an adaptive color that responds to light/dark mode
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .light, .unspecified:
                return UIColor(light)
            case .dark:
                return UIColor(dark)
            @unknown default:
                return UIColor(dark)
            }
        })
        #else
        self = dark
        #endif
    }
}

struct K {
    // MARK: - Colors (Adaptive Dark/Light mode - matches webapp exactly)
    struct Colors {
        // MARK: - Backgrounds
        /// Primary background: Dark: #1a1a1a, Light: #ffffff
        static let backgroundPrimary = Color(
            light: Color(red: 1.0, green: 1.0, blue: 1.0),
            dark: Color(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0)
        )
        
        /// Secondary background: Dark: #1e1e1e, Light: #f5f5f5
        static let backgroundSecondary = Color(
            light: Color(red: 0xf5/255.0, green: 0xf5/255.0, blue: 0xf5/255.0),
            dark: Color(red: 0x1e/255.0, green: 0x1e/255.0, blue: 0x1e/255.0)
        )
        
        /// Tertiary background: Dark: #242424, Light: #f0f0f0
        static let backgroundTertiary = Color(
            light: Color(red: 0xf0/255.0, green: 0xf0/255.0, blue: 0xf0/255.0),
            dark: Color(red: 0x24/255.0, green: 0x24/255.0, blue: 0x24/255.0)
        )
        
        /// Hover background: Dark: #2a2a2a, Light: #e8e8e8
        static let backgroundHover = Color(
            light: Color(red: 0xe8/255.0, green: 0xe8/255.0, blue: 0xe8/255.0),
            dark: Color(red: 0x2a/255.0, green: 0x2a/255.0, blue: 0x2a/255.0)
        )
        
        /// Active background: Dark: #323232, Light: #e0e0e0
        static let backgroundActive = Color(
            light: Color(red: 0xe0/255.0, green: 0xe0/255.0, blue: 0xe0/255.0),
            dark: Color(red: 0x32/255.0, green: 0x32/255.0, blue: 0x32/255.0)
        )
        
        // MARK: - Borders
        /// Border color: Dark: #3a3a3a, Light: #d0d0d0
        static let borderColor = Color(
            light: Color(red: 0xd0/255.0, green: 0xd0/255.0, blue: 0xd0/255.0),
            dark: Color(red: 0x3a/255.0, green: 0x3a/255.0, blue: 0x3a/255.0)
        )
        
        // MARK: - Text
        /// Primary text: Dark: #e3e3e3, Light: #1a1a1a
        static let textPrimary = Color(
            light: Color(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0),
            dark: Color(red: 0xe3/255.0, green: 0xe3/255.0, blue: 0xe3/255.0)
        )
        
        /// Secondary text: Dark: #b8b8b8, Light: #666666
        static let textSecondary = Color(
            light: Color(red: 0x66/255.0, green: 0x66/255.0, blue: 0x66/255.0),
            dark: Color(red: 0xb8/255.0, green: 0xb8/255.0, blue: 0xb8/255.0)
        )
        
        // MARK: - Accent (same in both modes)
        /// Accent color: #8B5CF6 (Moomo Violet)
        static let accentColor = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0)
        
        /// Accent hover: #A78BFA
        static let accentHover = Color(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0)
        
        // MARK: - Message
        /// Message background: Dark: #2a2a2a, Light: #f5f5f5
        static let messageBg = Color(
            light: Color(red: 0xf5/255.0, green: 0xf5/255.0, blue: 0xf5/255.0),
            dark: Color(red: 0x2a/255.0, green: 0x2a/255.0, blue: 0x2a/255.0)
        )
        
        /// Input background: Dark: #242424, Light: #ffffff
        static let inputBg = Color(
            light: Color(red: 1.0, green: 1.0, blue: 1.0),
            dark: Color(red: 0x24/255.0, green: 0x24/255.0, blue: 0x24/255.0)
        )
        
        // MARK: - Buttons
        /// Send button: #7C3AED (Moomo Violet dark)
        static let sendButton = Color(red: 0x7C/255.0, green: 0x3A/255.0, blue: 0xED/255.0)
        
        /// Send button hover: #6D28D9
        static let sendButtonHover = Color(red: 0x6D/255.0, green: 0x28/255.0, blue: 0xD9/255.0)
        
        // MARK: - Logo (same in both modes - Moomo brand colors)
        static let logoViolet = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0)
        static let logoRose = Color(red: 0xF4/255.0, green: 0x3F/255.0, blue: 0x5E/255.0)
        static let logoAmber = Color(red: 0xF5/255.0, green: 0x9E/255.0, blue: 0x0B/255.0)
        static let logoTeal = Color(red: 0x14/255.0, green: 0xB8/255.0, blue: 0xA6/255.0)
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
    
    // MARK: - Animation (Exact webapp durations)
    struct Animation {
        static let defaultDuration: Double = 0.3
        static let fastDuration: Double = 0.2
        static let slideUpDuration: Double = 0.2
    }
    
    // MARK: - Suggestions (native chat prompts sent directly to the AI)
    static let suggestions = [
        (icon: "lightbulb.fill", text: "Explain a complex topic simply"),
        (icon: "envelope.fill", text: "Help me write an email"),
        (icon: "sparkles", text: "Brainstorm some ideas"),
        (icon: "text.alignleft", text: "Summarize this text for me")
    ]
}
