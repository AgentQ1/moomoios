//
//  PersistenceService.swift
//  MoomoAI
//
//  Service for local data persistence
//

import Foundation

class PersistenceService {
    static let shared = PersistenceService()

    private let maxSessions = 50 // Match web app localStorage limit

    // PERFORMANCE: Serial queue for thread-safe persistence operations
    private let persistenceQueue = DispatchQueue(label: "com.moomo.persistence", qos: .utility)

    /// Pending coalesced save (message-path saves arrive once per message; only
    /// the newest snapshot needs to hit disk). Only touched from the main thread.
    private var pendingSave: DispatchWorkItem?

    private init() {}

    // MARK: - Chat Sessions

    func saveSessions(_ sessions: [ChatSession]) {
        // PERFORMANCE: Move encoding and saving off main thread
        persistenceQueue.async {
            self.persistNow(sessions)
        }
    }

    /// Coalesced variant for high-frequency callers (every message append).
    /// Encoding all sessions is O(total history), so bursts are collapsed into
    /// one write ~0.5s after the last update. Call from the main thread.
    func scheduleSaveSessions(_ sessions: [ChatSession]) {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.persistNow(sessions)
        }
        pendingSave = item
        persistenceQueue.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func persistNow(_ sessions: [ChatSession]) {
        // Limit sessions to prevent storage issues
        let limitedSessions = Array(sessions.prefix(maxSessions))

        // PERFORMANCE: Offload attached-image thumbnails to the on-disk cache and
        // strip them from the JSON kept in UserDefaults. This keeps launch fast and
        // avoids bloating UserDefaults (which is loaded fully into memory) with
        // base64 image data on every message update.
        let lightweight: [ChatSession] = limitedSessions.map { session in
            var session = session
            session.messages = session.messages.map { message in
                guard let data = message.imageData else { return message }
                if !ImageCache.shared.hasThumbnail(id: message.id) {
                    ImageCache.shared.storeThumbnail(data, id: message.id)
                }
                var message = message
                message.imageData = nil
                return message
            }
            return session
        }

        if let encoded = try? JSONEncoder().encode(lightweight) {
            UserDefaults.standard.set(encoded, forKey: "chat_sessions")
        }
    }

    func loadSessions() -> [ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: "chat_sessions"),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return []
        }
        // Attached-image thumbnails are NOT rehydrated here — doing so cost one
        // disk probe per message across every session on the launch path.
        // MessageBubbleView loads them lazily from ImageCache by message id.
        return sessions
    }

    func clearAllSessions() {
        UserDefaults.standard.removeObject(forKey: "chat_sessions")
    }

    // MARK: - Language

    func saveLanguage(_ language: Language) {
        UserDefaults.standard.set(language.code, forKey: "selected_language")
    }

    func loadLanguage() -> Language {
        let code = UserDefaults.standard.string(forKey: "selected_language") ?? "en"
        return Language.allLanguages.first { $0.code == code } ?? Language.defaultLanguage
    }

    // MARK: - Current Session

    func saveCurrentSessionId(_ sessionId: String) {
        UserDefaults.standard.set(sessionId, forKey: "current_session_id")
    }

    func loadCurrentSessionId() -> String? {
        return UserDefaults.standard.string(forKey: "current_session_id")
    }

    func clearCurrentSessionId() {
        UserDefaults.standard.removeObject(forKey: "current_session_id")
    }
}
