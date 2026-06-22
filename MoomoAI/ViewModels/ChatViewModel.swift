//
//  ChatViewModel.swift
//  MoomoAI
//
//  ViewModel for chat functionality - matches web app exactly
//

import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var currentSession: ChatSession?
    @Published var isLoading = false
    @Published var selectedLanguage: Language = Language.defaultLanguage
    @Published var selectedModel: AIModel = .Q1 // Default to Q1
    @Published var errorMessage: String?
    @Published var isSyncEnabled = false
    
    private let persistence = PersistenceService.shared
    private let modelAPI = ModelAPIService.shared
    private let firebaseService = FirebaseService.shared
    
    // PERFORMANCE: Cache for service queries to avoid repeated API calls
    private var serviceQueryCache: [String: (result: String, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // PERFORMANCE: Debounce Firebase sync operations
    private var syncDebounceTask: Task<Void, Never>?
    
    init() {
        loadSessions()
        selectedLanguage = persistence.loadLanguage()
        
        // Create new session if none exists
        if currentSession == nil {
            createNewSession()
        }
    }
    
    deinit {
        // CRITICAL FIX: Properly cleanup resources
        syncDebounceTask?.cancel()
        firebaseService.stopSyncingSessions()
        serviceQueryCache.removeAll()
    }
    
    // MARK: - Session Management
    
    func createNewSession() {
        let newSession = ChatSession(title: "New chat")
        sessions.insert(newSession, at: 0)
        currentSession = newSession
        persistence.saveSessions(sessions.filter { !$0.isTemporary })
        persistence.saveCurrentSessionId(newSession.id)
    }
    
    func createTemporarySession() {
        let tempSession = ChatSession(title: "Temporary chat", isTemporary: true)
        currentSession = tempSession
        // Temporary sessions are NOT added to sessions list or persisted
    }
    
    func selectSession(_ session: ChatSession) {
        currentSession = session
        persistence.saveCurrentSessionId(session.id)
    }
    
    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        
        if currentSession?.id == session.id {
            currentSession = sessions.first
            if currentSession == nil {
                createNewSession()
            }
        }
        
        persistence.saveSessions(sessions)
        persistence.deleteSession(session.id)
        
        // Sync deletion to Firebase if enabled
        if isSyncEnabled, let userEmail = persistence.loadUser()?.email {
            Task {
                do {
                    try await firebaseService.deleteSession(session.id, userEmail: userEmail)
                } catch {
                    print("❌ Error deleting session from Firebase: \(error)")
                }
            }
        }
    }
    
    func renameSession(_ session: ChatSession, newTitle: String) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].updateTitle(newTitle)
            if currentSession?.id == session.id {
                currentSession = sessions[index]
            }
            persistence.saveSessions(sessions)
        }
    }
    
    func togglePinSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].isPinned.toggle()
            if currentSession?.id == session.id {
                currentSession = sessions[index]
            }
            // Re-sort sessions: pinned first, then by updated date
            sortSessions()
            persistence.saveSessions(sessions)
        }
    }
    
    func toggleImportantSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].isImportant.toggle()
            if currentSession?.id == session.id {
                currentSession = sessions[index]
            }
            persistence.saveSessions(sessions)
        }
    }
    
    func toggleArchiveSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].isArchived.toggle()
            if currentSession?.id == session.id {
                currentSession = sessions[index]
            }
            persistence.saveSessions(sessions)
        }
    }
    
    func exportSessionToTXT(_ session: ChatSession) -> URL? {
        return ExportService.shared.exportToTXT(session)
    }
    
    func exportSessionToPDF(_ session: ChatSession) -> URL? {
        return ExportService.shared.exportToPDF(session)
    }
    
    private func sortSessions() {
        sessions.sort { lhs, rhs in
            // Pinned sessions first
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            // Then by updated date
            return lhs.updatedAt > rhs.updatedAt
        }
    }
    
    func duplicateSession(_ session: ChatSession) {
        let duplicate = ChatSession(
            title: "\(session.title) (Copy)",
            messages: session.messages
        )
        sessions.insert(duplicate, at: 0)
        persistence.saveSessions(sessions)
    }
    
    func clearAllSessions() {
        sessions.removeAll()
        persistence.clearAllSessions()
        createNewSession()
        
        // Also clear from Firebase if sync is enabled
        if isSyncEnabled, let userEmail = persistence.loadUser()?.email {
            Task {
                do {
                    try await firebaseService.deleteAllSessions(userEmail: userEmail)
                } catch {
                    print("❌ Error clearing sessions from Firebase: \(error)")
                }
            }
        }
    }
    
    private func loadSessions() {
        sessions = persistence.loadSessions()
        
        // Load current session
        if let sessionId = persistence.loadCurrentSessionId(),
           let session = sessions.first(where: { $0.id == sessionId }) {
            currentSession = session
        } else if let firstSession = sessions.first {
            currentSession = firstSession
        }
    }
    
    // MARK: - Message Handling
    
    func sendMessage(_ messageText: String, attachments: [AttachmentItem] = []) async {
        guard var session = currentSession else {
            return
        }
        
        // PERFORMANCE: Track analytics in background without blocking
        Task.detached(priority: .utility) {
            await FirebaseService.shared.trackMessageSent()
            
            if let user = await PersistenceService.shared.loadUser() {
                await FirebaseService.shared.trackActivity(
                    email: user.email,
                    activityType: "message_sent",
                    data: [
                        "message": messageText,
                        "messageLength": messageText.count,
                        "hasAttachments": !attachments.isEmpty
                    ]
                )
            }
        }
        
        // Add user message (with thumbnail if image attached)
        let thumbnailData: Data? = attachments.first(where: { $0.type == .image })?.thumbnailJPEGData(maxDimension: 300)
        let userMessage = ChatMessage(role: .user, content: messageText, imageData: thumbnailData)
        session.addMessage(userMessage)
        updateSession(session)
        
        // Show typing indicator
        isLoading = true
        print("🟡 Showing typing indicator...")
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)
        
        do {
            // Build system prompt with language
            let systemPrompt = buildSystemPrompt()
            print("🟡 System prompt: \(systemPrompt)")
            
            // Limit conversation history to last 20 messages (performance optimization)
            let limitedMessages = Array(session.messages.dropLast().suffix(20))
            print("🟡 Sending \(limitedMessages.count) messages to \(selectedModel.displayName) API with \(attachments.count) attachments...")
            print("🟡 Messages preview:")
            for (index, msg) in limitedMessages.enumerated() {
                print("  [\(index)] \(msg.role): \(msg.content.prefix(50))...")
            }
            
            // Get AI response using selected model
            let response = try await modelAPI.sendMessage(
                model: selectedModel,
                messages: limitedMessages,
                systemPrompt: systemPrompt,
                attachments: attachments
            )
            print("✅ Got response from \(selectedModel.displayName): \(response.prefix(100))...")
            
            // Track AI response
            firebaseService.trackAIResponse(length: response.count)
            
            // Remove typing indicator and add response
            session.messages.removeLast()
            let assistantMessage = ChatMessage(role: .assistant, content: response)
            session.addMessage(assistantMessage)
            updateSession(session)
            
        } catch {
            print("❌ Error sending message: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error localized: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            
            // Remove typing indicator and show the actual error
            session.messages.removeLast()
            let errorContent: String
            if let apiError = error as? ModelAPIError {
                errorContent = "⚠️ \(apiError.localizedDescription)"
            } else {
                errorContent = "⚠️ \(error.localizedDescription)"
            }
            let errorMsg = ChatMessage(
                role: .assistant,
                content: errorContent
            )
            session.addMessage(errorMsg)
            updateSession(session)
        }
        
        isLoading = false
    }
    
    private func buildSystemPrompt() -> String {
        let languageName = selectedLanguage.name
        
        if selectedLanguage.code != "en" {
            return "You are Moomo, an intelligent AI assistant. CRITICAL: The user has selected \(languageName) as their preferred language. You MUST respond entirely in \(languageName). Provide accurate, comprehensive, and well-structured responses. Never respond in English unless the user explicitly asks for translation."
        } else {
            return "You are Moomo, an intelligent AI assistant. Provide accurate, comprehensive, and well-structured responses. Be direct and to the point while remaining helpful and informative."
        }
    }
    
    private func updateSession(_ session: ChatSession) {
        // Temporary chats: update in-memory only, no persistence or sync
        if session.isTemporary {
            currentSession = session
            return
        }
        
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            currentSession = session
            
            // PERFORMANCE: Save to persistence in background
            Task.detached(priority: .utility) { [sessions] in
                await PersistenceService.shared.saveSessions(sessions)
            }
            
            // PERFORMANCE: Debounce Firebase sync to avoid excessive writes
            if isSyncEnabled, let userEmail = persistence.loadUser()?.email {
                syncDebounceTask?.cancel()
                syncDebounceTask = Task { [weak self] in
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
                        try await self?.firebaseService.saveSession(session, userEmail: userEmail)
                    } catch {
                        print("❌ Error syncing session to Firebase: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Firebase Sync
    
    /// Enable real-time sync with Firebase
    func enableFirebaseSync(userEmail: String) {
        guard !isSyncEnabled else { return }
        
        // Start listening for session changes
        firebaseService.startSyncingSessions(userEmail: userEmail) { [weak self] syncedSessions in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Merge synced sessions with local sessions
                self.mergeSessions(syncedSessions)
            }
        }
        
        isSyncEnabled = true
        print("✅ Firebase sync enabled for: \(userEmail)")
    }
    
    /// Disable Firebase sync
    func disableFirebaseSync() {
        firebaseService.stopSyncingSessions()
        isSyncEnabled = false
        print("✅ Firebase sync disabled")
    }
    
    /// Sync current session to Firebase
    func syncCurrentSessionToFirebase(userEmail: String) {
        guard let session = currentSession else { return }
        
        Task {
            do {
                try await firebaseService.saveSession(session, userEmail: userEmail)
            } catch {
                print("❌ Error syncing session to Firebase: \(error)")
            }
        }
    }
    
    /// Sync all sessions to Firebase
    func syncAllSessionsToFirebase(userEmail: String) {
        Task {
            do {
                try await firebaseService.syncAllSessions(sessions, userEmail: userEmail)
            } catch {
                print("❌ Error syncing all sessions to Firebase: \(error)")
            }
        }
    }
    
    /// Merge synced sessions from Firebase with local sessions
    private func mergeSessions(_ syncedSessions: [ChatSession]) {
        // Use timestamp-based conflict resolution
        var mergedSessions: [String: ChatSession] = [:]
        
        // Add local sessions
        for session in sessions {
            mergedSessions[session.id] = session
        }
        
        // Merge with synced sessions (newer wins)
        for syncedSession in syncedSessions {
            if let localSession = mergedSessions[syncedSession.id] {
                // Keep the one with newer updatedAt
                if syncedSession.updatedAt > localSession.updatedAt {
                    mergedSessions[syncedSession.id] = syncedSession
                }
            } else {
                // New session from another device
                mergedSessions[syncedSession.id] = syncedSession
            }
        }
        
        // Update sessions array
        sessions = Array(mergedSessions.values).sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        
        // Ensure current session is still valid
        if let currentId = currentSession?.id,
           let updatedSession = mergedSessions[currentId] {
            currentSession = updatedSession
        }
        
        // Save to local persistence
        persistence.saveSessions(sessions)
    }
    
    // MARK: - Message Actions
    
    func toggleReaction(messageId: String, emoji: String) {
        guard var session = currentSession else { return }
        
        if let index = session.messages.firstIndex(where: { $0.id == messageId }) {
            var message = session.messages[index]
            
            if message.reactions.contains(emoji) {
                message.removeReaction(emoji)
            } else {
                message.addReaction(emoji)
            }
            
            session.messages[index] = message
            updateSession(session)
        }
    }
    
    func deleteMessage(messageId: String) {
        guard var session = currentSession else { return }
        
        session.messages.removeAll { $0.id == messageId }
        updateSession(session)
    }
    
    func regenerateMessage(messageId: String, temperature: Double, editedPrompt: String) {
        guard var session = currentSession else { return }
        
        // Find the message to regenerate
        guard let messageIndex = session.messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        // Create conversation history up to this point (excluding the message to regenerate)
        let historyMessages = Array(session.messages[0..<messageIndex])
        
        // Add a temporary loading message to replace the old one
        session.messages[messageIndex] = ChatMessage(
            id: messageId,
            role: .assistant,
            content: "",
            isTyping: true
        )
        updateSession(session)
        
        isLoading = true
        
        Task {
            do {
                // Regenerate with the edited prompt using Q1
                var regenMessages = historyMessages
                regenMessages.append(ChatMessage(role: .user, content: editedPrompt))
                let response = try await modelAPI.sendMessage(
                    model: selectedModel,
                    messages: regenMessages,
                    systemPrompt: buildSystemPrompt()
                )
                
                // Update the message with the new response
                if var updatedSession = currentSession {
                    updatedSession.messages[messageIndex] = ChatMessage(
                        id: messageId,
                        role: .assistant,
                        content: response
                    )
                    updateSession(updatedSession)
                }
                
                isLoading = false
            } catch {
                // Handle error
                errorMessage = "Failed to regenerate: \(error.localizedDescription)"
                isLoading = false
                
                // Restore original message or show error
                if var errorSession = currentSession {
                    errorSession.messages[messageIndex] = ChatMessage(
                        id: messageId,
                        role: .assistant,
                        content: "Failed to regenerate response. Please try again."
                    )
                    updateSession(errorSession)
                }
                
                firebaseService.trackError(
                    error: error,
                    context: "message_regeneration",
                    isFatal: false
                )
            }
        }
    }
    
    // MARK: - Language Selection
    
    func selectLanguage(_ language: Language) {
        let previousLanguage = selectedLanguage
        selectedLanguage = language
        persistence.saveLanguage(language)
        
        // Track language switch
        if previousLanguage.code != language.code {
            firebaseService.trackLanguageSwitch(
                from: previousLanguage.name,
                to: language.name
            )
        }
    }
    
    // MARK: - Performance Optimizations
    
    // PERFORMANCE: Cache service queries to reduce API calls
    private func checkServiceQueryCache(_ query: String) -> String? {
        let cacheKey = query.lowercased()
        if let cached = serviceQueryCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            return cached.result
        }
        return nil
    }
    
    private func cacheServiceQuery(_ query: String, result: String) {
        let cacheKey = query.lowercased()
        serviceQueryCache[cacheKey] = (result: result, timestamp: Date())
        
        // Limit cache size to prevent memory bloat
        if serviceQueryCache.count > 50 {
            let oldestKey = serviceQueryCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key
            if let key = oldestKey {
                serviceQueryCache.removeValue(forKey: key)
            }
        }
    }
}
