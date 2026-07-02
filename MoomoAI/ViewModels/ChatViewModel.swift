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
    @Published var isSending = false   // True while any generation request is in flight (duplicate-send guard)
    @Published var selectedLanguage: Language = Language.defaultLanguage
    @Published var selectedModel: AIModel = .Q1 // Default to Q1
    @Published var errorMessage: String?

    private let persistence = PersistenceService.shared
    private let generation = GenerationService.shared

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
        // Hydrate this conversation's messages from the cloud.
        Task { await loadCurrentConversationFromCloud() }
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

    func sendMessage(_ messageText: String) async {
        guard !isSending else { return }
        guard var session = currentSession else {
            return
        }
        isSending = true
        defer { isSending = false }

        let conversationId = session.id
        let isTemp = session.isTemporary

        // Conversation history BEFORE this turn, for model context (last 20).
        let history = recentHistory(from: session.messages)

        let userMessage = ChatMessage(role: .user, content: messageText)
        session.addMessage(userMessage)
        updateSession(session)
        persistMessage(conversationId: conversationId, title: session.title, message: userMessage, isTemporary: isTemp)

        // Show typing indicator
        isLoading = true
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)

        do {
            // Include the user-memory summary only when memory is enabled.
            let memoryText = MemoryService.shared.isMemoryEnabled
                ? (await MemoryService.shared.loadMemory()?.contextText)
                : nil

            // Real generation via shared service (Cloud Functions + Gemini). The
            // backend assembles the system instruction from language + memory.
            let response = try await generation.generateText(
                message: messageText,
                history: history,
                memory: memoryText,
                language: selectedLanguage.name,
                languageCode: selectedLanguage.code
            )

            // Remove typing indicator and add response
            session.messages.removeLast()
            let assistantMessage = ChatMessage(role: .assistant, content: response.text ?? "")
            session.addMessage(assistantMessage)
            updateSession(session)
            persistMessage(conversationId: conversationId, title: session.title, message: assistantMessage, isTemporary: isTemp)
            scheduleMemoryUpdate(messages: session.messages, isTemporary: isTemp)

        } catch {
            handleGenerationError(error, session: &session)
        }

        isLoading = false
    }

    /// Generate an image from a prompt, inline in the current chat conversation.
    /// Uses the existing `generateImage` Cloud Function via GenerationService.
    func sendImagePrompt(_ promptText: String) async {
        guard !isSending else { return }
        guard var session = currentSession else {
            return
        }
        isSending = true
        defer { isSending = false }

        let conversationId = session.id
        let isTemp = session.isTemporary

        // Add the user's request as a normal user bubble.
        let userMessage = ChatMessage(role: .user, content: promptText)
        session.addMessage(userMessage)
        updateSession(session)
        persistMessage(conversationId: conversationId, title: session.title, message: userMessage, isTemporary: isTemp)

        // Show typing indicator while the image is generated.
        isLoading = true
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)

        do {
            let result = try await generation.generateImage(promptText)

            // Remove typing indicator and add the image result as an assistant bubble.
            // The image keeps the originating prompt (caption) + Storage path so it
            // can be previewed, re-edited, and indexed in the Library.
            session.messages.removeLast()
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: result.text ?? "",
                imageURL: result.url,
                imagePath: result.path,
                prompt: promptText,
                model: selectedModel.rawValue
            )
            session.addMessage(assistantMessage)
            updateSession(session)
            persistMessage(conversationId: conversationId, title: session.title, message: assistantMessage, isTemporary: isTemp)
            logImageAsset(assistantMessage, type: .generatedImage, prompt: promptText, conversation: session, isTemporary: isTemp)

        } catch {
            handleGenerationError(error, session: &session)
        }

        isLoading = false
    }

    /// Edit a previously generated image (follow-up like "make it darker") using
    /// its Storage path, so the change refers to the right image in this thread.
    func sendImageEdit(prompt promptText: String, targetPath: String, sourceCaption: String?) async {
        guard !isSending else { return }
        guard var session = currentSession else { return }
        isSending = true
        defer { isSending = false }

        let conversationId = session.id
        let isTemp = session.isTemporary

        let userMessage = ChatMessage(role: .user, content: promptText)
        session.addMessage(userMessage)
        updateSession(session)
        persistMessage(conversationId: conversationId, title: session.title, message: userMessage, isTemporary: isTemp)

        isLoading = true
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)

        do {
            let result = try await generation.editImage(path: targetPath, instruction: promptText)
            session.messages.removeLast()
            // Caption carries forward the edit lineage so the image stays self-describing.
            let caption = sourceCaption.map { "\($0) · \(promptText)" } ?? promptText
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: result.text ?? "",
                imageURL: result.url,
                imagePath: result.path,
                prompt: caption,
                model: selectedModel.rawValue
            )
            session.addMessage(assistantMessage)
            updateSession(session)
            persistMessage(conversationId: conversationId, title: session.title, message: assistantMessage, isTemporary: isTemp)
            logImageAsset(assistantMessage, type: .editedImage, prompt: caption, conversation: session, isTemporary: isTemp)
        } catch {
            handleGenerationError(error, session: &session)
        }

        isLoading = false
    }

    /// Edit an attached/photo image using a text instruction, inline in chat.
    /// Routes through the existing `editGeneratedImage` Cloud Function (NOT generateImage),
    /// sending the attached image bytes alongside the prompt.
    func sendImageEdit(prompt promptText: String, attachment: AttachmentItem) async {
        guard !isSending else { return }
        guard var session = currentSession else {
            return
        }
        isSending = true
        defer { isSending = false }

        let conversationId = session.id
        let isTemp = session.isTemporary

        // User bubble shows the attached image thumbnail + the instruction.
        let thumbnailData = attachment.thumbnailJPEGData(maxDimension: 300)
        let userMessage = ChatMessage(role: .user, content: promptText, imageData: thumbnailData)
        session.addMessage(userMessage)
        updateSession(session)
        persistMessage(conversationId: conversationId, title: session.title, message: userMessage, attachment: attachment, isTemporary: isTemp)

        // Typing indicator while the edit runs.
        isLoading = true
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)

        do {
            // Send a size-bounded JPEG of the attached image so the callable payload stays small.
            let payload = attachment.thumbnailJPEGData(maxDimension: 1024) ?? attachment.data
            let result = try await generation.editImage(imageData: payload, mimeType: "image/jpeg", instruction: promptText)

            session.messages.removeLast()
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: result.text ?? "",
                imageURL: result.url,
                imagePath: result.path,
                prompt: promptText,
                model: selectedModel.rawValue
            )
            session.addMessage(assistantMessage)
            updateSession(session)
            persistMessage(conversationId: conversationId, title: session.title, message: assistantMessage, isTemporary: isTemp)
            logImageAsset(assistantMessage, type: .editedImage, prompt: promptText, conversation: session, isTemporary: isTemp)

        } catch {
            handleGenerationError(error, session: &session)
        }

        isLoading = false
    }

    /// Ask a question about an attached document. Text is extracted on-device by
    /// DocumentProcessor and included alongside the question so the model can
    /// answer; the file itself is never uploaded. The document is indexed in the
    /// Library and the user can keep asking follow-up questions in this thread.
    func sendDocumentPrompt(question: String, document: ExtractedDocument, attachment: AttachmentItem) async {
        guard !isSending else { return }
        guard var session = currentSession else { return }
        isSending = true
        defer { isSending = false }

        let conversationId = session.id
        let isTemp = session.isTemporary
        let trimmedQuestion = question.isEmpty ? "Summarize this document." : question

        // User bubble shows the document chip + the question.
        let userMessage = ChatMessage(
            role: .user,
            content: trimmedQuestion,
            attachmentName: attachment.name,
            attachmentMime: attachment.mimeType
        )
        session.addMessage(userMessage)
        updateSession(session)
        persistMessage(conversationId: conversationId, title: session.title, message: userMessage, attachment: attachment, isTemporary: isTemp)
        logFileAsset(messageId: userMessage.id, attachment: attachment, prompt: trimmedQuestion, conversation: session, isTemporary: isTemp)

        isLoading = true
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)

        do {
            let history = recentHistory(from: session.messages)
            let memoryText = MemoryService.shared.isMemoryEnabled
                ? (await MemoryService.shared.loadMemory()?.contextText)
                : nil

            // Compose a single message that gives the model the document context.
            var composed = "The user attached a document named \"\(attachment.name)\"."
            if document.truncated { composed += " (Showing the first part of a longer document.)" }
            composed += "\n\n--- DOCUMENT CONTENT ---\n\(document.text)\n--- END DOCUMENT ---\n\nUser question: \(trimmedQuestion)"

            let response = try await generation.generateText(
                message: composed,
                history: history,
                memory: memoryText,
                language: selectedLanguage.name,
                languageCode: selectedLanguage.code
            )

            session.messages.removeLast()
            let assistantMessage = ChatMessage(role: .assistant, content: response.text ?? "", model: selectedModel.rawValue)
            session.addMessage(assistantMessage)
            updateSession(session)
            persistMessage(conversationId: conversationId, title: session.title, message: assistantMessage, isTemporary: isTemp)
            scheduleMemoryUpdate(messages: session.messages, isTemporary: isTemp)
        } catch {
            handleGenerationError(error, session: &session)
        }

        isLoading = false
    }

    // MARK: - Asset logging

    /// Record a generated/edited image in the Library index (best-effort).
    private func logImageAsset(_ message: ChatMessage, type: AssetType, prompt: String, conversation: ChatSession, isTemporary: Bool) {
        guard !isTemporary, let url = message.imageURL else { return }
        AssetLibraryService.shared.saveAsset(LibraryAsset(
            type: type,
            url: url,
            path: message.imagePath,
            prompt: prompt,
            chatId: conversation.id,
            chatTitle: conversation.title,
            messageId: message.id,
            model: message.model
        ))
    }

    /// Record an uploaded file in the Library index (metadata only — no binary).
    private func logFileAsset(messageId: String, attachment: AttachmentItem, prompt: String, conversation: ChatSession, isTemporary: Bool) {
        guard !isTemporary else { return }
        AssetLibraryService.shared.saveAsset(LibraryAsset(
            type: .uploadedFile,
            prompt: prompt,
            chatId: conversation.id,
            chatTitle: conversation.title,
            messageId: messageId,
            mimeType: attachment.mimeType,
            name: attachment.name
        ))
    }

    // MARK: - Cloud sync

    /// Load the current conversation's messages from Firestore (on app open / when
    /// switching conversations). Cloud wins when it has data; an empty result
    /// (offline or brand-new chat) leaves the local copy untouched.
    func loadCurrentConversationFromCloud() async {
        guard var session = currentSession, !session.isTemporary else { return }
        let cloud = await MemoryService.shared.loadMessages(conversationId: session.id)
        guard !cloud.isEmpty else { return }
        session.messages = cloud
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        currentSession = session
    }

    /// Merge the cloud conversation list into local sessions so chats reappear
    /// after logging in (including on a fresh device). Local sessions are kept;
    /// cloud-only conversations are added as metadata and hydrated lazily on open.
    func syncConversationsFromCloud() async {
        let cloud = await MemoryService.shared.loadConversations()
        guard !cloud.isEmpty else { return }
        let existingIds = Set(sessions.map { $0.id })
        var merged = sessions
        for convo in cloud where !existingIds.contains(convo.id) {
            merged.append(convo)
        }
        sessions = merged.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
        persistence.saveSessions(sessions.filter { !$0.isTemporary })
    }

    // MARK: - Auth lifecycle

    /// Called when a user signs in. Hydrates their chat list from the cloud.
    func handleSignIn() {
        Task {
            await syncConversationsFromCloud()
            if currentSession == nil { createNewSession() }
        }
    }

    /// Called on sign-out. Clears the previous user's in-memory + local state so
    /// the next session never restores stale chats from another account.
    func handleSignOut() {
        sessions = []
        currentSession = nil
        persistence.clearAllSessions()
        persistence.clearCurrentSessionId()
        createNewSession()
    }

    // MARK: - Memory + history helpers

    /// Recent messages mapped to `{role, text}`, oldest-first, capped at 20.
    private func recentHistory(from messages: [ChatMessage]) -> [[String: String]] {
        messages
            .filter { !$0.isTyping && !$0.content.isEmpty }
            .suffix(20)
            .map { ["role": $0.role == .user ? "user" : "assistant", "text": $0.content] }
    }

    /// Persist one message to Firestore. Temporary chats are never stored.
    private func persistMessage(conversationId: String, title: String, message: ChatMessage, attachment: AttachmentItem? = nil, isTemporary: Bool) {
        guard !isTemporary else { return }
        MemoryService.shared.saveMessage(conversationId: conversationId, conversationTitle: title, message: message, attachment: attachment)
    }

    /// Fold the latest exchange into the user-memory summary (server-side, best-effort).
    private func scheduleMemoryUpdate(messages: [ChatMessage], isTemporary: Bool) {
        guard MemoryService.shared.isMemoryEnabled, !isTemporary, !MemoryService.shared.isGuest else { return }
        let history = recentHistory(from: messages)
        guard !history.isEmpty else { return }
        Task { await generation.updateMemory(history: history) }
    }

    // MARK: - Error handling

    private func handleGenerationError(_ error: Error, session: inout ChatSession) {
        #if DEBUG
        print("CHAT_ERROR \(error)")
        #endif
        let text = friendlyErrorText(error)
        errorMessage = text

        if session.messages.last?.isTyping == true {
            session.messages.removeLast()
        }
        session.addMessage(ChatMessage(role: .assistant, content: text))
        updateSession(session)
    }

    private func friendlyErrorText(_ error: Error) -> String {
        if let genError = error as? GenerationService.GenerationError {
            return genError.errorDescription ?? "Something went wrong. Please try again."
        }
        return "Something went wrong. Please try again."
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
