import SwiftUI

struct RegenerateOptionsView: View {
    @Environment(\.dismiss) var dismiss
    
    let originalMessage: ChatMessage
    let userPrompt: String
    let onRegenerate: (Double, String) -> Void
    
    @State private var temperature: Double = 0.7
    @State private var editedPrompt: String
    @State private var isEditingPrompt: Bool = false
    
    init(originalMessage: ChatMessage, userPrompt: String = "", onRegenerate: @escaping (Double, String) -> Void) {
        self.originalMessage = originalMessage
        self.userPrompt = userPrompt
        self.onRegenerate = onRegenerate
        self._editedPrompt = State(initialValue: userPrompt)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Temperature Control Section
                        temperatureSection
                        
                        Divider()
                        
                        // Edit Prompt Section
                        editPromptSection
                        
                        Divider()
                        
                        // Preview Section
                        previewSection
                    }
                    .padding()
                }
                
                // Bottom Action Button
                actionButton
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Regenerate Response")
                .font(.headline)
            
            Spacer()
            
            // Invisible button for centering
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.clear)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
    
    // MARK: - Temperature Section
    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Creativity Level")
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "%.1f", temperature))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(temperatureDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $temperature, in: 0.5...1.5, step: 0.1)
                .accentColor(.accentColor)
            
            HStack {
                Text("More Focused")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("More Creative")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var temperatureDescription: String {
        switch temperature {
        case 0.5..<0.8:
            return "More focused and deterministic responses"
        case 0.8..<1.2:
            return "Balanced creativity and consistency"
        default:
            return "More creative and varied responses"
        }
    }
    
    // MARK: - Edit Prompt Section
    private var editPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Message")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isEditingPrompt.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isEditingPrompt ? "checkmark" : "pencil")
                        Text(isEditingPrompt ? "Done" : "Edit")
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
            }
            
            if isEditingPrompt {
                TextEditor(text: $editedPrompt)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(8)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(editedPrompt)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .transition(.opacity)
            }
            
            Text("Edit your message to refine the AI's response")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Response")
                .font(.headline)
            
            Text(originalMessage.content)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
                .lineLimit(10)
            
            Text("This response will be replaced with a new one")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            onRegenerate(temperature, editedPrompt)
            dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Regenerate Response")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                editedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                    ? Color.gray 
                    : Color.accentColor
            )
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .disabled(editedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Regenerate Button Component
struct RegenerateButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                Text("Regenerate")
                    .font(.caption)
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
struct RegenerateOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        RegenerateOptionsView(
            originalMessage: ChatMessage(
                id: "1",
                role: ChatMessage.MessageRole.assistant,
                content: "This is a sample AI response that we want to regenerate with different parameters.",
                timestamp: Date()
            ),
            onRegenerate: { temp, prompt in
                print("Regenerate with temp: \(temp), prompt: \(prompt)")
            }
        )
    }
}
