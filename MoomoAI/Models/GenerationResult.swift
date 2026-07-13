//
//  GenerationResult.swift
//  MoomoAI
//
//  One shared result model for every generation/edit call (text or image).
//

import Foundation

struct GenerationResult: Identifiable, Equatable {
    enum Kind: String { case text, image, image_edit, text_edit }

    let id: String
    let kind: Kind
    let text: String?     // populated for text / text_edit
    let url: String?      // image download URL for image / image_edit
    let path: String?     // Storage path, used as the source for image edits
    let createdAt: String

    /// Parse the clean JSON returned by the callable Cloud Functions.
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let typeString = data["type"] as? String,
              let kind = Kind(rawValue: typeString) else { return nil }
        self.id = id
        self.kind = kind
        self.text = data["text"] as? String
        self.url = data["url"] as? String
        self.path = data["path"] as? String
        self.createdAt = data["createdAt"] as? String ?? ""
    }
}
