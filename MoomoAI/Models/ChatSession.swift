//
//  ChatSession.swift
//  MoomoAI
//
//  Model for chat sessions
//

import Foundation

struct ChatSession: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool = false
    var isImportant: Bool = false
    var isArchived: Bool = false
    var isTemporary: Bool = false
    
    init(id: String = UUID().uuidString, title: String, messages: [ChatMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date(), isPinned: Bool = false, isImportant: Bool = false, isArchived: Bool = false, isTemporary: Bool = false) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isImportant = isImportant
        self.isArchived = isArchived
        self.isTemporary = isTemporary
    }
    
    var preview: String {
        guard let content = messages.last?.content else { return "New chat" }
        // Strip markdown before truncating — truncating first can cut a marker
        // in half and leave "**Quantum mechanics** is the bra" in the list.
        let plain = MarkdownFormatter.plainText(for: content)
        return plain.isEmpty ? "New chat" : String(plain.prefix(50))
    }
    
    var messageCount: Int {
        messages.count
    }
    
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
        
        // Auto-generate title from first user message if still "New chat".
        // Image-only messages have empty content — keep the default title then.
        if title == "New chat", message.role == .user, messages.count <= 2, !message.content.isEmpty {
            title = String(message.content.prefix(30))
        }
    }
    
    mutating func updateTitle(_ newTitle: String) {
        title = newTitle
        updatedAt = Date()
    }

    // Equatable/Hashable are synthesized over ALL fields. The previous custom ==
    // compared only messages.count, so in-place message changes (reactions,
    // typing → content) could read as "equal" and be skipped by SwiftUI diffing.
}

// Sample data for previews
extension ChatSession {
    static var sample: ChatSession {
        ChatSession(
            title: "Sample Chat",
            messages: [
                ChatMessage(role: .user, content: "Hello, how are you?"),
                ChatMessage(role: .assistant, content: "I'm doing great! How can I help you today?")
            ]
        )
    }
}
