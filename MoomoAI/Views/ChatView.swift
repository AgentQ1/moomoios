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
    @EnvironmentObject var authService: AuthService
    @Binding var showSidebar: Bool
    
    @State private var messageText = ""
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var attachments: [AttachmentItem] = []
    @State private var imageMode = false   // When true, the composer creates an image instead of chatting
    @State private var editingImage: EditingImageTarget?  // Non-nil while editing a previously generated image
    @State private var showCameraDeniedAlert = false
    @State private var cameraAlertMessage = ""
    @State private var showUnsupportedFileAlert = false
    @State private var unsupportedFileMessage = "This file type is not supported yet."
    @State private var isProcessingDocument = false
    @FocusState private var isInputFocused: Bool
    
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
                    WelcomeView()
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
        .background(LuxuryBackground())
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
        .alert("Camera Unavailable", isPresented: $showCameraDeniedAlert) {
            Button("OK", role: .cancel) { }
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(url) }
            }
        } message: {
            Text(cameraAlertMessage)
        }
        .alert("Can’t use this file", isPresented: $showUnsupportedFileAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(unsupportedFileMessage)
        }
        .onChange(of: chatViewModel.currentSession?.id) { _ in
            // Dismiss keyboard when switching to a new session
            isInputFocused = false
            messageText = ""
            attachments.removeAll()
            imageMode = false
            editingImage = nil
        }
        .onAppear {
            // Auto-focus the input field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
            // Load the current conversation's history from the cloud on open.
            Task { await chatViewModel.loadCurrentConversationFromCloud() }
        }
    }
    
    /// True while the current conversation has no messages yet — the empty
    /// "home" state that shows the full Moomo brand cluster in the header.
    private var isHomeState: Bool {
        chatViewModel.currentSession?.messages.isEmpty ?? true
    }

    // MARK: - Chat Header
    private var chatHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            // Hamburger — opens the navigation drawer.
            Button(action: {
                withAnimation {
                    showSidebar.toggle()
                    if showSidebar && isInputFocused {
                        isInputFocused = false
                    }
                }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(K.Colors.ink.opacity(0.85))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            // Center: full Moomo brand on the empty home, "LAB AI" once chatting.
            if isHomeState {
                MoomoBrandHeader()
            } else {
                LabAIHeader()
            }

            Spacer(minLength: 8)

            // Top-right sparkle button — starts a fresh chat.
            SparkleCircleButton {
                withAnimation {
                    chatViewModel.createNewSession()
                    if isInputFocused { isInputFocused = false }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
    
    // MARK: - Temporary Chat Welcome (Gemini-style)
    private var temporaryChatWelcome: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                // Viewfinder icon in a circle
                ZStack {
                    Circle()
                        .fill(K.Colors.gold.opacity(0.12))
                        .frame(width: 64, height: 64)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(K.Colors.gold)
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
                    ForEach(session.messages, id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            onReact: { emoji in
                                handleReaction(messageId: message.id, emoji: emoji)
                            },
                            onDelete: {
                                handleDeleteMessage(messageId: message.id)
                            },
                            onEditImage: { msg in
                                startEditingImage(msg)
                            },
                            onRegenerate: {
                                regenerate(after: message, in: session)
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
    
    // MARK: - Input Area (clean ChatGPT/Gemini-style composer)
    private var inputArea: some View {
        VStack(spacing: 0) {

            // "Editing image" context chip — follow-up prompts target this image.
            if let editing = editingImage {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(K.Colors.accentColor)
                    Text(editing.caption.map { "Editing: \($0)" } ?? "Editing image")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(K.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { withAnimation { editingImage = nil } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(K.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(K.Colors.accentColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Compact attachment preview (small thumbnail + remove button).
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { attachment in
                            AttachmentPreviewCard(attachment: attachment) {
                                if let index = attachments.firstIndex(where: { $0.id == attachment.id }) {
                                    attachments.remove(at: index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }

            // Input container — large rounded white card: text on top, controls below.
            VStack(alignment: .leading, spacing: 16) {
                // Text row. A small magic-wand icon appears (state only, no label)
                // when Create-image mode is active; tap it to leave image mode.
                HStack(alignment: .center, spacing: 10) {
                    if imageMode {
                        Button(action: { withAnimation { imageMode = false } }) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(K.Colors.gold)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.scale.combined(with: .opacity))
                    }

                    ZStack(alignment: .leading) {
                        if messageText.isEmpty {
                            Text(composerPlaceholder)
                                .font(.system(size: 18))
                                .foregroundColor(K.Colors.textSecondary)
                                .allowsHitTesting(false)
                        }

                        if #available(iOS 16.0, *) {
                            TextField("", text: $messageText, axis: .vertical)
                                .font(.system(size: 18))
                                .foregroundColor(K.Colors.ink)
                                .tint(K.Colors.navy)
                                .focused($isInputFocused)
                                .lineLimit(1...4)
                                .frame(minHeight: 28)
                                .submitLabel(.send)
                                .onSubmit { sendMessage() }
                        } else {
                            TextField("", text: $messageText)
                                .font(.system(size: 18))
                                .foregroundColor(K.Colors.ink)
                                .tint(K.Colors.navy)
                                .focused($isInputFocused)
                                .frame(height: 28)
                                .onSubmit { sendMessage() }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { isInputFocused = true }

                // Bottom controls: Plus • Image • Mic on the left, Send on the right.
                HStack(alignment: .center, spacing: 22) {
                    // Plus / attachment menu (Photo Library, Camera, Files, Create image).
                    Menu {
                        Button(action: { showImagePicker = true }) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        Button(action: { openCamera() }) {
                            Label("Camera", systemImage: "camera")
                        }
                        Button(action: { showDocumentPicker = true }) {
                            Label("Files", systemImage: "doc")
                        }
                        Divider()
                        Button(action: {
                            withAnimation { imageMode = true }
                            isInputFocused = true
                        }) {
                            Label("Create image", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(K.Colors.gold)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Image — jump straight to the photo library.
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "photo")
                            .font(.system(size: 21, weight: .regular))
                            .foregroundColor(K.Colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Mic — dictation.
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic")
                            .font(.system(size: 21, weight: .regular))
                            .foregroundColor(isRecording ? .red : K.Colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Send button — navy circle, enabled when there is text OR an attachment.
                    Button(action: sendMessage) {
                        Group {
                            if chatViewModel.isSending || isProcessingDocument {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(K.Colors.navy))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: K.Layout.composerCornerRadius, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: K.Layout.composerCornerRadius, style: .continuous)
                    .stroke(composerBorderColor, lineWidth: imageMode ? 1.5 : 1)
            )
            .shadow(color: K.Colors.navy.opacity(0.06), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: imageMode)
    }

    /// Composer keeps a soft gold hairline, deepening to gold on focus and navy in
    /// Create-image mode.
    private var composerBorderColor: Color {
        if imageMode { return K.Colors.navy }
        return isInputFocused ? K.Colors.gold : K.Colors.goldSoft.opacity(0.7)
    }
    
    // MARK: - Composer Placeholder
    private var composerPlaceholder: String {
        if editingImage != nil { return "Describe your change…" }
        if imageMode { return "Describe an image..." }
        if attachments.contains(where: { !$0.isSupportedImage }) { return "Ask about this document…" }
        return chatViewModel.currentSession?.isTemporary == true ? "Ask in a temporary chat" : "Ask anything..."
    }

    // MARK: - Send Button State
    private var canSend: Bool {
        guard !chatViewModel.isSending, !isProcessingDocument else { return false }
        if editingImage != nil { return !messageText.trimmed.isEmpty }
        return !messageText.trimmed.isEmpty || !attachments.isEmpty
    }

    private func clearComposer() {
        messageText = ""
        attachments.removeAll()
        imageMode = false
        editingImage = nil
        isInputFocused = false
    }

    /// Enter "edit this image" mode for a previously generated image.
    private func startEditingImage(_ message: ChatMessage) {
        guard let path = message.imagePath, !path.isEmpty else { return }
        withAnimation {
            editingImage = EditingImageTarget(path: path, caption: message.prompt)
            imageMode = false
            attachments.removeAll()
        }
        HapticFeedback.light()
        isInputFocused = true
    }

    // MARK: - Actions
    private func sendMessage() {
        // Duplicate-send guard: ignore repeated taps while a request is in flight.
        guard !chatViewModel.isSending, !isProcessingDocument else {
            #if DEBUG
            print("CHAT_SEND blocked duplicate request")
            #endif
            return
        }

        let prompt = messageText.trimmed

        // (0) Editing a previously generated image -> edit by Storage path.
        if let target = editingImage {
            guard !prompt.isEmpty else { return }
            let caption = target.caption
            let path = target.path
            clearComposer()
            HapticFeedback.light()
            Task { await chatViewModel.sendImageEdit(prompt: prompt, targetPath: path, sourceCaption: caption) }
            return
        }

        // (1) An attached image (Photo Library / Camera / Files) + prompt always
        // uses the image-EDIT flow — never generateImage.
        if let imageAttachment = attachments.first(where: { $0.type == .image }) {
            let instruction = prompt.isEmpty ? "Edit this image" : prompt
            clearComposer()
            HapticFeedback.light()
            Task { await chatViewModel.sendImageEdit(prompt: instruction, attachment: imageAttachment) }
            return
        }

        // (2) An attached document (PDF / txt / doc) -> extract text and ask about it.
        if let document = attachments.first(where: { !$0.isSupportedImage }) {
            handleDocumentSend(document, question: prompt)
            return
        }

        // (3) Create-image mode with no attached input image -> text-to-image.
        if imageMode {
            guard !prompt.isEmpty else { return }
            clearComposer()
            HapticFeedback.light()
            Task { await chatViewModel.sendImagePrompt(prompt) }
            return
        }

        // (4) Plain text -> normal chat with conversation history + memory.
        guard !prompt.isEmpty else { return }
        clearComposer()
        HapticFeedback.light()
        Task { await chatViewModel.sendMessage(prompt) }
    }

    /// Extract text from an attached document off the main thread, then ask the AI
    /// about it. Genuinely unsupported / unreadable files surface a clear error —
    /// they are never silently dropped.
    private func handleDocumentSend(_ document: AttachmentItem, question: String) {
        guard DocumentProcessor.isSupported(fileName: document.name, mimeType: document.mimeType) else {
            #if DEBUG
            print("CHAT_SEND unsupportedFile name=\(document.name) mimeType=\(document.mimeType)")
            #endif
            attachments.removeAll { $0.id == document.id }
            unsupportedFileMessage = "“\(document.name)” isn’t a supported document type yet. Try a PDF or text file."
            showUnsupportedFileAlert = true
            return
        }

        let data = document.data
        let name = document.name
        let mime = document.mimeType
        clearComposer()
        HapticFeedback.light()
        isProcessingDocument = true

        Task { @MainActor in
            do {
                // Extraction is CPU work — run it off the main thread.
                let extracted = try await Task.detached(priority: .userInitiated) {
                    try DocumentProcessor.extractText(from: data, fileName: name, mimeType: mime)
                }.value
                isProcessingDocument = false
                await chatViewModel.sendDocumentPrompt(question: question, document: extracted, attachment: document)
            } catch {
                isProcessingDocument = false
                unsupportedFileMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn’t read this document."
                showUnsupportedFileAlert = true
            }
        }
    }

    // MARK: - Camera permission
    /// Open the camera, handling the unavailable / denied cases with a friendly alert
    /// instead of presenting a black screen.
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraAlertMessage = "The camera isn't available on this device."
            showCameraDeniedAlert = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        cameraAlertMessage = "Camera access is off. Enable it in Settings to take photos."
                        showCameraDeniedAlert = true
                    }
                }
            }
        default:
            cameraAlertMessage = "Camera access is off. Enable it in Settings to take photos."
            showCameraDeniedAlert = true
        }
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

    /// Regenerate an assistant reply by re-sending the user prompt that preceded it.
    private func regenerate(after assistantMessage: ChatMessage, in session: ChatSession) {
        guard !chatViewModel.isSending, !isProcessingDocument else { return }
        guard let idx = session.messages.firstIndex(where: { $0.id == assistantMessage.id }) else { return }
        let precedingPrompt = session.messages[..<idx]
            .last(where: { $0.role == .user && !$0.content.trimmed.isEmpty })?
            .content.trimmed
        guard let prompt = precedingPrompt, !prompt.isEmpty else { return }
        HapticFeedback.light()
        Task { await chatViewModel.sendMessage(prompt) }
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

// MARK: - Editing Image Target

/// Identifies a previously generated image the composer is currently editing, so
/// follow-up prompts ("make it darker") apply to the right image in this thread.
struct EditingImageTarget: Identifiable {
    let id = UUID()
    let path: String
    let caption: String?
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
                        .frame(width: 56, height: 56)
                        .clipped()
                        .cornerRadius(8)
                } else if attachment.type == .pdf {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(K.Colors.backgroundSecondary)
                            .frame(width: 56, height: 56)
                        
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
                            .frame(width: 56, height: 56)
                        
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
            .environmentObject(AuthService())
            .preferredColorScheme(.light)
    }
}
