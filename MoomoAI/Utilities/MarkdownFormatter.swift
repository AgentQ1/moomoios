//
//  MarkdownFormatter.swift
//  MoomoAI
//
//  Formats markdown text to AttributedString - EXACTLY matching webapp formatting
//

import SwiftUI

struct MarkdownFormatter {
    /// Clean markdown text by removing symbols for display in TextEditor
    static func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        
        // Remove markdown headers
        cleaned = cleaned.replacingOccurrences(of: "###", with: "")
        cleaned = cleaned.replacingOccurrences(of: "##", with: "")
        
        // Remove bold markers but keep the text
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        
        // Remove italic markers
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")
        
        // Remove code block markers
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        
        // Clean up extra spaces
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        return cleaned
    }
    
    /// Convert markdown text to AttributedString with EXACT webapp styling
    static func format(_ text: String) -> AttributedString {
        // Use manual parsing for consistent formatting matching web app
        return parseManually(text)
    }
    
    /// Manual parsing for better control over formatting - matches web app exactly
    private static func parseManually(_ text: String) -> AttributedString {
        var result = AttributedString()
        
        // Split into lines to process line by line
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""
        
        for (index, line) in lines.enumerated() {
            // Check for code block start/end
            if line.hasPrefix("```") {
                if !inCodeBlock {
                    // Starting a code block
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeBlockContent = ""
                } else {
                    // Ending a code block - add formatted code
                    if !codeBlockContent.isEmpty {
                        var codeAttr = AttributedString("\n")
                        
                        // Add language label if present
                        if !codeBlockLanguage.isEmpty {
                            var langLabel = AttributedString(codeBlockLanguage + "\n")
                            langLabel.font = .system(size: 12, weight: .medium)
                            langLabel.foregroundColor = Color(red: 0x66/255.0, green: 0x99/255.0, blue: 0xff/255.0)
                            codeAttr.append(langLabel)
                        }
                        
                        // Add code content
                        var code = AttributedString(codeBlockContent)
                        code.font = .system(size: 13, design: .monospaced)
                        code.foregroundColor = Color(red: 0xe3/255.0, green: 0xe3/255.0, blue: 0xe3/255.0)
                        code.backgroundColor = Color(red: 0x2a/255.0, green: 0x2a/255.0, blue: 0x2a/255.0)
                        codeAttr.append(code)
                        
                        var newline = AttributedString("\n\n")
                        newline.font = .system(size: 15, weight: .regular)
                        codeAttr.append(newline)
                        
                        result.append(codeAttr)
                    }
                    inCodeBlock = false
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                }
                continue
            }
            
            // Inside code block - accumulate content
            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                continue
            }
            
            // Process regular line with inline formatting
            var lineAttr = processInlineFormatting(line)
            
            // Add line break except for last line
            if index < lines.count - 1 {
                lineAttr.append(AttributedString("\n"))
            }
            
            result.append(lineAttr)
        }
        
        return result
    }
    
    /// Process inline markdown formatting (bold, italic, code, links)
    private static func processInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text
        
        // Process headers first
        if text.hasPrefix("### ") {
            var header = AttributedString(String(text.dropFirst(4)))
            header.font = .system(size: 17, weight: .semibold)
            header.foregroundColor = Color(red: 0xe3/255.0, green: 0xe3/255.0, blue: 0xe3/255.0)
            return header
        } else if text.hasPrefix("## ") {
            var header = AttributedString(String(text.dropFirst(3)))
            header.font = .system(size: 20, weight: .semibold)
            header.foregroundColor = Color(red: 0xe3/255.0, green: 0xe3/255.0, blue: 0xe3/255.0)
            return header
        } else if text.hasPrefix("# ") {
            var header = AttributedString(String(text.dropFirst(2)))
            header.font = .system(size: 24, weight: .semibold)
            header.foregroundColor = Color(red: 0xe3/255.0, green: 0xe3/255.0, blue: 0xe3/255.0)
            return header
        }
        
        // Process list items
        if text.hasPrefix("- ") || text.hasPrefix("* ") {
            var bullet = AttributedString("• ")
            bullet.font = .system(size: 15, weight: .regular)
            result.append(bullet)
            remaining = String(text.dropFirst(2))
        } else if let match = text.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            var number = AttributedString(String(text[match]))
            number.font = .system(size: 15, weight: .regular)
            result.append(number)
            remaining = String(text[match.upperBound...])
        }
        
        // Process inline patterns (code, bold, italic, links)
        while !remaining.isEmpty {
            // Look for inline code `code`
            if let codeRange = findPattern(in: remaining, pattern: "`", endPattern: "`") {
                // Add text before code
                let beforeCode = String(remaining[..<codeRange.lowerBound])
                if !beforeCode.isEmpty {
                    var plain = AttributedString(beforeCode)
                    plain.font = .system(size: 15, weight: .regular)
                    result.append(plain)
                }
                
                // Add code
                let codeText = String(remaining[codeRange]).dropFirst().dropLast()
                var code = AttributedString(String(codeText))
                code.font = .system(size: 13, design: .monospaced)
                code.foregroundColor = Color(red: 0x8B/255.0, green: 0x5C/255.0, blue: 0xF6/255.0)
                code.backgroundColor = Color(red: 0x2a/255.0, green: 0x2a/255.0, blue: 0x2a/255.0)
                result.append(code)
                
                remaining = String(remaining[codeRange.upperBound...])
            }
            // Look for bold **text**
            else if let boldRange = findPattern(in: remaining, pattern: "**", endPattern: "**") {
                let beforeBold = String(remaining[..<boldRange.lowerBound])
                if !beforeBold.isEmpty {
                    var plain = AttributedString(beforeBold)
                    plain.font = .system(size: 15, weight: .regular)
                    result.append(plain)
                }
                
                let boldText = String(remaining[boldRange]).dropFirst(2).dropLast(2)
                var bold = AttributedString(String(boldText))
                bold.font = .system(size: 15, weight: .semibold)
                result.append(bold)
                
                remaining = String(remaining[boldRange.upperBound...])
            }
            // Look for italic *text*
            else if let italicRange = findPattern(in: remaining, pattern: "*", endPattern: "*") {
                let beforeItalic = String(remaining[..<italicRange.lowerBound])
                if !beforeItalic.isEmpty {
                    var plain = AttributedString(beforeItalic)
                    plain.font = .system(size: 15, weight: .regular)
                    result.append(plain)
                }
                
                let italicText = String(remaining[italicRange]).dropFirst().dropLast()
                var italic = AttributedString(String(italicText))
                italic.font = .system(size: 15, weight: .regular).italic()
                result.append(italic)
                
                remaining = String(remaining[italicRange.upperBound...])
            }
            // No special formatting found, add rest as plain text
            else {
                var plain = AttributedString(remaining)
                plain.font = .system(size: 15, weight: .regular)
                result.append(plain)
                break
            }
        }
        
        return result
    }
    
    /// Find a pattern in text (like `code` or **bold**)
    private static func findPattern(in text: String, pattern: String, endPattern: String) -> Range<String.Index>? {
        guard let startRange = text.range(of: pattern) else { return nil }
        let searchStart = text.index(after: startRange.upperBound)
        guard searchStart < text.endIndex else { return nil }
        
        let remainingText = text[searchStart...]
        guard let endRange = remainingText.range(of: endPattern) else { return nil }
        
        return startRange.lowerBound..<endRange.upperBound
    }
    
    /// Check if text contains markdown
    static func containsMarkdown(_ text: String) -> Bool {
        let markdownPatterns = ["**", "*", "`", "```", "#", "-", "1.", "•"]
        return markdownPatterns.contains { text.contains($0) }
    }
    
    /// Extract code blocks from text
    static func extractCodeBlocks(_ text: String) -> [(language: String, code: String)] {
        var codeBlocks: [(String, String)] = []
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = text as NSString
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for result in results {
                let language = result.range(at: 1).location != NSNotFound 
                    ? nsString.substring(with: result.range(at: 1)) 
                    : "code"
                let code = nsString.substring(with: result.range(at: 2))
                codeBlocks.append((language, code))
            }
        }
        
        return codeBlocks
    }
}
