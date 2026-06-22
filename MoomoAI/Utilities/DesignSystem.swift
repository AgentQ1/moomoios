//
//  DesignSystem.swift
//  MoomoAI
//
//  Futuristic design system matching webapp - Grok-inspired aesthetic
//

import SwiftUI

// MARK: - Design System
enum DesignSystem {
    
    // MARK: - Colors (Exact webapp CSS variables - using RGB values)
    enum Colors {
        // Primary backgrounds
        static let backgroundPrimary = Color(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0)
        static let backgroundSecondary = Color(red: 0x1e/255.0, green: 0x1e/255.0, blue: 0x1e/255.0)
        static let backgroundTertiary = Color(red: 0x24/255.0, green: 0x24/255.0, blue: 0x24/255.0)
        static let backgroundHover = Color(red: 0x2a/255.0, green: 0x2a/255.0, blue: 0x2a/255.0)
        static let backgroundActive = Color(red: 0x32/255.0, green: 0x32/255.0, blue: 0x32/255.0)
        
        // Borders
        static let borderColor = Color(red: 0x3a/255.0, green: 0x3a/255.0, blue: 0x3a/255.0)
        
        // Text colors
        static let textPrimary = Color(red: 0xe3/255.0, green: 0xe3/255.0, blue: 0xe3/255.0)
        static let textSecondary = Color(red: 0xb8/255.0, green: 0xb8/255.0, blue: 0xb8/255.0)
        
        // Accent colors
        static let accentColor = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0)
        static let accentHover = Color(red: 0xA7/255.0, green: 0x8B/255.0, blue: 0xFA/255.0)
        
        // Message backgrounds
        static let messageBg = Color(red: 0x2a/255.0, green: 0x2a/255.0, blue: 0x2a/255.0)
        static let inputBg = Color(red: 0x24/255.0, green: 0x24/255.0, blue: 0x24/255.0)
        
        // Send button
        static let sendButton = Color(red: 0x7C/255.0, green: 0x3A/255.0, blue: 0xED/255.0)
        static let sendButtonHover = Color(red: 0x6D/255.0, green: 0x28/255.0, blue: 0xD9/255.0)
        
        // Logo colors (Moomo brand)
        static let logoViolet = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0)
        static let logoRose = Color(red: 0xF4/255.0, green: 0x3F/255.0, blue: 0x5E/255.0)
        static let logoAmber = Color(red: 0xF5/255.0, green: 0x9E/255.0, blue: 0x0B/255.0)
        static let logoTeal = Color(red: 0x14/255.0, green: 0xB8/255.0, blue: 0xA6/255.0)
    }
    
    // MARK: - Typography (Exact webapp font sizes & weights)
    enum Typography {
        // Welcome screen
        static let welcomeTitleSize: CGFloat = 32
        static let welcomeTitleWeight: Font.Weight = .semibold
        static let welcomeSubtitleSize: CGFloat = 16
        
        // Message text
        static let messageTextSize: CGFloat = 15
        static let messageLineSpacing: CGFloat = 9.6  // 15 * 1.6 - 15
        
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
    enum Layout {
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
        
        // Input area
        static let inputHeight: CGFloat = 32
        static let sendButtonSize: CGFloat = 32
    }
    
    // MARK: - Animation (Exact webapp durations)
    enum Animation {
        static let defaultDuration: Double = 0.3
        static let fastDuration: Double = 0.2
        static let slideUpDuration: Double = 0.2
    }
    
    // MARK: - Suggestions
    static let suggestions: [(emoji: String, text: String)] = [
        (emoji: "📊", text: "Create presentation"),
        (emoji: "📰", text: "Read news"),
        (emoji: "📄", text: "Create document"),
        (emoji: "🎤", text: "Voice chat")
    ]
}

// MARK: - View Modifiers for Consistent Styling
extension View {
    /// Apply webapp-style suggestion card styling
    func suggestionCardStyle() -> some View {
        self
            .background(DesignSystem.Colors.backgroundTertiary)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(DesignSystem.Colors.borderColor, lineWidth: 1)
            )
    }
    
    /// Apply webapp-style input container styling
    func inputContainerStyle(isFocused: Bool = false) -> some View {
        self
            .background(DesignSystem.Colors.inputBg)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(
                        isFocused ? DesignSystem.Colors.accentColor : DesignSystem.Colors.borderColor,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isFocused ? DesignSystem.Colors.accentColor.opacity(0.1) : .clear,
                radius: 4,
                x: 0,
                y: 0
            )
    }
    
    /// Apply webapp-style message text styling
    func messageTextStyle() -> some View {
        self
            .font(.system(size: DesignSystem.Typography.messageTextSize))
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .lineSpacing(DesignSystem.Typography.messageLineSpacing)
    }
}
