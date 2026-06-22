//
//  WelcomeView.swift
//  MoomoAI
//
//  Welcome screen - Moomo futuristic design
//

import SwiftUI

struct WelcomeView: View {
    let onSuggestionTap: (String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: K.Layout.sectionSpacing) {
                Spacer(minLength: 60)
                
                // Logo (Smaller, exact webapp size)
                logoView
                
                // Title and subtitle
                VStack(spacing: 8) {
                    Text("What would you like to explore?")
                        .font(.system(size: K.Typography.welcomeTitleSize, weight: K.Typography.welcomeTitleWeight))
                        .foregroundColor(K.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Ask me anything or try one of these suggestions")
                        .font(.system(size: K.Typography.welcomeSubtitleSize))
                        .foregroundColor(K.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, K.Layout.sectionSpacing)
                
                // Suggestions (Exact webapp styling)
                VStack(spacing: K.Layout.itemSpacing) {
                    ForEach(K.suggestions, id: \.text) { suggestion in
                        SuggestionCard(
                            icon: suggestion.icon,
                            text: suggestion.text,
                            onTap: {
                                onSuggestionTap(suggestion.text)
                            }
                        )
                    }
                }
                .padding(.horizontal, K.Layout.sectionSpacing)
                .padding(.top, K.Layout.mediumPadding)
                
                Spacer()
            }
        }
        .background(K.Colors.backgroundPrimary)
    }
    
    // MARK: - Logo View (Moomo brand: 80x80px with 60x12px bars)
    private var logoView: some View {
        VStack(spacing: K.Layout.logoBarSpacing) {
            // Violet bar #8B5CF6
            RoundedRectangle(cornerRadius: K.Layout.logoBarCornerRadius)
                .fill(K.Colors.logoViolet)
                .frame(width: K.Layout.logoBarWidth, height: K.Layout.logoBarHeight)
            
            // Rose bar #F43F5E
            RoundedRectangle(cornerRadius: K.Layout.logoBarCornerRadius)
                .fill(K.Colors.logoRose)
                .frame(width: K.Layout.logoBarWidth, height: K.Layout.logoBarHeight)
            
            // Amber bar #F59E0B
            RoundedRectangle(cornerRadius: K.Layout.logoBarCornerRadius)
                .fill(K.Colors.logoAmber)
                .frame(width: K.Layout.logoBarWidth, height: K.Layout.logoBarHeight)
            
            // Teal bar #14B8A6
            RoundedRectangle(cornerRadius: K.Layout.logoBarCornerRadius)
                .fill(K.Colors.logoTeal)
                .frame(width: K.Layout.logoBarWidth, height: K.Layout.logoBarHeight)
        }
        .padding(K.Layout.logoPadding)
        .frame(width: K.Layout.logoSize, height: K.Layout.logoSize)
        .background(Color.clear)
    }
}

// MARK: - Suggestion Card (Native iOS with SF Symbols)
struct SuggestionCard: View {
    let icon: String
    let text: String
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: K.Layout.mediumPadding) {
                // SF Symbol icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(K.Colors.textPrimary)
                    .frame(width: 28, height: 28)
                
                // Text (webapp: font-size: 14px)
                Text(text)
                    .font(.system(size: K.Typography.suggestionTextSize))
                    .foregroundColor(K.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, K.Layout.mediumPadding)
            .padding(.vertical, K.Layout.mediumPadding)
            .frame(maxWidth: .infinity)
            // Webapp: background: var(--bg-tertiary), border: 1px solid var(--border-color), border-radius: 12px
            .background(K.Colors.backgroundTertiary)
            .cornerRadius(K.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: K.Layout.cornerRadius)
                    .stroke(K.Colors.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(SuggestionButtonStyle())
    }
}

// MARK: - Button Style with Hover Effect
struct SuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView { _ in }
            .background(K.Colors.backgroundPrimary)
            .preferredColorScheme(.dark)
    }
}
