//
//  LibraryAsset.swift
//  MoomoAI
//
//  A non-text asset (generated image, edited image, uploaded file, future video)
//  produced inside a conversation. Persisted to Firestore at
//  users/{uid}/assets/{assetId} so the Library can list everything a user has
//  created or uploaded, linked back to the chat/message that produced it.
//

import Foundation

/// The kind of asset shown in the Library. Plain text messages are never assets.
enum AssetType: String, Codable, CaseIterable, Identifiable {
    case generatedImage
    case editedImage
    case uploadedFile
    case video   // reserved for future support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generatedImage: return "Image"
        case .editedImage: return "Edited"
        case .uploadedFile: return "File"
        case .video: return "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .generatedImage: return "photo"
        case .editedImage: return "wand.and.stars"
        case .uploadedFile: return "doc"
        case .video: return "video"
        }
    }

    /// True for asset kinds that render as an image (have a download URL).
    var isImage: Bool { self == .generatedImage || self == .editedImage }
}

/// One asset record. Equatable/Hashable by id for efficient SwiftUI diffing.
struct LibraryAsset: Identifiable, Equatable, Hashable {
    let id: String
    let type: AssetType
    let url: String?        // download URL for images
    let path: String?       // Storage path (used as the source for re-edits)
    let prompt: String      // originating prompt / caption / question
    let chatId: String
    let chatTitle: String
    let messageId: String
    let model: String?
    let mimeType: String?   // populated for uploaded files
    let name: String?       // original filename for uploaded files
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        type: AssetType,
        url: String? = nil,
        path: String? = nil,
        prompt: String,
        chatId: String,
        chatTitle: String = "",
        messageId: String,
        model: String? = nil,
        mimeType: String? = nil,
        name: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.path = path
        self.prompt = prompt
        self.chatId = chatId
        self.chatTitle = chatTitle
        self.messageId = messageId
        self.model = model
        self.mimeType = mimeType
        self.name = name
        self.createdAt = createdAt
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LibraryAsset, rhs: LibraryAsset) -> Bool { lhs.id == rhs.id }
}
