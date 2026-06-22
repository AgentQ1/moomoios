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
        messages.last?.content.prefix(50).description ?? "New chat"
    }
    
    var messageCount: Int {
        messages.count
    }
    
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
        
        // Auto-generate title from first user message if still "New chat"
        if title == "New chat", message.role == .user, messages.count <= 2 {
            title = String(message.content.prefix(30))
        }
    }
    
    mutating func updateTitle(_ newTitle: String) {
        title = newTitle
        updatedAt = Date()
    }
    
    // PERFORMANCE: Proper Equatable for SwiftUI optimization
    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.messages.count == rhs.messages.count &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.isPinned == rhs.isPinned
    }
    
    // PERFORMANCE: Hashable for efficient ForEach rendering
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
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
