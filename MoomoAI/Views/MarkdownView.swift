//
//  MarkdownView.swift
//  MoomoAI
//
//  Markdown rendering with syntax highlighting and code copy
//

import SwiftUI

struct MarkdownView: View {
    let text: String
    @State private var attributedString: AttributedString?
    
    var body: some View {
        if let attributedString = attributedString {
            Text(attributedString)
                .textSelection(.enabled)
        } else {
            Text(text)
                .onAppear {
                    parseMarkdown()
                }
        }
    }
    
    private func parseMarkdown() {
        // Simple markdown parser
        var result = AttributedString(text)
        
        // Bold **text**
        result = applyPattern(result, pattern: "\\*\\*(.+?)\\*\\*") { content in
            var attr = AttributedString(content)
            attr.font = .system(.body, design: .default).bold()
            return attr
        }
        
        // Italic *text*
        result = applyPattern(result, pattern: "\\*(.+?)\\*") { content in
            var attr = AttributedString(content)
            attr.font = .system(.body, design: .default).italic()
            return attr
        }
        
        // Inline code `code`
        result = applyPattern(result, pattern: "`([^`]+)`") { content in
            var attr = AttributedString(content)
            attr.font = .system(.body, design: .monospaced)
            attr.backgroundColor = K.Colors.backgroundSecondary.opacity(0.5)
            attr.foregroundColor = K.Colors.accentColor
            return attr
        }
        
        attributedString = result
    }
    
    private func applyPattern(_ string: AttributedString, pattern: String, transform: (String) -> AttributedString) -> AttributedString {
        var result = string
        let text = String(string.characters)
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        // Process matches in reverse to maintain indices
        for match in matches.reversed() {
            if match.numberOfRanges >= 2,
               let contentRange = Range(match.range(at: 1), in: text),
               let fullRange = Range(match.range, in: text) {
                let content = String(text[contentRange])
                let transformed = transform(content)
                
                // Replace in attributed string
                if let attrRange = Range<AttributedString.Index>(fullRange, in: result) {
                    result.replaceSubrange(attrRange, with: transformed)
                }
            }
        }
        
        return result
    }
}

// MARK: - Code Block View
struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                if let language = language, !language.isEmpty {
                    Text(language)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(K.Colors.textSecondary)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                        Text(copied ? "Copied!" : "Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(copied ? .green : K.Colors.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(K.Colors.backgroundSecondary.opacity(0.5))
            
            // Code content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(K.Colors.textPrimary)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(K.Colors.backgroundSecondary)
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(K.Colors.textSecondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func copyCode() {
        UIPasteboard.general.string = code
        copied = true
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

// MARK: - Enhanced Message Bubble with Markdown
struct EnhancedMessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Parse and render content with code blocks
                contentView
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(K.Colors.textSecondary)
            }
            .padding(12)
            .background(message.role == .user ? K.Colors.accentColor.opacity(0.1) : K.Colors.backgroundSecondary)
            .cornerRadius(16)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role != .user {
                Spacer()
            }
        }
        .padding(.horizontal, K.Layout.padding)
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            let blocks = parseContent(message.content)
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    MarkdownView(text: text)
                        .font(.system(size: 16))
                        .foregroundColor(K.Colors.textPrimary)
                case .code(let code, let language):
                    CodeBlockView(code: code, language: language)
                }
            }
        }
    }
    
    private func parseContent(_ content: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        
        // Split by code blocks ```language\ncode```
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(content)]
        }
        
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
        var lastIndex = content.startIndex
        
        for match in matches {
            // Add text before code block
            if let textRange = Range(NSRange(location: content.distance(from: content.startIndex, to: lastIndex), length: match.range.location - content.distance(from: content.startIndex, to: lastIndex)), in: content) {
                let text = String(content[textRange])
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(text))
                }
            }
            
            // Add code block
            if let codeRange = Range(match.range(at: 2), in: content) {
                let code = String(content[codeRange])
                var language: String?
                if match.numberOfRanges >= 2, let langRange = Range(match.range(at: 1), in: content) {
                    language = String(content[langRange])
                }
                blocks.append(.code(code, language))
            }
            
            if let endIndex = Range(match.range, in: content)?.upperBound {
                lastIndex = endIndex
            }
        }
        
        // Add remaining text
        if lastIndex < content.endIndex {
            let text = String(content[lastIndex...])
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(text))
            }
        }
        
        return blocks.isEmpty ? [.text(content)] : blocks
    }
    
    enum ContentBlock {
        case text(String)
        case code(String, String?)
    }
}

struct MarkdownView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MarkdownView(text: "This is **bold** and *italic* text with `inline code`")
            
            CodeBlockView(code: "func hello() {\n    print(\"Hello, World!\")\n}", language: "swift")
        }
        .padding()
    }
}
