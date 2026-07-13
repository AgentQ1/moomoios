//
//  MemoryService.swift
//  MoomoAI
//
//  Conversation + user-memory persistence, ChatGPT/Gemini style. Firestore layout:
//    users/{uid}/conversations/{conversationId}/messages/{messageId}
//    users/{uid}/memory/profile
//
//  Every method is best-effort: it no-ops when signed out and logs failures in
//  DEBUG only, so persistence problems never break the chat UI. The actual
//  memory *summary* is produced server-side (Gemini) via the updateMemory Cloud
//  Function — this service only reads it back and stores raw messages.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// The user-memory profile shown in Settings and injected into the model context.
struct UserMemory: Equatable {
    var summary: String = ""
    var preferences: [String] = []
    var importantFacts: [String] = []
    var projects: [String] = []
    var updatedAt: Date?

    var isEmpty: Bool {
        summary.isEmpty && preferences.isEmpty && importantFacts.isEmpty && projects.isEmpty
    }

    /// Compact text block injected into generateText when memory is enabled.
    var contextText: String {
        var lines: [String] = []
        if !summary.isEmpty { lines.append(summary) }
        if !preferences.isEmpty { lines.append("Preferences: " + preferences.joined(separator: "; ")) }
        if !importantFacts.isEmpty { lines.append("Important facts: " + importantFacts.joined(separator: "; ")) }
        if !projects.isEmpty { lines.append("Projects: " + projects.joined(separator: "; ")) }
        return lines.joined(separator: "\n")
    }
}

final class MemoryService {
    static let shared = MemoryService()
    private lazy var db = Firestore.firestore()
    private init() {}

    private let memoryEnabledKey = "moomo.memoryEnabled"

    // Cached memory profile: loadMemory() used to hit Firestore on EVERY message
    // send (adding a network round trip before generation even started). The
    // profile only changes when the backend folds memory, so cache it briefly and
    // invalidate after updateMemory/clearMemory. Guarded by a lock — async
    // callers resume on arbitrary executors.
    private let cacheLock = NSLock()
    private var cachedMemory: UserMemory?
    private var cachedMemoryUid: String?
    private var cachedMemoryAt: Date?
    private static let memoryCacheTTL: TimeInterval = 300

    /// Synchronous scoped locking (NSLock.lock is unavailable directly in async
    /// contexts; a sync helper keeps the critical section tiny and await-free).
    private func withCacheLock<T>(_ body: () -> T) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return body()
    }

    /// User-controlled toggle (default ON). Backed by UserDefaults so the Settings
    /// screen (@AppStorage) and the ViewModel read/write the same value.
    var isMemoryEnabled: Bool {
        get { UserDefaults.standard.object(forKey: memoryEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: memoryEnabledKey) }
    }

    private var uid: String? { Auth.auth().currentUser?.uid }

    /// True for anonymous (guest) sessions. Guests never build a durable memory
    /// profile, so the client skips updateMemory entirely (the backend also guards).
    var isGuest: Bool { Auth.auth().currentUser?.isAnonymous ?? true }

    // MARK: - Conversation messages

    /// Persist a single chat message under the current conversation (fire-and-forget).
    func saveMessage(conversationId: String,
                     conversationTitle: String,
                     message: ChatMessage,
                     attachment: AttachmentItem? = nil) {
        guard let uid else { return }

        var data: [String: Any] = [
            "role": message.role == .user ? "user" : "assistant",
            "text": message.content,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let url = message.imageURL { data["imageURL"] = url }
        if let path = message.imagePath { data["imagePath"] = path }
        if let prompt = message.prompt { data["prompt"] = prompt }
        if let model = message.model { data["model"] = model }
        // Attached-image thumbnail, so multimodal context (follow-ups, regenerate)
        // survives hydration on this or another device. Firestore docs cap at
        // 1 MB — a 300px JPEG is ~15–40 KB; skip anything unexpectedly large.
        if let imageData = message.imageData, imageData.count <= 300_000 {
            data["imageData"] = imageData
        }
        if let attachment {
            data["attachment"] = [
                "name": attachment.name,
                "mimeType": attachment.mimeType,
                "source": attachment.source.rawValue,
            ]
        }

        let conversationRef = db.collection("users").document(uid)
            .collection("conversations").document(conversationId)

        // One batch = one network round trip for the message + the lightweight
        // conversation metadata (title/updatedAt) used to list and sort chats.
        let batch = db.batch()
        batch.setData([
            "title": conversationTitle,
            "updatedAt": FieldValue.serverTimestamp(),
        ], forDocument: conversationRef, merge: true)
        batch.setData(data, forDocument: conversationRef.collection("messages").document(message.id))
        batch.commit { error in
            #if DEBUG
            if let error { print("MEMORY saveMessage error=\(error.localizedDescription)") }
            #endif
        }
    }

    /// Delete a single message's cloud copy (best-effort, fire-and-forget).
    func deleteMessage(conversationId: String, messageId: String) {
        guard let uid else { return }
        db.collection("users").document(uid)
            .collection("conversations").document(conversationId)
            .collection("messages").document(messageId).delete()
    }

    /// Update a conversation's title server-side so renames survive re-login.
    func renameConversation(conversationId: String, title: String) {
        guard let uid else { return }
        db.collection("users").document(uid)
            .collection("conversations").document(conversationId)
            .setData(["title": title], merge: true)
    }

    /// Best-effort recursive delete of one conversation (its messages, then the
    /// conversation doc). Firestore has no client-side recursive delete, so the
    /// messages are removed in pages off the main thread.
    func deleteConversation(conversationId: String) {
        guard let uid else { return }
        let convoRef = db.collection("users").document(uid)
            .collection("conversations").document(conversationId)
        Task.detached(priority: .utility) { [db] in
            await Self.deleteConversationTree(db: db, convoRef: convoRef)
        }
    }

    /// Best-effort delete of every conversation (Profile → Clear All Chats).
    func deleteAllConversations() {
        guard let uid else { return }
        let conversations = db.collection("users").document(uid).collection("conversations")
        Task.detached(priority: .utility) { [db] in
            do {
                while true {
                    let page = try await conversations.limit(to: 100).getDocuments()
                    guard !page.documents.isEmpty else { break }
                    for doc in page.documents {
                        await Self.deleteConversationTree(db: db, convoRef: doc.reference)
                    }
                    if page.documents.count < 100 { break }
                }
            } catch {
                #if DEBUG
                print("MEMORY deleteAllConversations error=\(error.localizedDescription)")
                #endif
            }
        }
    }

    private static func deleteConversationTree(db: Firestore, convoRef: DocumentReference) async {
        do {
            while true {
                let page = try await convoRef.collection("messages").limit(to: 250).getDocuments()
                guard !page.documents.isEmpty else { break }
                let batch = db.batch()
                page.documents.forEach { batch.deleteDocument($0.reference) }
                try await batch.commit()
                if page.documents.count < 250 { break }
            }
            try await convoRef.delete()
        } catch {
            #if DEBUG
            print("MEMORY deleteConversation error=\(error.localizedDescription)")
            #endif
        }
    }

    /// Load the most recent messages for a conversation, oldest first. Bounded by
    /// `limit` so very long chats don't load hundreds of documents on open
    /// (older turns stay available server-side and the rolling memory summary
    /// preserves their context).
    func loadMessages(conversationId: String, limit: Int = 80) async -> [ChatMessage] {
        guard let uid else { return [] }
        do {
            // Fetch newest-first + limited, then reverse to chronological order.
            let snapshot = try await db.collection("users").document(uid)
                .collection("conversations").document(conversationId)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            return snapshot.documents.reversed().compactMap(Self.message(from:))
        } catch {
            #if DEBUG
            print("MEMORY loadMessages error=\(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Load the conversation list (metadata only, no messages) so chats reappear
    /// after logging in on a fresh device. Messages are hydrated lazily when a
    /// conversation is opened.
    func loadConversations(limit: Int = 50) async -> [ChatSession] {
        guard let uid else { return [] }
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("conversations")
                .order(by: "updatedAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            return snapshot.documents.compactMap { doc -> ChatSession? in
                let d = doc.data()
                let title = d["title"] as? String ?? "Chat"
                let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                return ChatSession(
                    id: doc.documentID,
                    title: title,
                    messages: [],
                    createdAt: updatedAt,
                    updatedAt: updatedAt
                )
            }
        } catch {
            #if DEBUG
            print("MEMORY loadConversations error=\(error.localizedDescription)")
            #endif
            return []
        }
    }

    /// Map a Firestore message document back into a ChatMessage.
    private static func message(from doc: QueryDocumentSnapshot) -> ChatMessage? {
        let d = doc.data()
        guard let roleString = d["role"] as? String else { return nil }
        let role: ChatMessage.MessageRole = (roleString == "user") ? .user : .assistant
        let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let attachment = d["attachment"] as? [String: Any]
        return ChatMessage(
            id: doc.documentID,
            role: role,
            content: d["text"] as? String ?? "",
            timestamp: createdAt,
            imageData: d["imageData"] as? Data,
            imageURL: d["imageURL"] as? String,
            imagePath: d["imagePath"] as? String,
            prompt: d["prompt"] as? String,
            model: d["model"] as? String,
            attachmentName: attachment?["name"] as? String,
            attachmentMime: attachment?["mimeType"] as? String
        )
    }

    // MARK: - User memory / profile

    func loadMemory() async -> UserMemory? {
        guard let uid else { return nil }

        let cached: (hit: Bool, value: UserMemory?) = withCacheLock {
            guard cachedMemoryUid == uid, let at = cachedMemoryAt,
                  Date().timeIntervalSince(at) < Self.memoryCacheTTL else {
                return (false, nil)
            }
            return (true, cachedMemory)
        }
        if cached.hit { return cached.value }

        do {
            let doc = try await db.collection("users").document(uid)
                .collection("memory").document("profile").getDocument()
            let d = doc.data()
            let memory = d.map { d in
                UserMemory(
                    summary: d["summary"] as? String ?? "",
                    preferences: d["preferences"] as? [String] ?? [],
                    importantFacts: d["importantFacts"] as? [String] ?? [],
                    projects: d["projects"] as? [String] ?? [],
                    updatedAt: (d["updatedAt"] as? Timestamp)?.dateValue()
                )
            }
            withCacheLock {
                cachedMemory = memory
                cachedMemoryUid = uid
                cachedMemoryAt = Date()
            }
            return memory
        } catch {
            #if DEBUG
            print("MEMORY loadMemory error=\(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Drop the cached profile (after the backend folds new memory, on clear,
    /// or on account changes) so the next read fetches fresh data.
    func invalidateMemoryCache() {
        withCacheLock {
            cachedMemory = nil
            cachedMemoryUid = nil
            cachedMemoryAt = nil
        }
    }

    /// Delete the stored memory profile (Settings → Clear memory). Memory is
    /// client-read-only in Firestore, so the delete is performed server-side via
    /// the clearMemory Cloud Function (Admin SDK).
    func clearMemory() async {
        guard uid != nil else { return }
        invalidateMemoryCache()
        do {
            try await GenerationService.shared.clearMemory()
        } catch {
            #if DEBUG
            print("MEMORY clearMemory error=\(error.localizedDescription)")
            #endif
        }
    }
}
