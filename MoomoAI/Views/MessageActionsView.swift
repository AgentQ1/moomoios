//
//  MessageActionsView.swift
//  MoomoAI
//
//  Message actions: copy, share, reactions, delete
//

import SwiftUI

struct MessageActionsView: View {
    let message: ChatMessage
    let onCopy: () -> Void
    let onShare: () -> Void
    let onReact: (String) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    private let quickReactions = ["👍", "👎", "❤️", "😂", "🎉", "🤔"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Message Actions")
                    .font(.headline)
                    .foregroundColor(K.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(K.Colors.textSecondary)
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Reactions
                    reactionSection
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
        }
        .background(K.Colors.backgroundPrimary)
        .cornerRadius(20)
        .shadow(radius: 20)
    }
    
    // MARK: - Reaction Section
    
    private var reactionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("React")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(K.Colors.textSecondary)
            
            HStack(spacing: 16) {
                ForEach(quickReactions, id: \.self) { emoji in
                    Button(action: {
                        onReact(emoji)
                        // Add haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismiss()
                    }) {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 50, height: 50)
                            .background(
                                message.reactions.contains(emoji) ?
                                K.Colors.accentColor.opacity(0.2) :
                                K.Colors.backgroundSecondary
                            )
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        message.reactions.contains(emoji) ?
                                        K.Colors.accentColor :
                                        Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            ActionButton(
                icon: "doc.on.doc",
                title: "Copy Message",
                action: {
                    onCopy()
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    dismiss()
                }
            )
            
            ActionButton(
                icon: "square.and.arrow.up",
                title: "Share Message",
                action: {
                    onShare()
                    dismiss()
                }
            )
            
            if message.role == .user {
                ActionButton(
                    icon: "trash",
                    title: "Delete Message",
                    isDestructive: true,
                    action: {
                        onDelete()
                        let impact = UINotificationFeedbackGenerator()
                        impact.notificationOccurred(.warning)
                        dismiss()
                    }
                )
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(K.Colors.textSecondary)
            }
            .foregroundColor(isDestructive ? .red : K.Colors.textPrimary)
            .padding()
            .background(K.Colors.backgroundSecondary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Copy Confirmation Toast

struct CopyConfirmationToast: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("Copied to clipboard")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(K.Colors.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(K.Colors.backgroundSecondary)
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet for Messages

struct MessageShareSheet: UIViewControllerRepresentable {
    let message: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct MessageActionsView_Previews: PreviewProvider {
    static var previews: some View {
        MessageActionsView(
            message: ChatMessage(role: .assistant, content: "This is a sample message"),
            onCopy: {},
            onShare: {},
            onReact: { _ in },
            onDelete: {}
        )
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
