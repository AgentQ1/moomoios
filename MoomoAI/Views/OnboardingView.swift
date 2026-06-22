//
//  OnboardingView.swift
//  MoomoAI
//
//  First-time user onboarding with feature highlights
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Welcome to Moomo AI",
            description: "Your intelligent AI assistant powered by Claude. Get accurate, comprehensive responses to any question.",
            accentColor: .blue
        ),
        OnboardingPage(
            icon: "message.badge.filled.fill",
            title: "Smart Conversations",
            description: "Chat naturally with AI, search through your conversations, and regenerate responses with different creativity levels.",
            accentColor: .purple
        ),
        OnboardingPage(
            icon: "cloud.fill",
            title: "Cloud Sync",
            description: "Your conversations sync across all your devices via Firebase. Never lose your chat history.",
            accentColor: .cyan
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            K.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip Button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(AnimationConstants.springStandard) {
                            isPresented = false
                        }
                        HapticFeedback.light()
                    }) {
                        Text("Skip")
                            .font(.headline)
                            .foregroundColor(K.Colors.textSecondary)
                            .padding()
                    }
                }
                
                // Page Indicator
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(AnimationConstants.springStandard, value: currentPage)
                
                // Navigation Buttons
                HStack(spacing: 20) {
                    // Back Button
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation(AnimationConstants.springStandard) {
                                currentPage -= 1
                            }
                            HapticFeedback.selection()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.headline)
                            .foregroundColor(K.Colors.textSecondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(K.Colors.backgroundSecondary)
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                    
                    // Next/Get Started Button
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation(AnimationConstants.springStandard) {
                                currentPage += 1
                            }
                            HapticFeedback.selection()
                        } else {
                            withAnimation(AnimationConstants.springStandard) {
                                isPresented = false
                            }
                            HapticFeedback.success()
                        }
                    }) {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                            } else {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [K.Colors.accentColor, K.Colors.accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: K.Colors.accentColor.opacity(0.3), radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon with animated gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                page.accentColor.opacity(0.2),
                                page.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Image(systemName: page.icon)
                    .font(.system(size: 70))
                    .foregroundColor(page.accentColor)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .animation(
                        Animation.spring(response: 0.6, dampingFraction: 0.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .onAppear {
                isAnimating = true
            }
            
            VStack(spacing: 16) {
                // Title
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(K.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Description
                Text(page.description)
                    .font(.body)
                    .foregroundColor(K.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
            .preferredColorScheme(.dark)
    }
}
