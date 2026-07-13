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
    let onEditImage: ((ChatMessage) -> Void)?
    let onRegenerate: (() -> Void)?

    @State private var showCopyButton = false
    @State private var showCopyToast = false
    @State private var showFullScreenImage = false

    init(message: ChatMessage,
         onReact: ((String) -> Void)? = nil,
         onDelete: (() -> Void)? = nil,
         onEditImage: ((ChatMessage) -> Void)? = nil,
         onRegenerate: (() -> Void)? = nil) {
        self.message = message
        self.onReact = onReact
        self.onDelete = onDelete
        self.onEditImage = onEditImage
        self.onRegenerate = onRegenerate
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var timeString: String { Self.timeFormatter.string(from: message.timestamp) }
    private var isLiked: Bool { message.reactions.contains("👍") }
    private var isDisliked: Bool { message.reactions.contains("👎") }

    var body: some View {
        Group {
            if message.role == .user {
                userMessage
            } else {
                assistantMessage
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
                            withAnimation { showCopyToast = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let source = previewSource {
                ImagePreviewView(source: source, caption: previewCaption)
            }
        }
    }

    /// Decoded thumbnail for an attached image, served from the memory-cached
    /// two-tier store. Falls back to the on-disk copy (by message id) so
    /// thumbnails survive cloud hydration replacing the message (cloud copies
    /// carry no image bytes). Gated so plain text rows never touch the disk.
    private var attachedThumbnail: UIImage? {
        guard message.imageData != nil || (message.attachmentMime?.hasPrefix("image/") ?? false) else {
            return nil
        }
        return ImageCache.shared.messageThumbnail(id: message.id, data: message.imageData)
    }

    // MARK: - User message (right-aligned, royal-navy, with read receipt)
    private var userMessage: some View {
        let thumbnail = attachedThumbnail
        return HStack {
            Spacer(minLength: 48)
            VStack(alignment: .trailing, spacing: 6) {
                // Attached image thumbnail (tap to preview)
                if let uiImage = thumbnail {
                    Button(action: { showFullScreenImage = true }) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                // Attached document chip (images render as thumbnails above)
                if let name = message.attachmentName, thumbnail == nil {
                    documentChip(name: name)
                }

                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(K.Colors.navyText)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }

                // Timestamp + double-check read receipt.
                HStack(spacing: 6) {
                    Text(timeString)
                        .font(.system(size: 12))
                        .foregroundColor(K.Colors.slate)
                    ReadReceipt(color: K.Colors.slate)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Assistant message (left-aligned, with action bar)
    private var assistantMessage: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                if message.isTyping {
                    typingIndicator
                } else {
                    // AI-generated image card (tap to open full-screen preview)
                    if let urlString = message.imageURL, let url = URL(string: urlString) {
                        generatedImageCard(url: url)
                    }

                    if !message.content.isEmpty {
                        messageContent
                            .contextMenu {
                                Button(action: copyToClipboard) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                if onDelete != nil {
                                    Button(role: .destructive, action: { onDelete?() }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                        // Action bar (copy • like • dislike • regenerate).
                        MessageActionBar(
                            isLiked: isLiked,
                            isDisliked: isDisliked,
                            onCopy: copyToClipboard,
                            onLike: { onReact?("👍") },
                            onDislike: { onReact?("👎") },
                            onRegenerate: message.imageURL == nil ? onRegenerate : nil
                        )
                    }
                }
            }
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Preview source

    private var previewSource: ImageSource? {
        if let urlString = message.imageURL, let url = URL(string: urlString) { return .remote(url) }
        if let image = attachedThumbnail { return .local(image) }
        return nil
    }

    private var previewCaption: String? {
        if let prompt = message.prompt, !prompt.isEmpty { return prompt }
        return message.content.isEmpty ? nil : message.content
    }

    // MARK: - Generated Image Card
    private func generatedImageCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showFullScreenImage = true }) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(K.Colors.backgroundSecondary)
                            .frame(width: 240, height: 240)
                        ProgressView().tint(K.Colors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .padding(8)
            }
            .contextMenu {
                Button(action: { showFullScreenImage = true }) {
                    Label("Open", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                if message.imagePath != nil, onEditImage != nil {
                    Button(action: { onEditImage?(message) }) {
                        Label("Edit image", systemImage: "wand.and.stars")
                    }
                }
                if let prompt = message.prompt, !prompt.isEmpty {
                    Button(action: { copy(prompt) }) {
                        Label("Copy prompt", systemImage: "doc.on.doc")
                    }
                }
            }

            // Action row: the unique continuity feature is in-place editing.
            if message.imagePath != nil, onEditImage != nil {
                Button(action: { onEditImage?(message) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Edit image")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(K.Colors.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(K.Colors.accentColor.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            // Caption: keep the prompt visible with the image.
            if let prompt = message.prompt, !prompt.isEmpty, message.content.isEmpty {
                Text(prompt)
                    .font(.system(size: 13))
                    .foregroundColor(K.Colors.textSecondary)
                    .frame(maxWidth: 320, alignment: .leading)
            }
        }
        .padding(.bottom, message.content.isEmpty ? 0 : 8)
    }

    // MARK: - Document chip
    private func documentChip(name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 16))
                .foregroundColor(K.Colors.accentColor)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(K.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(K.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(K.Colors.borderColor.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Message Content
    /// Assistant markdown rendered block-by-block (MarkdownText owns all
    /// typography: Dynamic Type, compact spacing, list gutters, code cards).
    private var messageContent: some View {
        MarkdownText(text: message.content)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .onAppear { showCopyButton = true }
    }

    // MARK: - Actions
    private func copyToClipboard() { copy(message.content) }

    private func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
        withAnimation { showCopyToast = true }
    }
}

#Preview {
    VStack(spacing: 24) {
        MessageBubbleView(message: ChatMessage(role: .user, content: "Hello, how are you?"))
        MessageBubbleView(message: ChatMessage(
            role: .assistant,
            content: "**Individual item actions:**\n\n1. Open the item\n2. Tap `Remove App`\n- One bullet\n  - Nested bullet"
        ))
        MessageBubbleView(message: ChatMessage(role: .assistant, content: "", isTyping: true))
    }
    .padding()
    .background(K.Colors.backgroundPrimary)
    .preferredColorScheme(.light)
}
