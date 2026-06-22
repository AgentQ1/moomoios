//
//  ChatViewModel.swift
//  MoomoAI
//
//  ViewModel for chat functionality (frontend-only shell).
//
//  TODO: BACKEND INTEGRATION — Firebase real-time sync and analytics were
//  removed during the frontend-only reset. Sessions are persisted locally only
//  (see PersistenceService), and AI responses come from MockAIService. Re-add
//  cloud sync / real generation when rebuilding the backend.
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

    private let persistence = PersistenceService.shared
    private let modelAPI = MockAIService.shared

    init() {
        loadSessions()
        selectedLanguage = persistence.loadLanguage()

        // Create new session if none exists
        if currentSession == nil {
            createNewSession()
        }
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

        // Add user message (with thumbnail if image attached)
        let thumbnailData: Data? = attachments.first(where: { $0.type == .image })?.thumbnailJPEGData(maxDimension: 300)
        let userMessage = ChatMessage(role: .user, content: messageText, imageData: thumbnailData)
        session.addMessage(userMessage)
        updateSession(session)

        // Show typing indicator
        isLoading = true
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)

        do {
            // Build system prompt with language
            let systemPrompt = buildSystemPrompt()

            // Limit conversation history to last 20 messages (performance optimization)
            let limitedMessages = Array(session.messages.dropLast().suffix(20))

            // Get a placeholder response from the local mock service.
            // TODO: BACKEND INTEGRATION — replace MockAIService with real generation.
            let response = try await modelAPI.sendMessage(
                model: selectedModel,
                messages: limitedMessages,
                systemPrompt: systemPrompt,
                attachments: attachments
            )

            // Remove typing indicator and add response
            session.messages.removeLast()
            let assistantMessage = ChatMessage(role: .assistant, content: response)
            session.addMessage(assistantMessage)
            updateSession(session)

        } catch {
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
        // Temporary chats: update in-memory only, no persistence
        if session.isTemporary {
            currentSession = session
            return
        }

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            currentSession = session

            // Persist locally in the background.
            Task.detached(priority: .utility) { [sessions] in
                PersistenceService.shared.saveSessions(sessions)
            }
        }
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

    // MARK: - Language Selection

    func selectLanguage(_ language: Language) {
        selectedLanguage = language
        persistence.saveLanguage(language)
    }
}
