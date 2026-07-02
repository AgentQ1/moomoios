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
    var imageData: Data? = nil   // JPEG thumbnail for attached images (user side)
    var imageURL: String? = nil  // Remote URL for AI-generated images (assistant side)

    // Asset continuity (all optional → Codable stays backward-compatible).
    var imagePath: String? = nil      // Storage path of a generated/edited image; lets us re-edit it later
    var prompt: String? = nil         // Originating prompt/caption kept with a generated image
    var model: String? = nil          // Model that produced this message (e.g. "Q1")
    var attachmentName: String? = nil // Filename for a document attachment shown in chat
    var attachmentMime: String? = nil // MIME type for a document attachment

    enum MessageRole: String, Codable {
        case user
        case assistant
    }

    init(id: String = UUID().uuidString, role: MessageRole, content: String, timestamp: Date = Date(), isTyping: Bool = false, reactions: [String] = [], imageData: Data? = nil, imageURL: String? = nil, imagePath: String? = nil, prompt: String? = nil, model: String? = nil, attachmentName: String? = nil, attachmentMime: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isTyping = isTyping
        self.reactions = reactions
        self.imageData = imageData
        self.imageURL = imageURL
        self.imagePath = imagePath
        self.prompt = prompt
        self.model = model
        self.attachmentName = attachmentName
        self.attachmentMime = attachmentMime
    }

    /// True when this assistant message is an AI-generated/edited image.
    var isGeneratedImage: Bool { imageURL != nil }
    
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
        lhs.imageData == rhs.imageData &&
        lhs.imageURL == rhs.imageURL
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
