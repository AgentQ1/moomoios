//
//  FirebaseService.swift
//  MoomoAI
//
//  Service for Firebase operations - matches web app Firebase integration
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase
import FirebaseAnalytics

class FirebaseService {
    static let shared = FirebaseService()
    
    private let database: DatabaseReference
    private var sessionsSyncHandle: DatabaseHandle?
    private var messagesSyncHandles: [String: DatabaseHandle] = [:]
    
    private init() {
        // Enable offline persistence BEFORE accessing database
        Database.database().isPersistenceEnabled = true
        
        // Now get the database reference
        self.database = Database.database().reference()
    }
    
    // MARK: - User Management
    
    /// Save or update user in Firebase Realtime Database
    func saveUser(_ user: User) async throws {
        let userKey = user.email.replacingOccurrences(of: ".", with: "_")
        let userRef = database.child("users").child(userKey)
        
        // Check if user exists
        let snapshot = try await userRef.getData()
        
        let userData: [String: Any] = [
            "email": user.email,
            "name": user.name,
            "picture": user.picture ?? "",
            "userId": user.id,
            "lastSignIn": ISO8601DateFormatter().string(from: Date()),
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        if !snapshot.exists() {
            // New user
            var newUserData = userData
            newUserData["createdAt"] = ISO8601DateFormatter().string(from: Date())
            newUserData["totalSessions"] = 1
            newUserData["totalMessages"] = 0
            newUserData["totalSearches"] = 0
            newUserData["connectedServices"] = []
            
            try await userRef.setValue(newUserData)
            print("✅ NEW user profile created: \(user.email)")
        } else {
            // Existing user - update last sign in
            let existingData = snapshot.value as? [String: Any]
            let totalSessions = (existingData?["totalSessions"] as? Int ?? 0) + 1
            
            var updateData = userData
            updateData["totalSessions"] = totalSessions
            
            try await userRef.updateChildValues(updateData)
            print("✅ EXISTING user profile updated: \(user.email)")
        }
    }
    
    /// Fetch user stats from Firebase Realtime Database
    func fetchUserStats(email: String) async -> (totalMessages: Int, totalSessions: Int, totalSearches: Int)? {
        let userKey = email.replacingOccurrences(of: ".", with: "_")
        let userRef = database.child("users").child(userKey)
        
        do {
            let snapshot = try await userRef.getData()
            guard let data = snapshot.value as? [String: Any] else { return nil }
            
            let totalMessages = data["totalMessages"] as? Int ?? 0
            let totalSessions = data["totalSessions"] as? Int ?? 0
            let totalSearches = data["totalSearches"] as? Int ?? 0
            
            return (totalMessages, totalSessions, totalSearches)
        } catch {
            print("❌ Error fetching user stats: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Delete all sessions for a user from Firebase
    func deleteAllSessions(userEmail: String) async throws {
        let userKey = userEmail.replacingOccurrences(of: ".", with: "_")
        let sessionsRef = database.child("users").child(userKey).child("sessions")
        try await sessionsRef.removeValue()
        print("✅ All sessions deleted from Firebase for: \(userEmail)")
    }
    
    /// Track user activity
    func trackActivity(email: String, activityType: String, data: [String: Any] = [:]) async {
        let userKey = email.replacingOccurrences(of: ".", with: "_")
        let userRef = database.child("users").child(userKey)
        
        // Save activity to activities sub-node
        let activityRef = userRef.child("activities").childByAutoId()
        var activityData = data
        activityData["type"] = activityType
        activityData["timestamp"] = ISO8601DateFormatter().string(from: Date())
        activityData["userEmail"] = email
        
        do {
            try await activityRef.setValue(activityData)
            
            // Update user counters
            let snapshot = try await userRef.getData()
            let existingData = snapshot.value as? [String: Any] ?? [:]
            
            var updates: [String: Any] = [
                "updatedAt": ISO8601DateFormatter().string(from: Date())
            ]
            
            switch activityType {
            case "message_sent":
                let totalMessages = (existingData["totalMessages"] as? Int ?? 0) + 1
                updates["totalMessages"] = totalMessages
                if let message = data["message"] as? String {
                    updates["lastMessage"] = String(message.prefix(100))
                }
            case "search":
                let totalSearches = (existingData["totalSearches"] as? Int ?? 0) + 1
                updates["totalSearches"] = totalSearches
                if let searchTerm = data["search_term"] as? String {
                    updates["lastSearch"] = searchTerm
                }
            case "service_connected":
                if let serviceName = data["service_name"] as? String {
                    var currentServices = existingData["connectedServices"] as? [String] ?? []
                    if !currentServices.contains(serviceName) {
                        currentServices.append(serviceName)
                        updates["connectedServices"] = currentServices
                    }
                }
            default:
                break
            }
            
            try await userRef.updateChildValues(updates)
            print("✅ Activity tracked: \(activityType)")
        } catch {
            print("❌ Error tracking activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Analytics
    
    /// Log event to Firebase Analytics
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    /// Set user for analytics
    func setAnalyticsUser(userId: String, email: String) {
        Analytics.setUserID(userId)
        Analytics.setUserProperty(email, forName: "email")
        print("✅ User set in Firebase Analytics: \(email)")
    }
    
    /// Track sign in
    func trackSignIn(method: String) {
        logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }
    
    /// Track message sent
    func trackMessageSent(type: String = "text") {
        logEvent("message_sent", parameters: [
            "message_type": type
        ])
    }
    
    /// Track AI response
    func trackAIResponse(length: Int) {
        logEvent("ai_response", parameters: [
            "response_length": length
        ])
    }
    
    // MARK: - Enhanced Analytics
    
    /// Track feature usage with detailed metrics
    func trackFeatureUsage(feature: String, action: String? = nil, metadata: [String: Any] = [:]) {
        var params = metadata
        if let action = action {
            params["action"] = action
        }
        params["feature"] = feature
        params["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        logEvent("feature_usage", parameters: params)
        
        // Also save to user's activity log
        Task {
            if let email = PersistenceService.shared.loadUser()?.email {
                await trackActivity(email: email, activityType: "feature_usage", data: params)
            }
        }
    }
    
    /// Track voice call metrics
    func trackVoiceCall(duration: TimeInterval, messageCount: Int, userSpeakTime: TimeInterval? = nil) {
        let params: [String: Any] = [
            "duration_seconds": Int(duration),
            "message_count": messageCount,
            "user_speak_time": userSpeakTime != nil ? Int(userSpeakTime!) : 0,
            "feature": "voice_call"
        ]
        
        logEvent("voice_call_completed", parameters: params)
        trackFeatureUsage(feature: "voice_call", action: "completed", metadata: params)
    }
    
    /// Track news interaction
    func trackNewsInteraction(category: String, action: String, articleTitle: String? = nil) {
        var params: [String: Any] = [
            "category": category,
            "action": action
        ]
        if let title = articleTitle {
            params["article_title"] = String(title.prefix(100))
        }
        
        logEvent("news_interaction", parameters: params)
        trackFeatureUsage(feature: "news", action: action, metadata: params)
    }
    
    /// Track Google service usage
    func trackGoogleServiceUsage(service: String, action: String, resultCount: Int? = nil) {
        var params: [String: Any] = [
            "service": service,
            "action": action
        ]
        if let count = resultCount {
            params["result_count"] = count
        }
        
        logEvent("google_service_usage", parameters: params)
        trackFeatureUsage(feature: "google_\(service.lowercased())", action: action, metadata: params)
    }
    
    /// Track attachment usage
    func trackAttachmentUsage(type: String, size: Int, source: String) {
        let params: [String: Any] = [
            "attachment_type": type,
            "size_bytes": size,
            "source": source
        ]
        
        logEvent("attachment_added", parameters: params)
        trackFeatureUsage(feature: "attachments", action: "added", metadata: params)
    }
    
    /// Track session metrics
    func trackSessionMetrics(sessionId: String, duration: TimeInterval, messageCount: Int, hasAttachments: Bool) {
        let params: [String: Any] = [
            "session_id": sessionId,
            "duration_seconds": Int(duration),
            "message_count": messageCount,
            "has_attachments": hasAttachments
        ]
        
        logEvent("session_metrics", parameters: params)
    }
    
    /// Track language switch
    func trackLanguageSwitch(from: String, to: String) {
        let params: [String: Any] = [
            "from_language": from,
            "to_language": to
        ]
        
        logEvent("language_switched", parameters: params)
        trackFeatureUsage(feature: "language", action: "switched", metadata: params)
    }
    
    /// Track export action
    func trackExport(format: String, sessionId: String, messageCount: Int) {
        let params: [String: Any] = [
            "format": format,
            "session_id": sessionId,
            "message_count": messageCount
        ]
        
        logEvent("conversation_exported", parameters: params)
        trackFeatureUsage(feature: "export", action: "completed", metadata: params)
    }
    
    /// Track error occurrences
    func trackError(error: Error, context: String, isFatal: Bool = false) {
        let params: [String: Any] = [
            "error_description": error.localizedDescription,
            "context": context,
            "is_fatal": isFatal,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code
        ]
        
        logEvent("error_occurred", parameters: params)
        
        // Log to Firebase Database for monitoring
        Task {
            if let email = PersistenceService.shared.loadUser()?.email {
                await trackActivity(email: email, activityType: "error", data: params)
            }
        }
    }
    
    /// Track app session
    func trackAppSession(action: String) {
        let params: [String: Any] = [
            "action": action,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        logEvent("app_session_\(action)", parameters: params)
    }
    
    /// Track search usage
    func trackSearch(query: String, resultCount: Int, context: String) {
        let params: [String: Any] = [
            "query_length": query.count,
            "result_count": resultCount,
            "context": context
        ]
        
        logEvent("search_performed", parameters: params)
        trackFeatureUsage(feature: "search", action: "performed", metadata: params)
    }
    
    /// Track AI regeneration
    func trackRegeneration(messageId: String, attemptNumber: Int) {
        let params: [String: Any] = [
            "message_id": messageId,
            "attempt_number": attemptNumber
        ]
        
        logEvent("message_regenerated", parameters: params)
        trackFeatureUsage(feature: "regenerate", action: "completed", metadata: params)
    }
    
    // MARK: - Real-time Sync
    
    /// Start syncing sessions for a user
    func startSyncingSessions(userEmail: String, onUpdate: @escaping ([ChatSession]) -> Void) {
        let userKey = userEmail.replacingOccurrences(of: ".", with: "_")
        let sessionsRef = database.child("users").child(userKey).child("sessions")
        
        // Stop previous listener if exists
        stopSyncingSessions()
        
        // PERFORMANCE: Use .childChanged instead of .value to get only updates
        // Listen for changes with limit to prevent loading all data
        sessionsSyncHandle = sessionsRef.queryLimited(toLast: 50).observe(.value, with: { snapshot in
            guard snapshot.exists(), let sessionsData = snapshot.value as? [String: Any] else {
                onUpdate([])
                return
            }
            
            // PERFORMANCE: Parse in background to avoid blocking main thread
            Task.detached(priority: .userInitiated) {
                var sessions: [ChatSession] = []
                
                for (sessionId, sessionDataAny) in sessionsData {
                    guard let sessionData = sessionDataAny as? [String: Any] else { continue }
                    
                    let title = sessionData["title"] as? String ?? "New chat"
                    let isPinned = sessionData["isPinned"] as? Bool ?? false
                    
                    // Parse dates
                    let createdAt = self.parseDate(sessionData["createdAt"] as? String) ?? Date()
                    let updatedAt = self.parseDate(sessionData["updatedAt"] as? String) ?? Date()
                    
                    // Parse messages - PERFORMANCE: Limit messages per session
                    var messages: [ChatMessage] = []
                    if let messagesData = sessionData["messages"] as? [String: Any] {
                        // Only load recent messages to reduce memory
                        let messagePairs = Array(messagesData.prefix(100))
                        for (messageId, messageDataAny) in messagePairs {
                            guard let messageData = messageDataAny as? [String: Any] else { continue }
                            
                            let role = messageData["role"] as? String == "user" ? ChatMessage.MessageRole.user : ChatMessage.MessageRole.assistant
                            let content = messageData["content"] as? String ?? ""
                            let timestamp = self.parseDate(messageData["timestamp"] as? String) ?? Date()
                            
                            let message = ChatMessage(
                                id: messageId,
                                role: role,
                                content: content,
                                timestamp: timestamp
                            )
                            messages.append(message)
                        }
                    }
                    
                    // Sort messages by timestamp
                    messages.sort { $0.timestamp < $1.timestamp }
                    
                    let session = ChatSession(
                        id: sessionId,
                        title: title,
                        messages: messages,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        isPinned: isPinned
                    )
                    sessions.append(session)
                }
                
                // Sort sessions: pinned first, then by updated date
                sessions.sort { lhs, rhs in
                    if lhs.isPinned != rhs.isPinned {
                        return lhs.isPinned
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
                
                await MainActor.run {
                    onUpdate(sessions)
                    print("✅ Sessions synced from Firebase: \(sessions.count) sessions")
                }
            }
        })
    }
    
    /// Stop syncing sessions
    func stopSyncingSessions() {
        if let handle = sessionsSyncHandle {
            database.removeObserver(withHandle: handle)
            sessionsSyncHandle = nil
            print("✅ Stopped syncing sessions")
        }
    }
    
    /// Save session to Firebase
    func saveSession(_ session: ChatSession, userEmail: String) async throws {
        let userKey = userEmail.replacingOccurrences(of: ".", with: "_")
        let sessionRef = database.child("users").child(userKey).child("sessions").child(session.id)
        
        // Convert messages to dictionary
        var messagesDict: [String: Any] = [:]
        for message in session.messages {
            messagesDict[message.id] = [
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content,
                "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
            ]
        }
        
        let sessionData: [String: Any] = [
            "title": session.title,
            "isPinned": session.isPinned,
            "createdAt": ISO8601DateFormatter().string(from: session.createdAt),
            "updatedAt": ISO8601DateFormatter().string(from: session.updatedAt),
            "messages": messagesDict
        ]
        
        try await sessionRef.setValue(sessionData)
        print("✅ Session saved to Firebase: \(session.title)")
    }
    
    /// Delete session from Firebase
    func deleteSession(_ sessionId: String, userEmail: String) async throws {
        let userKey = userEmail.replacingOccurrences(of: ".", with: "_")
        let sessionRef = database.child("users").child(userKey).child("sessions").child(sessionId)
        
        try await sessionRef.removeValue()
        print("✅ Session deleted from Firebase: \(sessionId)")
    }
    
    /// Update session metadata (title, isPinned, updatedAt)
    func updateSessionMetadata(_ session: ChatSession, userEmail: String) async throws {
        let userKey = userEmail.replacingOccurrences(of: ".", with: "_")
        let sessionRef = database.child("users").child(userKey).child("sessions").child(session.id)
        
        let updates: [String: Any] = [
            "title": session.title,
            "isPinned": session.isPinned,
            "updatedAt": ISO8601DateFormatter().string(from: session.updatedAt)
        ]
        
        try await sessionRef.updateChildValues(updates)
        print("✅ Session metadata updated in Firebase: \(session.title)")
    }
    
    /// Add message to session in Firebase
    func addMessage(_ message: ChatMessage, sessionId: String, userEmail: String) async throws {
        let userKey = userEmail.replacingOccurrences(of: ".", with: "_")
        let messageRef = database.child("users").child(userKey).child("sessions").child(sessionId).child("messages").child(message.id)
        
        let messageData: [String: Any] = [
            "role": message.role == .user ? "user" : "assistant",
            "content": message.content,
            "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
        ]
        
        try await messageRef.setValue(messageData)
        
        // Update session updatedAt
        let sessionRef = database.child("users").child(userKey).child("sessions").child(sessionId)
        try await sessionRef.updateChildValues([
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ])
        
        print("✅ Message added to Firebase session: \(sessionId)")
    }
    
    /// Sync all local sessions to Firebase
    func syncAllSessions(_ sessions: [ChatSession], userEmail: String) async throws {
        for session in sessions {
            try await saveSession(session, userEmail: userEmail)
        }
        print("✅ All sessions synced to Firebase: \(sessions.count) sessions")
    }
    
    // MARK: - Helpers
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
}
