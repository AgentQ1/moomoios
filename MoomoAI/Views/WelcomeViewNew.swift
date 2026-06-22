//
//  WelcomeViewNew.swift
//  MoomoAI
//
//  Welcome screen - EXACT match to webapp futuristic design
//

import SwiftUI

struct WelcomeViewNew: View {
    let onSuggestionTap: (String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Layout.sectionSpacing) {
                Spacer(minLength: 60)
                
                // Logo (Smaller, exact webapp size: 80x80px)
                MoomoLogoView()
                
                // Title and subtitle
                VStack(spacing: 8) {
                    Text("What would you like to explore?")
                        .font(.system(
                            size: DesignSystem.Typography.welcomeTitleSize,
                            weight: DesignSystem.Typography.welcomeTitleWeight
                        ))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Ask me anything or try one of these suggestions")
                        .font(.system(size: DesignSystem.Typography.welcomeSubtitleSize))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, DesignSystem.Layout.sectionSpacing)
                
                // Suggestions (Exact webapp styling)
                VStack(spacing: DesignSystem.Layout.itemSpacing) {
                    ForEach(DesignSystem.suggestions, id: \.text) { suggestion in
                        SuggestionCardView(
                            icon: suggestion.icon,
                            text: suggestion.text,
                            onTap: {
                                onSuggestionTap(suggestion.text)
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Layout.sectionSpacing)
                .padding(.top, DesignSystem.Layout.mediumPadding)
                
                Spacer()
            }
        }
        .background(DesignSystem.Colors.backgroundPrimary)
    }
}

// MARK: - Moomo Logo (Moomo brand: 80x80px with 60x12px bars)
struct MoomoLogoView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Layout.logoBarSpacing) {
            // Violet bar #8B5CF6
            RoundedRectangle(cornerRadius: DesignSystem.Layout.logoBarCornerRadius)
                .fill(DesignSystem.Colors.logoViolet)
                .frame(
                    width: DesignSystem.Layout.logoBarWidth,
                    height: DesignSystem.Layout.logoBarHeight
                )
            
            // Rose bar #F43F5E
            RoundedRectangle(cornerRadius: DesignSystem.Layout.logoBarCornerRadius)
                .fill(DesignSystem.Colors.logoRose)
                .frame(
                    width: DesignSystem.Layout.logoBarWidth,
                    height: DesignSystem.Layout.logoBarHeight
                )
            
            // Amber bar #F59E0B
            RoundedRectangle(cornerRadius: DesignSystem.Layout.logoBarCornerRadius)
                .fill(DesignSystem.Colors.logoAmber)
                .frame(
                    width: DesignSystem.Layout.logoBarWidth,
                    height: DesignSystem.Layout.logoBarHeight
                )
            
            // Teal bar #14B8A6
            RoundedRectangle(cornerRadius: DesignSystem.Layout.logoBarCornerRadius)
                .fill(DesignSystem.Colors.logoTeal)
                .frame(
                    width: DesignSystem.Layout.logoBarWidth,
                    height: DesignSystem.Layout.logoBarHeight
                )
        }
        .padding(DesignSystem.Layout.logoPadding)
        .frame(
            width: DesignSystem.Layout.logoSize,
            height: DesignSystem.Layout.logoSize
        )
        .background(Color.clear)
    }
}

// MARK: - Suggestion Card (Native iOS with SF Symbols)
struct SuggestionCardView: View {
    let icon: String
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Layout.mediumPadding) {
                // SF Symbol icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: 28, height: 28)
                
                // Text (webapp: font-size: 14px)
                Text(text)
                    .font(.system(size: DesignSystem.Typography.suggestionTextSize))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DesignSystem.Layout.mediumPadding)
            .padding(.vertical, DesignSystem.Layout.mediumPadding)
            .frame(maxWidth: .infinity)
            .suggestionCardStyle()
        }
        .buttonStyle(FuturisticButtonStyle())
    }
}

// MARK: - Futuristic Button Style with Smooth Animations
struct FuturisticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: DesignSystem.Animation.fastDuration), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct WelcomeViewNew_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeViewNew { _ in }
            .preferredColorScheme(.dark)
    }
}
