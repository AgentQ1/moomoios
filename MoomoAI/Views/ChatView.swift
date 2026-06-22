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
    @State private var showCameraDeniedAlert = false
    @State private var cameraAlertMessage = ""
    @State private var showUnsupportedFileAlert = false
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
        .alert("Camera Unavailable", isPresented: $showCameraDeniedAlert) {
            Button("OK", role: .cancel) { }
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(url) }
            }
        } message: {
            Text(cameraAlertMessage)
        }
        .alert("Unsupported File", isPresented: $showUnsupportedFileAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This file type is not supported yet.")
        }
        .onChange(of: chatViewModel.currentSession?.id) { _ in
            // Dismiss keyboard when switching to a new session
            isInputFocused = false
            messageText = ""
            attachments.removeAll()
            imageMode = false
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
                    ForEach(session.messages, id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            onReact: { emoji in
                                handleReaction(messageId: message.id, emoji: emoji)
                            },
                            onDelete: {
                                handleDeleteMessage(messageId: message.id)
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

            // Input container — text on top, controls below.
            VStack(spacing: 0) {
                // Text row. A small magic-wand icon appears (state only, no label)
                // when Create-image mode is active; tap it to leave image mode.
                HStack(alignment: .center, spacing: 8) {
                    if imageMode {
                        Button(action: { withAnimation { imageMode = false } }) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(K.Colors.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.leading, 12)
                        .transition(.scale.combined(with: .opacity))
                    }

                    ZStack(alignment: .leading) {
                        if messageText.isEmpty {
                            Text(composerPlaceholder)
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
                                .onSubmit { sendMessage() }
                        } else {
                            TextField("", text: $messageText)
                                .font(.system(size: 17))
                                .foregroundColor(K.Colors.textPrimary)
                                .tint(K.Colors.accentColor)
                                .focused($isInputFocused)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .onSubmit { sendMessage() }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { isInputFocused = true }

                // Bottom controls: Plus menu • Spacer • Mic • Send.
                HStack(alignment: .center, spacing: 12) {
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
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(K.Colors.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

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

                    // Send button — enabled when there is text OR an attachment, and no request is in flight.
                    Button(action: sendMessage) {
                        Group {
                            if chatViewModel.isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(canSend ? K.Colors.sendButton : K.Colors.textSecondary.opacity(0.3))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSend)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(K.Colors.inputBg)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(composerBorderColor, lineWidth: imageMode ? 2 : 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(K.Colors.backgroundPrimary)
        .animation(.easeInOut(duration: 0.2), value: imageMode)
    }

    /// Composer border turns purple in Create-image mode, or while focused.
    private var composerBorderColor: Color {
        if imageMode { return K.Colors.accentColor }
        return isInputFocused ? K.Colors.accentColor : K.Colors.borderColor
    }
    
    // MARK: - Composer Placeholder
    private var composerPlaceholder: String {
        if imageMode {
            return "Describe an image..."
        }
        return chatViewModel.currentSession?.isTemporary == true ? "Ask in a temporary chat" : "Ask anything..."
    }

    // MARK: - Send Button State
    private var canSend: Bool {
        guard !chatViewModel.isSending else { return false }
        return !messageText.trimmed.isEmpty || !attachments.isEmpty
    }

    private func clearComposer() {
        messageText = ""
        attachments.removeAll()
        imageMode = false
        isInputFocused = false
    }

    // MARK: - Actions
    private func sendMessage() {
        // Duplicate-send guard: ignore repeated taps while a request is in flight.
        guard !chatViewModel.isSending else {
            #if DEBUG
            print("CHAT_SEND blocked duplicate request")
            #endif
            return
        }

        let prompt = messageText.trimmed

        // Files flow: only image files are supported right now. A non-image
        // attachment (PDF/doc/etc.) shows a friendly message instead of being
        // silently dropped or misrouted into the image-edit flow.
        if let unsupported = attachments.first(where: { !$0.isSupportedImage }) {
            #if DEBUG
            print("CHAT_SEND unsupportedFile name=\(unsupported.name) mimeType=\(unsupported.mimeType) source=\(unsupported.source.rawValue)")
            #endif
            attachments.removeAll { $0.id == unsupported.id }
            showUnsupportedFileAlert = true
            return
        }

        // (3) An attached image (Photo Library / Camera / Files) + prompt always
        // uses the image-EDIT flow — never generateImage.
        if let imageAttachment = attachments.first(where: { $0.type == .image }) {
            let instruction = prompt.isEmpty ? "Edit this image" : prompt
            #if DEBUG
            print("CHAT_SEND editImage name=\(imageAttachment.name) mimeType=\(imageAttachment.mimeType) source=\(imageAttachment.source.rawValue)")
            #endif
            clearComposer()
            HapticFeedback.light()
            Task {
                await chatViewModel.sendImageEdit(prompt: instruction, attachment: imageAttachment)
            }
            return
        }

        // (2) Create-image mode with no attached input image -> text-to-image.
        if imageMode {
            guard !prompt.isEmpty else { return }
            #if DEBUG
            print("CHAT_SEND createImage")
            #endif
            clearComposer()
            HapticFeedback.light()
            Task {
                await chatViewModel.sendImagePrompt(prompt)
            }
            return
        }

        // (1) Plain text -> normal chat with conversation history + memory.
        guard !prompt.isEmpty else {
            #if DEBUG
            print("CHAT_SEND empty")
            #endif
            return
        }
        #if DEBUG
        print("CHAT_SEND textOnly")
        #endif
        clearComposer()
        HapticFeedback.light()
        Task {
            await chatViewModel.sendMessage(prompt)
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
            .preferredColorScheme(.dark)
    }
}
