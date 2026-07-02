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
    
    private init() {}
    
    // MARK: - Chat Sessions
    
    func saveSessions(_ sessions: [ChatSession]) {
        // PERFORMANCE: Move encoding and saving off main thread
        persistenceQueue.async {
            // Limit sessions to prevent storage issues
            let limitedSessions = Array(sessions.prefix(self.maxSessions))

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
    }

    func loadSessions() -> [ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: "chat_sessions"),
              var sessions = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return []
        }
        // Rehydrate attached-image thumbnails from the on-disk cache.
        for index in sessions.indices {
            sessions[index].messages = sessions[index].messages.map { message in
                guard message.imageData == nil,
                      let data = ImageCache.shared.loadThumbnail(id: message.id) else { return message }
                var message = message
                message.imageData = data
                return message
            }
        }
        return sessions
    }
    
    func deleteSession(_ sessionId: String) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == sessionId }
        saveSessions(sessions)
    }
    
    func clearAllSessions() {
        UserDefaults.standard.removeObject(forKey: "chat_sessions")
    }
    
    // MARK: - User
    
    func saveUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "moomo_user")
        }
    }
    
    func loadUser() -> User? {
        guard let data = UserDefaults.standard.data(forKey: "moomo_user"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    func clearUser() {
        UserDefaults.standard.removeObject(forKey: "moomo_user")
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
