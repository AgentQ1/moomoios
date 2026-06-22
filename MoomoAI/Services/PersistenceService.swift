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
            
            if let encoded = try? JSONEncoder().encode(limitedSessions) {
                UserDefaults.standard.set(encoded, forKey: "chat_sessions")
            }
        }
    }
    
    func loadSessions() -> [ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: "chat_sessions"),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return []
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

    // MARK: - AI Data Sharing Consent

    func setAIDataSharingConsent(_ isAllowed: Bool) {
        UserDefaults.standard.set(isAllowed, forKey: "ai_data_sharing_consent")
    }

    func hasAIDataSharingConsent() -> Bool {
        return UserDefaults.standard.bool(forKey: "ai_data_sharing_consent")
    }
}
