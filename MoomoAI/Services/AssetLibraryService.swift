//
//  AssetLibraryService.swift
//  MoomoAI
//
//  Persists and loads Library assets (generated images, edited images, uploaded
//  files) at Firestore path users/{uid}/assets/{assetId}. Every asset is linked
//  back to the chat + message + prompt that produced it, so the Library and the
//  chat stay in sync and assets survive logout/login. Writes are best-effort and
//  no-op when signed out; reads are paginated for scalability.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AssetLibraryService {
    static let shared = AssetLibraryService()
    private lazy var db = Firestore.firestore()
    private init() {}

    private var uid: String? { Auth.auth().currentUser?.uid }

    /// One page of assets plus the cursor needed to fetch the next page.
    struct Page {
        let assets: [LibraryAsset]
        let cursor: DocumentSnapshot?
        let reachedEnd: Bool
    }

    // MARK: - Write

    /// Persist an asset record (fire-and-forget). Skipped when signed out.
    func saveAsset(_ asset: LibraryAsset) {
        guard let uid else { return }
        var data: [String: Any] = [
            "type": asset.type.rawValue,
            "prompt": asset.prompt,
            "chatId": asset.chatId,
            "chatTitle": asset.chatTitle,
            "messageId": asset.messageId,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let url = asset.url { data["url"] = url }
        if let path = asset.path { data["path"] = path }
        if let model = asset.model { data["model"] = model }
        if let mimeType = asset.mimeType { data["mimeType"] = mimeType }
        if let name = asset.name { data["name"] = name }

        db.collection("users").document(uid)
            .collection("assets").document(asset.id)
            .setData(data) { error in
                #if DEBUG
                if let error { print("ASSET save error=\(error.localizedDescription)") }
                #endif
            }
    }

    // MARK: - Read

    /// Load a page of assets, newest first. Pass the previous page's `cursor` to paginate.
    func loadAssets(pageSize: Int = 30, after cursor: DocumentSnapshot? = nil) async -> Page {
        guard let uid else { return Page(assets: [], cursor: nil, reachedEnd: true) }
        do {
            var query: Query = db.collection("users").document(uid)
                .collection("assets")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
            if let cursor { query = query.start(afterDocument: cursor) }

            let snapshot = try await query.getDocuments()
            let assets = snapshot.documents.compactMap(Self.asset(from:))
            return Page(
                assets: assets,
                cursor: snapshot.documents.last,
                reachedEnd: snapshot.documents.count < pageSize
            )
        } catch {
            #if DEBUG
            print("ASSET loadAssets error=\(error.localizedDescription)")
            #endif
            return Page(assets: [], cursor: cursor, reachedEnd: true)
        }
    }

    /// Delete an asset record (Library → remove). Does not delete the underlying
    /// Storage object (those are Cloud-Function managed); only the index entry.
    func deleteAsset(id: String) {
        guard let uid else { return }
        db.collection("users").document(uid).collection("assets").document(id).delete()
    }

    private static func asset(from doc: QueryDocumentSnapshot) -> LibraryAsset? {
        let d = doc.data()
        guard let typeString = d["type"] as? String,
              let type = AssetType(rawValue: typeString) else { return nil }
        return LibraryAsset(
            id: doc.documentID,
            type: type,
            url: d["url"] as? String,
            path: d["path"] as? String,
            prompt: d["prompt"] as? String ?? "",
            chatId: d["chatId"] as? String ?? "",
            chatTitle: d["chatTitle"] as? String ?? "",
            messageId: d["messageId"] as? String ?? "",
            model: d["model"] as? String,
            mimeType: d["mimeType"] as? String,
            name: d["name"] as? String,
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}
