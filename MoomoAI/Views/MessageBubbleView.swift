//
//  MessageBubbleView.swift
//  MoomoAI
//
//  Individual message bubble - EXACTLY matches web app message styling (no avatars)
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    let onReact: ((String) -> Void)?
    let onDelete: (() -> Void)?
    let onRegenerate: (() -> Void)?
    
    @State private var showCopyButton = false
    @State private var showActions = false
    @State private var showShareSheet = false
    @State private var showCopyToast = false
    @State private var showFullScreenImage = false
    
    init(message: ChatMessage, onReact: ((String) -> Void)? = nil, onDelete: (() -> Void)? = nil, onRegenerate: (() -> Void)? = nil) {
        self.message = message
        self.onReact = onReact
        self.onDelete = onDelete
        self.onRegenerate = onRegenerate
    }
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            // NO AVATAR - matches webapp exactly
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    // User message title (only for user messages, matching webapp)
                    if message.role == .user {
                        // Show attached image thumbnail
                        if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                            Button(action: { showFullScreenImage = true }) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 6)
                        }
                        
                        Text(message.content)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(K.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 8)
                            .textSelection(.enabled)
                    } else {
                        // Message content (assistant)
                        if message.isTyping {
                            typingIndicator
                        } else {
                            messageContent
                                .contextMenu {
                                    Button(action: copyToClipboard) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    if message.role == .assistant && onRegenerate != nil {
                                        Button(action: { onRegenerate?() }) {
                                            Label("Regenerate", systemImage: "arrow.clockwise")
                                        }
                                    }
                                    if onDelete != nil {
                                        Button(role: .destructive, action: { onDelete?() }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: 900) // Match webapp max width
            
            // Regenerate button for AI messages
            if message.role == .assistant && !message.isTyping && onRegenerate != nil {
                HStack(spacing: 8) {
                    Button(action: copyToClipboard) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16))
                            .foregroundColor(K.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(K.Colors.backgroundSecondary)
                            .cornerRadius(6)
                    }
                    
                    Button(action: { onRegenerate?() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(K.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(K.Colors.backgroundSecondary)
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
                .frame(maxWidth: 900)
            }
        }
        .overlay(alignment: .top) {
            if showCopyToast {
                Text("Copied")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .padding(.top, -50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopyToast = false
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: { showFullScreenImage = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(20)
                    }
                }
            }
        }
    }
    
    // MARK: - Message Content (EXACT webapp styling)
    private var messageContent: some View {
        // WebApp CSS:
        // font-size: 15px
        // line-height: 1.6
        // color: var(--text-primary)
        // word-wrap: break-word
        Text(MarkdownFormatter.format(message.content))
            .font(.system(size: 15, weight: .regular))
            .lineSpacing(9) // 15px * 1.6 = 24px total, so spacing = 24 - 15 = 9px
            .foregroundColor(K.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
    
    // MARK: - Typing Indicator
    private var typingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(K.Colors.textSecondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(showCopyButton ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: showCopyButton
                    )
            }
        }
        .padding(12)
        .onAppear {
            showCopyButton = true
        }
    }
    
    // MARK: - Actions
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = message.content
        #endif
        withAnimation {
            showCopyToast = true
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        MessageBubbleView(message: ChatMessage(
            role: .user,
            content: "Hello, how are you?"
        ))
        
        MessageBubbleView(message: ChatMessage(
            role: .assistant,
            content: "I'm doing great! How can I help you today?"
        ), onRegenerate: {})
        
        MessageBubbleView(message: ChatMessage(
            role: .assistant,
            content: "",
            isTyping: true
        ))
    }
    .padding()
    .background(K.Colors.backgroundPrimary)
    .preferredColorScheme(.dark)
}
