//
//  ChatMessage.swift
//  MoomoAI
//
//  Model for chat messages
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    var isTyping: Bool = false
    var reactions: [String] = [] // Array of emoji reactions
    var imageData: Data? = nil   // JPEG thumbnail for attached images
    
    enum MessageRole: String, Codable {
        case user
        case assistant
    }
    
    init(id: String = UUID().uuidString, role: MessageRole, content: String, timestamp: Date = Date(), isTyping: Bool = false, reactions: [String] = [], imageData: Data? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isTyping = isTyping
        self.reactions = reactions
        self.imageData = imageData
    }
    
    mutating func addReaction(_ emoji: String) {
        if !reactions.contains(emoji) {
            reactions.append(emoji)
        }
    }
    
    mutating func removeReaction(_ emoji: String) {
        reactions.removeAll { $0 == emoji }
    }
    
    // PERFORMANCE: Proper Equatable implementation for SwiftUI optimization
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isTyping == rhs.isTyping &&
        lhs.reactions == rhs.reactions &&
        lhs.imageData == rhs.imageData
    }
    
    // PERFORMANCE: Hashable for efficient ForEach rendering
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Extension for conversation history format
extension ChatMessage {
    var conversationFormat: [String: Any] {
        return [
            "role": role == .user ? "user" : "model",
            "parts": [["text": content]]
        ]
    }
}
