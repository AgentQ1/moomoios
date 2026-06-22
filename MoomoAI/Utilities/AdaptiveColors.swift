//
//  AdaptiveColors.swift
//  MoomoAI
//
//  Adaptive color system matching webapp dark/light modes
//

import SwiftUI

// MARK: - Adaptive Color Helper
struct AdaptiveColor {
    let light: Color
    let dark: Color
    
    var color: Color {
        // SwiftUI automatically adapts based on system appearance
        // We use Color(light:dark:) to create adaptive colors
        Color(light: light, dark: dark)
    }
}

// MARK: - Color Extension for Adaptive Colors
extension Color {
    /// Creates an adaptive color that responds to light/dark mode
    /// Matches webapp's @media (prefers-color-scheme: light)
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
        // Fallback for non-UIKit platforms
        self = dark
        #endif
    }
}

// MARK: - Themed Colors (Webapp Match)
struct ThemedColors {
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

// MARK: - Preview Helper
struct AdaptiveColors_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Adaptive Colors Demo")
                .font(.title)
                .foregroundColor(ThemedColors.textPrimary)
            
            Rectangle()
                .fill(ThemedColors.backgroundTertiary)
                .frame(height: 100)
                .overlay(
                    Text("Background Tertiary")
                        .foregroundColor(ThemedColors.textPrimary)
                )
            
            Rectangle()
                .fill(ThemedColors.accentColor)
                .frame(height: 60)
                .overlay(
                    Text("Accent Color")
                        .foregroundColor(.white)
                )
        }
        .padding()
        .background(ThemedColors.backgroundPrimary)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
        
        VStack(spacing: 20) {
            Text("Adaptive Colors Demo")
                .font(.title)
                .foregroundColor(ThemedColors.textPrimary)
            
            Rectangle()
                .fill(ThemedColors.backgroundTertiary)
                .frame(height: 100)
                .overlay(
                    Text("Background Tertiary")
                        .foregroundColor(ThemedColors.textPrimary)
                )
            
            Rectangle()
                .fill(ThemedColors.accentColor)
                .frame(height: 60)
                .overlay(
                    Text("Accent Color")
                        .foregroundColor(.white)
                )
        }
        .padding()
        .background(ThemedColors.backgroundPrimary)
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")
    }
}
