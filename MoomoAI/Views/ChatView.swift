//
//  ChatView.swift
//  MoomoAI
//
//  Main chat interface - matches web app chat UI exactly
//

import SwiftUI
import PhotosUI
import Speech
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showSidebar: Bool
    
    @State private var messageText = ""
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var attachments: [AttachmentItem] = []
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var showRegenerateOptions = false
    @State private var messageToRegenerate: ChatMessage?
    @State private var userPromptForRegeneration: String = ""
    @State private var showAIDataConsent = false
    @State private var pendingMessageAfterConsent: String?
    @State private var pendingAttachmentsAfterConsent: [AttachmentItem] = []
    @FocusState private var isInputFocused: Bool
    @FocusState private var isSearchFocused: Bool
    
    // Speech recognition
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages
            if let session = chatViewModel.currentSession {
                if session.isTemporary && session.messages.isEmpty {
                    // Gemini-style temporary chat welcome screen
                    temporaryChatWelcome
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isInputFocused {
                                isInputFocused = false
                            }
                        }
                } else if session.messages.isEmpty {
                    WelcomeView(onSuggestionTap: { suggestion in
                        handleWelcomeSuggestion(suggestion)
                    })
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard when tapping empty welcome area
                        if isInputFocused {
                            isInputFocused = false
                        }
                    }
                } else {
                    messagesScrollView(session: session)
                        .onTapGesture {
                            // Dismiss keyboard when tapping message area
                            if isInputFocused {
                                isInputFocused = false
                            }
                        }
                }
            }
            
            // Input Area
            inputArea
        }
        .background(K.Colors.backgroundPrimary)
        .navigationBarHidden(true)
        .sheet(isPresented: $showImagePicker) {
            if #available(iOS 16.0, *) {
                PhotoPickerView { items in
                    for item in items {
                        attachments.append(item)
                    }
                }
            } else {
                Text("Photo picker requires iOS 16+")
                    .padding()
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { item in
                attachments.append(item)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { item in
                attachments.append(item)
            }
        }
        .sheet(isPresented: $showRegenerateOptions) {
            if let message = messageToRegenerate {
                RegenerateOptionsView(
                    originalMessage: message,
                    userPrompt: userPromptForRegeneration,
                    onRegenerate: { temperature, editedPrompt in
                        handleRegenerateSubmit(
                            messageId: message.id,
                            temperature: temperature,
                            editedPrompt: editedPrompt
                        )
                    }
                )
            }
        }
        .overlay {
            if showAIDataConsent {
                AIDataConsentView(
                    isPresented: $showAIDataConsent,
                    onAccept: {
                        PersistenceService.shared.setAIDataSharingConsent(true)
                        // Re-send the pending message
                        if let pending = pendingMessageAfterConsent {
                            messageText = pending
                            attachments = pendingAttachmentsAfterConsent
                            pendingMessageAfterConsent = nil
                            pendingAttachmentsAfterConsent = []
                            sendMessage()
                        }
                    },
                    onDecline: {
                        pendingMessageAfterConsent = nil
                        pendingAttachmentsAfterConsent = []
                    }
                )
            }
        }
        .onChange(of: chatViewModel.currentSession?.id) { _ in
            // Dismiss keyboard when switching to a new session
            isInputFocused = false
            messageText = ""
            attachments.removeAll()
        }
        .onAppear {
            // Auto-focus the input field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Chat Header
    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { 
                    withAnimation { 
                        showSidebar.toggle()
                        // Dismiss keyboard when opening sidebar
                        if showSidebar && isInputFocused {
                            isInputFocused = false
                        }
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22))
                        .foregroundColor(K.Colors.textPrimary)
                        .padding(8)
                }
                
                Spacer()
                
                Text(chatViewModel.currentSession?.isTemporary == true ? "Temporary chat" : "Moomo AI Assistant")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(K.Colors.textPrimary)
                
                Spacer()
                
                // Temporary chat toggle
                Button(action: {
                    withAnimation {
                        if chatViewModel.currentSession?.isTemporary == true {
                            // Exit temporary mode — go back to last regular session or create new
                            if let lastRegular = chatViewModel.sessions.first {
                                chatViewModel.selectSession(lastRegular)
                            } else {
                                chatViewModel.createNewSession()
                            }
                        } else {
                            chatViewModel.createTemporarySession()
                        }
                        if isInputFocused { isInputFocused = false }
                    }
                }) {
                    Image(systemName: chatViewModel.currentSession?.isTemporary == true ? "viewfinder" : "viewfinder")
                        .font(.system(size: 20))
                        .foregroundColor(chatViewModel.currentSession?.isTemporary == true ? K.Colors.accentColor : K.Colors.textPrimary)
                        .padding(8)
                }
                
                // New Chat button (visible after first query)
                if let session = chatViewModel.currentSession, !session.messages.isEmpty {
                    Button(action: {
                        withAnimation {
                            chatViewModel.createNewSession()
                            // Dismiss keyboard when creating new chat
                            if isInputFocused {
                                isInputFocused = false
                            }
                            // Clear search if active
                            if showSearch {
                                showSearch = false
                                searchText = ""
                            }
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 22))
                            .foregroundColor(K.Colors.textPrimary)
                            .padding(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            
            // Search bar
            if showSearch {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(K.Colors.textSecondary)
                    
                    TextField("Search messages...", text: $searchText)
                        .foregroundColor(K.Colors.textPrimary)
                        .focused($isSearchFocused)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(K.Colors.textSecondary)
                        }
                    }
                }
                .padding(10)
                .background(K.Colors.backgroundSecondary)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(K.Colors.backgroundPrimary)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Temporary Chat Welcome (Gemini-style)
    private var temporaryChatWelcome: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                // Viewfinder icon in a circle
                ZStack {
                    Circle()
                        .fill(K.Colors.textSecondary.opacity(0.1))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "viewfinder")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(K.Colors.textSecondary)
                }
                
                // Title
                Text("Temporary chat")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(K.Colors.textPrimary)
                
                // Description
                Text("Temporary chats don't appear in Recent Chats and aren't used to train models or personalize your experience.")
                    .font(.system(size: 15))
                    .foregroundColor(K.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.Colors.backgroundPrimary)
    }
    
    // MARK: - Messages Scroll View (EXACT webapp layout)
    private func messagesScrollView(session: ChatSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                // PERFORMANCE: Use LazyVStack with proper ID for efficient rendering
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(filteredMessages(from: session), id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            onReact: { emoji in
                                handleReaction(messageId: message.id, emoji: emoji)
                            },
                            onDelete: {
                                handleDeleteMessage(messageId: message.id)
                            },
                            onRegenerate: {
                                handleRegenerate(message: message)
                            }
                        )
                        .id(message.id)
                        .transition(AnimationConstants.messageSlideIn)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .simultaneousGesture(
                // Dismiss keyboard when scrolling
                DragGesture().onChanged { _ in
                    if isInputFocused {
                        isInputFocused = false
                    }
                }
            )
            .onChange(of: session.messages.count) { _ in
                // PERFORMANCE: Debounce scroll animation to prevent jank
                if let lastMessage = session.messages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(AnimationConstants.springStandard) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func filteredMessages(from session: ChatSession) -> [ChatMessage] {
        guard !searchText.isEmpty else { return session.messages }
        return session.messages.filter { message in
            message.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            
            // Attachments preview - like web app
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(attachments) { attachment in
                            AttachmentPreviewCard(attachment: attachment) {
                                if let index = attachments.firstIndex(where: { $0.id == attachment.id }) {
                                    attachments.remove(at: index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(K.Colors.backgroundPrimary.opacity(0.5))
            }
            
            // Input Container - Text area on top, buttons at bottom
            VStack(spacing: 0) {
                // Text input area - ONE LINE
                ZStack(alignment: .leading) {
                    // Placeholder text
                    if messageText.isEmpty {
                        Text(chatViewModel.currentSession?.isTemporary == true ? "Ask in a temporary chat" : "Ask me anything...")
                            .font(.system(size: 17))
                            .foregroundColor(K.Colors.textSecondary.opacity(0.6))
                            .padding(.leading, 12)
                            .allowsHitTesting(false)
                    }
                    
                    if #available(iOS 16.0, *) {
                        TextField("", text: $messageText, axis: .vertical)
                            .font(.system(size: 17))
                            .foregroundColor(K.Colors.textPrimary)
                            .tint(K.Colors.accentColor)
                            .focused($isInputFocused)
                            .lineLimit(1...3)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .submitLabel(.send)
                            .onSubmit {
                                sendMessage()
                            }
                            .onTapGesture {
                                isInputFocused = true
                            }
                    } else {
                        TextField("", text: $messageText)
                            .font(.system(size: 17))
                            .foregroundColor(K.Colors.textPrimary)
                            .tint(K.Colors.accentColor)
                            .focused($isInputFocused)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .onSubmit {
                                sendMessage()
                            }
                            .onTapGesture {
                                isInputFocused = true
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = true
                }
                
                // Bottom row - All buttons
                HStack(alignment: .center, spacing: 12) {
                    // Plus button - directly open photo picker (like web app)
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(K.Colors.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Search toggle button
                    Button(action: {
                        withAnimation {
                            showSearch.toggle()
                            if showSearch {
                                // Dismiss input keyboard before showing search
                                isInputFocused = false
                                isSearchFocused = true
                            } else {
                                searchText = ""
                            }
                        }
                    }) {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "slider.horizontal.3")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(K.Colors.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Model selector
                    ModelSelectorView(selectedModel: $chatViewModel.selectedModel)
                    
                    // Mic button
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isRecording ? .red : K.Colors.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? K.Colors.textSecondary.opacity(0.3) : K.Colors.sendButton)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(K.Colors.inputBg)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isInputFocused ? K.Colors.accentColor : K.Colors.borderColor, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(K.Colors.backgroundPrimary)
    }
    
    // MARK: - Actions
    private func sendMessage() {
        print("🔵 sendMessage called with text: '\(messageText)'")
        guard !messageText.trimmed.isEmpty || !attachments.isEmpty else {
            print("❌ Message empty, not sending")
            return
        }
        
        // Check AI data sharing consent before first message
        if !PersistenceService.shared.hasAIDataSharingConsent() {
            pendingMessageAfterConsent = messageText.trimmed
            pendingAttachmentsAfterConsent = attachments
            showAIDataConsent = true
            return
        }
        
        var message = messageText.trimmed
        print("✅ Sending message: '\(message)'")
        
        // TODO: BACKEND INTEGRATION — attachment analytics removed in frontend-only reset.

        // For images, pass attachment data
        // Store attachments reference for the API call
        let messageAttachments = attachments
        
        // If only attachments without text, add a prompt
        if message.isEmpty && !attachments.isEmpty {
            message = "What can you tell me about this?"
        }
        
        // Clear inputs
        messageText = ""
        let localAttachments = messageAttachments
        attachments.removeAll()
        isInputFocused = false
        
        // Haptic feedback for sending
        HapticFeedback.light()
        
        Task {
            await chatViewModel.sendMessage(message, attachments: localAttachments)
        }
    }
    
    private func handleWelcomeSuggestion(_ suggestion: String) {
        // Send the tapped suggestion to the AI as a regular chat message
        messageText = suggestion
        sendMessage()
    }

    // MARK: - Message Actions
    
    private func handleReaction(messageId: String, emoji: String) {
        chatViewModel.toggleReaction(messageId: messageId, emoji: emoji)

        // Haptic feedback
        HapticFeedback.light()
    }
    
    private func handleDeleteMessage(messageId: String) {
        chatViewModel.deleteMessage(messageId: messageId)
    }
    
    private func handleRegenerate(message: ChatMessage) {
        // Find the user message that preceded this AI response
        if let session = chatViewModel.currentSession,
           let messageIndex = session.messages.firstIndex(where: { $0.id == message.id }),
           messageIndex > 0 {
            let previousMessage = session.messages[messageIndex - 1]
            userPromptForRegeneration = previousMessage.content
        }
        
        messageToRegenerate = message
        showRegenerateOptions = true
        
        // Haptic feedback
        HapticFeedback.light()
    }
    
    private func handleRegenerateSubmit(messageId: String, temperature: Double, editedPrompt: String) {
        // Dismiss sheet first
        showRegenerateOptions = false
        
        chatViewModel.regenerateMessage(
            messageId: messageId,
            temperature: temperature,
            editedPrompt: editedPrompt
        )

        // Reset state
        messageToRegenerate = nil
        userPromptForRegeneration = ""
    }
    
    // MARK: - Speech Recognition
    private func startRecording() {
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                guard authStatus == .authorized else {
                    print("Speech recognition not authorized")
                    return
                }
                
                do {
                    try startSpeechRecognition()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }
    
    private func startSpeechRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get the input node
        let inputNode = audioEngine.inputNode
        
        // Create and start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.messageText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
        
        // Configure the microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
    }
    
    private func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
}

// MARK: - Attachment Preview Card (Web App Style)
struct AttachmentPreviewCard: View {
    let attachment: AttachmentItem
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if attachment.type == .image, let thumbnail = attachment.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                } else if attachment.type == .pdf {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(K.Colors.backgroundSecondary)
                            .frame(width: 80, height: 80)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                            Text("PDF")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(K.Colors.textSecondary)
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(K.Colors.backgroundSecondary)
                            .frame(width: 80, height: 80)
                        
                        VStack(spacing: 4) {
                            Image(systemName: attachment.type.icon)
                                .font(.system(size: 24))
                                .foregroundColor(attachment.type.color)
                            Text(attachment.name.split(separator: ".").last?.uppercased() ?? "FILE")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(K.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(4)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(K.Colors.borderColor.opacity(0.3), lineWidth: 1)
            )
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 20, height: 20)
                    )
            }
            .offset(x: 6, y: -6)
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(showSidebar: .constant(false))
            .environmentObject(ChatViewModel())
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
