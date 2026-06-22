//
//  EmptyStateView.swift
//  MoomoAI
//
//  Reusable empty state component for various contexts
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                K.Colors.accentColor.opacity(0.1),
                                K.Colors.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(K.Colors.accentColor)
            }
            .scaleEffect(1.0)
            .animation(
                Animation.spring(response: 0.6, dampingFraction: 0.5)
                    .repeatForever(autoreverses: true),
                value: UUID()
            )
            
            VStack(spacing: 12) {
                // Title
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(K.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Description
                Text(description)
                    .font(.body)
                    .foregroundColor(K.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Optional Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticFeedback.light()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(K.Colors.accentColor)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    static func noMessages(onStartConversation: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "message.fill",
            title: "No Messages Yet",
            description: "Start a conversation with Moomo AI and get intelligent responses to your questions.",
            actionTitle: "Start Chatting",
            action: onStartConversation
        )
    }
    
    static var noSearchResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results Found",
            description: "We couldn't find any messages matching your search. Try different keywords or check your spelling."
        )
    }
}

// MARK: - Preview
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyStateView.noMessages(onStartConversation: {})
                .background(K.Colors.backgroundPrimary)
            
            EmptyStateView.noSearchResults
                .background(K.Colors.backgroundPrimary)
        }
        .preferredColorScheme(.dark)
    }
}
