//
//  ChatViewModel.swift
//  MoomoAI
//
//  ViewModel for chat functionality. Sessions are persisted locally
//  (PersistenceService) and mirrored to Firestore (MemoryService); generation
//  runs through GenerationService (callable Cloud Functions + Gemini).
//

import Foundation
import SwiftUI

/// The authoritative UI mode for the current conversation. `isTemporary` wins
/// over message count — a fresh temporary chat is also empty, so deriving
/// state from `messages.isEmpty` alone can't tell the two apart.
enum ChatMode {
    case normalEmpty
    case normalActive
    case temporary

    static func forSession(_ session: ChatSession?) -> ChatMode {
        guard let session = session else { return .normalEmpty }
        if session.isTemporary { return .temporary }
        return session.messages.contains(where: { $0.role == .user }) ? .normalActive : .normalEmpty
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var currentSession: ChatSession?
    @Published var isSending = false   // True while any generation request is in flight (duplicate-send guard)
    @Published var selectedLanguage: Language = Language.defaultLanguage
    @Published var selectedModel: AIModel = .Q1 // Default to Q1

    private let persistence = PersistenceService.shared
    private let generation = GenerationService.shared

    /// uid the view model is currently operating for; drives auth transitions
    /// (including guest → different-account switches where isSignedIn never flips).
    private var currentUid: String?

    /// When each conversation was last hydrated from Firestore. Re-opening a chat
    /// within the TTL serves the local copy instead of refetching up to 80 docs.
    private var hydratedAt: [String: Date] = [:]
    private static let hydrationTTL: TimeInterval = 30

    /// Trailing-debounce task for server-side memory folding (one Gemini call each).
    private var memoryUpdateTask: Task<Void, Never>?

    /// Where the user was when they entered Temporary Chat, so exiting can land
    /// back on that chat if it's still an empty shell instead of stacking a new
    /// empty "New chat" row on every enter/exit cycle.
    private var sessionIdBeforeTemporary: String?

    /// Drives the top-right header action (Temporary Chat / Exit / New Chat).
    var chatMode: ChatMode {
        ChatMode.forSession(currentSession)
    }

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
        // Reuse the chat the user is already on if it's still empty — repeated
        // taps on "New chat" must not stack empty "New chat" rows in the sidebar.
        if let current = currentSession, !current.isTemporary, current.messages.isEmpty {
            return
        }
        let newSession = ChatSession(title: "New chat")
        sessions.insert(newSession, at: 0)
        currentSession = newSession
        persistence.saveSessions(sessions.filter { !$0.isTemporary })
        persistence.saveCurrentSessionId(newSession.id)
    }

    func createTemporarySession() {
        // Already in a temporary chat — repeated taps must not stack fresh ones.
        guard currentSession?.isTemporary != true else { return }
        sessionIdBeforeTemporary = currentSession?.id
        let tempSession = ChatSession(title: "Temporary chat", isTemporary: true)
        currentSession = tempSession
        // Temporary sessions are NOT added to sessions list or persisted
    }

    /// Leave Temporary Chat and land on a normal empty chat. The temporary
    /// session was never added to `sessions`, persisted, mirrored to the cloud,
    /// or folded into memory, so dropping the reference discards its messages
    /// and attachments entirely.
    func exitTemporarySession() {
        guard currentSession?.isTemporary == true else { return }

        // Land back on the chat the user came from while it's still an empty
        // shell; otherwise start a fresh normal chat.
        if let id = sessionIdBeforeTemporary,
           let previous = sessions.first(where: { $0.id == id }),
           !previous.isTemporary, previous.messages.isEmpty {
            currentSession = previous
            persistence.saveCurrentSessionId(previous.id)
        } else {
            currentSession = nil
            createNewSession()
        }
        sessionIdBeforeTemporary = nil
    }

    func selectSession(_ session: ChatSession) {
        currentSession = session
        persistence.saveCurrentSessionId(session.id)
        // Hydrate this conversation's messages from the cloud.
        Task { await loadCurrentConversationFromCloud() }
    }

    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        hydratedAt[session.id] = nil

        if currentSession?.id == session.id {
            currentSession = sessions.first
            if currentSession == nil {
                createNewSession()
            }
        }

        persistence.saveSessions(sessions)
        // Also delete server-side, or the chat resurrects at the next cloud sync.
        if !session.isTemporary {
            MemoryService.shared.deleteConversation(conversationId: session.id)
        }
    }

    func renameSession(_ session: ChatSession, newTitle: String) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].updateTitle(newTitle)
            if currentSession?.id == session.id {
                currentSession = sessions[index]
            }
            persistence.saveSessions(sessions)
            // Keep the cloud title in sync, or the rename is lost on re-login.
            if !session.isTemporary {
                MemoryService.shared.renameConversation(conversationId: session.id, title: newTitle)
            }
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

    func clearAllSessions() {
        sessions.removeAll()
        hydratedAt.removeAll()
        persistence.clearAllSessions()
        // Wipe the cloud copies too — "Clear All Chats" must not silently restore
        // everything at the next sign-in.
        MemoryService.shared.deleteAllConversations()
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

    /// Send a chat message — text-only, image-only, or text + attached images —
    /// as ONE multimodal request, so the model actually sees the pixels alongside
    /// the question. Returns false on failure so the composer can restore the
    /// draft and attachments instead of silently dropping them (the text is
    /// never silently re-sent without its images).
    @discardableResult
    func sendMessage(_ messageText: String, attachments: [AttachmentItem] = []) async -> Bool {
        guard !isSending else { return false }
        guard var session = currentSession else {
            return false
        }
        isSending = true
        defer { isSending = false }

        let conversationId = session.id
        let isTemp = session.isTemporary
        let imageAttachments = attachments.filter { $0.isSupportedImage }

        // Conversation history BEFORE this turn, for model context (last 20),
        // plus images from recent user turns so follow-ups like "what about the
        // second one?" keep their visual context.
        let history = recentHistory(from: session.messages)
        let historyImages = recentHistoryImages(from: session.messages)

        // Build the FULL request content before touching UI state: the user
        // bubble, its persisted thumbnail, and every inline image payload.
        let thumbnailData = imageAttachments.first?.thumbnailJPEGData(maxDimension: 300)
        var images = historyImages
        for attachment in imageAttachments {
            // Size-bounded JPEG re-encode (also normalizes orientation via
            // UIGraphicsImageRenderer). Fall back to the original bytes + real
            // MIME type if re-encoding fails; the backend validates both.
            if let jpeg = attachment.thumbnailJPEGData(maxDimension: 1024) {
                images.append(.init(data: jpeg, mimeType: "image/jpeg"))
            } else {
                images.append(.init(data: attachment.data, mimeType: attachment.mimeType))
            }
        }

        let userMessage = ChatMessage(role: .user, content: messageText, imageData: thumbnailData)
        session.addMessage(userMessage)
        updateSession(session)
        persistMessage(conversationId: conversationId, title: session.title, message: userMessage, attachment: imageAttachments.first, isTemporary: isTemp)

        // Show typing indicator
        let typingMessage = ChatMessage(role: .assistant, content: "", isTyping: true)
        session.addMessage(typingMessage)
        updateSession(session)

        do {
            // Include the user-memory summary only when memory is enabled.
            let memoryText = MemoryService.shared.isMemoryEnabled
                ? (await MemoryService.shared.loadMemory()?.contextText)
                : nil

            #if DEBUG
            print("CHAT_SEND attachments=\(imageAttachments.count) historyImages=\(historyImages.count) requestImages=\(images.count) textLen=\(messageText.count)")
            #endif

            // Real generation via shared service (Cloud Functions + Gemini). The
            // backend assembles the system instruction from language + memory and
            // places image parts and text in the same model request.
            let response = try await generation.generateText(
                message: messageText,
                history: history,
                memory: memoryText,
                language: selectedLanguage.name,
                languageCode: selectedLanguage.code,
                images: images
            )

            // Remove typing indicator and add response
            session.messages.removeLast()
            let assistantMessage = ChatMessage(role: .assistant, content: response.text ?? "")
            session.addMessage(assistantMessage)
            updateSession(session)
            persistMessage(conversationId: conversationId, title: session.title, message: assistantMessage, isTemporary: isTemp)
            scheduleMemoryUpdate(messages: session.messages, isTemporary: isTemp)
            return true

        } catch {
            handleGenerationError(error, session: &session, imagesAttached: !images.isEmpty)
            return false
        }

    }

    /// Regenerate an assistant reply IN PLACE. Re-sending the preceding prompt
    /// through sendMessage appended a second copy of the user bubble (and a
    /// second Firestore document) on every regenerate, and dropped any attached
    /// image because only the text was re-sent.
    func regenerateResponse(for assistantMessageId: String) async {
        guard !isSending else { return }
        guard var session = currentSession else { return }
        guard let assistantIndex = session.messages.firstIndex(where: { $0.id == assistantMessageId }),
              session.messages[assistantIndex].role == .assistant else { return }
        // The user turn this reply answers — its text AND its attached image.
        guard let userIndex = session.messages[..<assistantIndex].lastIndex(where: { $0.role == .user }) else { return }
        let userMessage = session.messages[userIndex]

        let userImage = userMessage.imageData ?? ImageCache.shared.thumbnailData(id: userMessage.id)
        guard !userMessage.content.trimmed.isEmpty || userImage != nil else { return }

        isSending = true
        defer { isSending = false }

        let conversationId = session.id
        let isTemp = session.isTemporary
        let history = recentHistory(from: Array(session.messages[..<userIndex]))

        // Swap the old reply for a typing indicator, in place.
        session.messages[assistantIndex] = ChatMessage(role: .assistant, content: "", isTyping: true)
        updateSession(session)

        do {
            let memoryText = MemoryService.shared.isMemoryEnabled
                ? (await MemoryService.shared.loadMemory()?.contextText)
                : nil

            var images: [GenerationService.InlineImage] = recentHistoryImages(from: Array(session.messages[..<userIndex]))
            if let userImage {
                images.append(.init(data: userImage, mimeType: "image/jpeg"))
            }

            let response = try await generation.generateText(
                message: userMessage.content,
                history: history,
                memory: memoryText,
                language: selectedLanguage.name,
                languageCode: selectedLanguage.code,
                images: images
            )

            // Keep the SAME message id so the Firestore copy is overwritten
            // instead of duplicated.
            let assistantMessage = ChatMessage(id: assistantMessageId, role: .assistant, content: response.text ?? "")
            session.messages[assistantIndex] = assistantMessage
            updateSession(session)
            persistMessage(conversationId: conversationId, title: session.title, message: assistantMessage, isTemporary: isTemp)
        } catch {
            // Put a friendly error where the typing indicator sits (same id, so
            // a later regenerate still targets one message).
            let text = friendlyErrorText(error)
            session.messages[assistantIndex] = ChatMessage(id: assistantMessageId, role: .assistant, content: text)
            updateSession(session)
        }
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
    ///
    /// Skipped while a send is in flight (the send's local copy and the cloud
    /// snapshot would clobber each other) and when the conversation was already
    /// hydrated within the last `hydrationTTL` seconds, so flipping between two
    /// chats doesn't refetch up to 80 documents each time.
    func loadCurrentConversationFromCloud() async {
        guard var session = currentSession, !session.isTemporary, !isSending else { return }
        if let at = hydratedAt[session.id], Date().timeIntervalSince(at) < Self.hydrationTTL { return }

        let cloud = await MemoryService.shared.loadMessages(conversationId: session.id)
        guard !cloud.isEmpty else { return }

        // Re-check after the await: a send that started meanwhile owns the session.
        guard !isSending else { return }
        hydratedAt[session.id] = Date()
        session.messages = cloud
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        // Only steer the UI if the user is still looking at this conversation.
        if currentSession?.id == session.id {
            currentSession = session
        }
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

    /// Reconcile chat state with the signed-in user. Keyed on the *uid*, not just
    /// "signed in", so it also catches guest → account switches where the uid
    /// changes while isSignedIn stays true (which previously bled the old
    /// account's local chats into the new one). Safe to call repeatedly — it
    /// no-ops unless the uid actually changed. Call it both on appear (the auth
    /// listener can restore the session before the root view is installed, so an
    /// onChange alone can miss the transition) and on every subsequent change.
    func handleAuthChange(uid: String?) {
        guard uid != currentUid else { return }
        let hadUser = currentUid != nil
        currentUid = uid

        if hadUser {
            // Sign-out or account switch: drop the previous user's state so the
            // next session never shows another account's chats.
            memoryUpdateTask?.cancel()
            sessions = []
            currentSession = nil
            hydratedAt.removeAll()
            persistence.clearAllSessions()
            persistence.clearCurrentSessionId()
            ImageCache.shared.clearThumbnails()
            createNewSession()
        }

        if uid != nil {
            Task {
                await syncConversationsFromCloud()
                if currentSession == nil { createNewSession() }
                await loadCurrentConversationFromCloud()
            }
        }
    }

    // MARK: - Memory + history helpers

    /// Recent messages mapped to `{role, text}`, oldest-first, capped at 20.
    private func recentHistory(from messages: [ChatMessage]) -> [[String: String]] {
        messages
            .filter { !$0.isTyping && !$0.content.isEmpty }
            .suffix(20)
            .map { ["role": $0.role == .user ? "user" : "assistant", "text": $0.content] }
    }

    /// Thumbnails of images the user attached in recent turns, oldest-first,
    /// capped at 2 — enough for follow-ups ("what about the second one?") to
    /// keep their visual context without inflating the request payload. Bytes
    /// come from the message itself or the on-disk thumbnail store (local
    /// persistence and cloud hydration both strip inline bytes).
    private func recentHistoryImages(from messages: [ChatMessage]) -> [GenerationService.InlineImage] {
        let images = messages
            .suffix(10)
            .filter { $0.role == .user }
            .compactMap { message -> GenerationService.InlineImage? in
                guard let data = message.imageData ?? ImageCache.shared.thumbnailData(id: message.id) else { return nil }
                return .init(data: data, mimeType: "image/jpeg")
            }
        return Array(images.suffix(2))
    }

    /// Persist one message to Firestore. Temporary chats are never stored.
    private func persistMessage(conversationId: String, title: String, message: ChatMessage, attachment: AttachmentItem? = nil, isTemporary: Bool) {
        guard !isTemporary else { return }
        MemoryService.shared.saveMessage(conversationId: conversationId, conversationTitle: title, message: message, attachment: attachment)
    }

    /// Fold recent conversation into the user-memory summary (server-side,
    /// best-effort). Debounced: each fold costs a full model call plus Firestore
    /// traffic on the backend, so instead of folding after every exchange we wait
    /// until the user pauses. The final history snapshot carries the last 20
    /// turns, so nothing from the burst is lost.
    private func scheduleMemoryUpdate(messages: [ChatMessage], isTemporary: Bool) {
        guard MemoryService.shared.isMemoryEnabled, !isTemporary, !MemoryService.shared.isGuest else { return }
        let history = recentHistory(from: messages)
        guard !history.isEmpty else { return }
        memoryUpdateTask?.cancel()
        memoryUpdateTask = Task { [generation] in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard !Task.isCancelled else { return }
            await generation.updateMemory(history: history)
            MemoryService.shared.invalidateMemoryCache()
        }
    }

    // MARK: - Error handling

    private func handleGenerationError(_ error: Error, session: inout ChatSession, imagesAttached: Bool = false) {
        #if DEBUG
        print("CHAT_ERROR \(error)")
        #endif
        // A failed image request is surfaced AS an image failure — the model is
        // never silently asked again without the pixels. sendMessage returns
        // false, so ChatView restores the draft and its attachments for retry.
        let reason = friendlyErrorText(error)
        let text = imagesAttached
            ? "I couldn't analyze the attached image. \(reason)\n\nYour message and image are back in the composer — tap send to retry."
            : reason

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
        // Temporary chats: update in-memory only, no persistence.
        if session.isTemporary {
            if currentSession?.id == session.id { currentSession = session }
            return
        }

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            // Only steer the UI when the user is still on this conversation — a
            // completion from a chat they navigated away from must not yank them
            // back (ChatView resets the composer whenever the session id changes,
            // so the clobber also wiped whatever they were typing).
            if currentSession?.id == session.id {
                currentSession = session
            }
            // Coalesced local persistence (saveSessions already runs off-main).
            persistence.scheduleSaveSessions(sessions)
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
        // Delete the cloud copy too, or hydration resurrects the message.
        if !session.isTemporary {
            MemoryService.shared.deleteMessage(conversationId: session.id, messageId: messageId)
        }
    }

    // MARK: - Language Selection

    func selectLanguage(_ language: Language) {
        selectedLanguage = language
        persistence.saveLanguage(language)
    }
}
