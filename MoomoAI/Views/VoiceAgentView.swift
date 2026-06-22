//
//  VoiceAgentView.swift
//  MoomoAI
//
//  Voice Agent Interface - Shows listening state and agent responses
//

import SwiftUI

struct VoiceAgentView: View {
    @StateObject private var voiceAgent = VoiceAgentService.shared
    @Environment(\.dismiss) var dismiss
    @State private var showPermissionAlert = false
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        voiceAgent.stopListening()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                }
                
                Spacer()
                
                // Listening visualization
                if voiceAgent.isListening {
                    listeningVisualization
                } else if voiceAgent.isProcessing {
                    processingVisualization
                } else {
                    idleVisualization
                }
                
                // Transcribed text
                if !voiceAgent.transcribedText.isEmpty {
                    VStack(spacing: 10) {
                        Text("You said:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(voiceAgent.transcribedText)
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 30)
                }
                
                // Agent response
                if !voiceAgent.agentResponse.isEmpty {
                    VStack(spacing: 10) {
                        Text("Moomo:")
                            .font(.caption)
                            .foregroundColor(.blue.opacity(0.7))
                        
                        Text(voiceAgent.agentResponse)
                            .font(.body)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Instructions
                VStack(spacing: 15) {
                    Text(instructionText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Example commands
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try saying:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        
                        exampleCommand("\"Create a document on Quantum Mechanics\"")
                        exampleCommand("\"Make a presentation on Entanglement\"")
                        exampleCommand("\"Write a paper on Black Holes\"")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startVoiceAgent()
        }
        .alert("Microphone Permission Required", isPresented: $showPermissionAlert) {
            Button("Settings", action: openSettings)
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable microphone access in Settings to use voice commands.")
        }
    }
    
    // MARK: - Visualizations
    
    private var listeningVisualization: some View {
        ZStack {
            // Outer pulse
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(animationScale)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animationScale)
            
            // Middle circle
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                )
            
            // Icon
            Image(systemName: "waveform")
                .font(.system(size: 50, weight: .medium))
                .foregroundColor(.white)
        }
        .onAppear {
            animationScale = 1.2
        }
    }
    
    private var processingVisualization: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(2)
            
            Text("Processing...")
                .font(.title3)
                .foregroundColor(.white)
        }
    }
    
    private var idleVisualization: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.5)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
            
            Image(systemName: "mic.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
        }
    }
    
    private func exampleCommand(_ text: String) -> some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var instructionText: String {
        if voiceAgent.isListening {
            return "Listening... Speak your command"
        } else if voiceAgent.isProcessing {
            return "Processing your request..."
        } else {
            return "Tap the button to start speaking"
        }
    }
    
    // MARK: - Actions
    
    private func startVoiceAgent() {
        voiceAgent.requestPermissions { granted in
            if granted {
                do {
                    try voiceAgent.startListening()
                } catch {
                    print("Error starting voice recognition: \(error)")
                }
            } else {
                showPermissionAlert = true
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct VoiceAgentView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceAgentView()
    }
}
