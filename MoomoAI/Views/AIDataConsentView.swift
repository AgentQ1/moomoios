//
//  AIDataConsentView.swift
//  MoomoAI
//
//  Privacy consent dialog for third-party AI data sharing (Apple Guideline 5.1.1(i) & 5.1.2(i))
//

import SwiftUI

struct AIDataConsentView: View {
    @Binding var isPresented: Bool
    var onAccept: () -> Void
    var onDecline: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40))
                        .foregroundColor(K.Colors.accentColor)
                    
                    Text("AI Data Sharing")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(K.Colors.textPrimary)
                    
                    Text("Your privacy matters to us")
                        .font(.system(size: 14))
                        .foregroundColor(K.Colors.textSecondary)
                }
                .padding(.top, 28)
                .padding(.bottom, 20)
                
                Divider()
                    .background(K.Colors.borderColor)
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // What data is shared
                        consentSection(
                            icon: "doc.text.fill",
                            title: "What data is shared",
                            items: [
                                "Your chat messages and conversation history",
                                "Text from any files or images you attach",
                                "Your selected language preference"
                            ]
                        )
                        
                        // Who receives the data
                        consentSection(
                            icon: "building.2.fill",
                            title: "Who receives your data",
                            items: [
                                "Google (Gemini AI) — processes AI responses for the Q1 model",
                                "Firebase (Google) — stores your account and chat data"
                            ]
                        )
                        
                        // How data is used
                        consentSection(
                            icon: "gearshape.fill",
                            title: "How your data is used",
                            items: [
                                "To generate AI-powered responses to your questions",
                                "To maintain conversation context within a chat session",
                                "Data is transmitted securely via encrypted HTTPS connections",
                                "AI providers may process data per their own privacy policies"
                            ]
                        )
                        
                        // Privacy policy link
                        VStack(alignment: .leading, spacing: 8) {
                            Text("For complete details, please review our:")
                                .font(.system(size: 13))
                                .foregroundColor(K.Colors.textSecondary)
                            
                            Link("Privacy Policy", destination: URL(string: "https://moomopro-72876.web.app/privacy-policy.html")!)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(K.Colors.accentColor)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .frame(maxHeight: 340)
                
                Divider()
                    .background(K.Colors.borderColor)
                
                // Action Buttons
                VStack(spacing: 10) {
                    Button(action: {
                        HapticFeedback.success()
                        onAccept()
                        isPresented = false
                    }) {
                        Text("I Agree — Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(K.Colors.accentColor)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        HapticFeedback.light()
                        onDecline()
                        isPresented = false
                    }) {
                        Text("Decline")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(K.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(K.Colors.backgroundSecondary)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.horizontal, 28)
        }
    }
    
    // MARK: - Section Builder
    
    private func consentSection(icon: String, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(K.Colors.accentColor)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(K.Colors.textPrimary)
            }
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.system(size: 13))
                        .foregroundColor(K.Colors.textSecondary)
                    
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundColor(K.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
            }
        }
    }
}

struct AIDataConsentView_Previews: PreviewProvider {
    static var previews: some View {
        AIDataConsentView(
            isPresented: .constant(true),
            onAccept: {},
            onDecline: {}
        )
        .preferredColorScheme(.dark)
    }
}
