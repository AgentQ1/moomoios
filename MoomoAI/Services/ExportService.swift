//
//  ExportService.swift
//  MoomoAI
//
//  Service for exporting conversations to PDF and TXT formats
//

import Foundation
import PDFKit
import UIKit

class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - Export to TXT
    
    /// Exports a chat session to plain text format
    /// - Parameter session: The chat session to export
    /// - Returns: URL of the exported TXT file
    func exportToTXT(_ session: ChatSession) -> URL? {
        var text = """
        Moomo AI Chat Export
        ====================
        Title: \(session.title)
        Created: \(formatDate(session.createdAt))
        Messages: \(session.messageCount)
        
        
        """
        
        for (index, message) in session.messages.enumerated() {
            let role = message.role == .user ? "You" : "Moomo AI"
            let timestamp = formatTime(message.timestamp)
            
            text += """
            [\(index + 1)] \(role) - \(timestamp)
            \(message.content)
            
            
            """
        }
        
        text += """
        
        
        ====================
        Exported from Moomo AI
        \(formatDate(Date()))
        """
        
        return saveToFile(text, filename: "\(sanitizeFilename(session.title)).txt")
    }
    
    // MARK: - Export to PDF
    
    /// Exports a chat session to PDF format with formatting
    /// - Parameter session: The chat session to export
    /// - Returns: URL of the exported PDF file
    func exportToPDF(_ session: ChatSession) -> URL? {
        let pdfMetaData = [
            kCGPDFContextTitle: "Moomo AI - \(session.title)",
            kCGPDFContextAuthor: "Moomo AI",
            kCGPDFContextCreator: "Moomo AI iOS App"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 50
        let contentWidth = pageWidth - 2 * margin
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            var yPosition: CGFloat = margin
            
            // Start first page
            context.beginPage()
            
            // Draw header
            yPosition = drawHeader(
                context: context.cgContext,
                pageRect: pageRect,
                session: session,
                yPosition: yPosition,
                margin: margin,
                contentWidth: contentWidth
            )
            
            // Draw messages
            for (index, message) in session.messages.enumerated() {
                // Skip typing indicators
                guard !message.isTyping else { continue }
                
                let messageHeight = calculateMessageHeight(
                    message: message,
                    index: index,
                    contentWidth: contentWidth
                )
                
                // Check if we need a new page
                if yPosition + messageHeight > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin
                }
                
                yPosition = drawMessage(
                    context: context.cgContext,
                    message: message,
                    index: index,
                    yPosition: yPosition,
                    margin: margin,
                    contentWidth: contentWidth
                )
            }
            
            // Draw footer on last page
            drawFooter(
                context: context.cgContext,
                pageRect: pageRect,
                margin: margin
            )
        }
        
        return saveToFile(data, filename: "\(sanitizeFilename(session.title)).pdf")
    }
    
    // MARK: - PDF Drawing Helpers
    
    private func drawHeader(
        context: CGContext,
        pageRect: CGRect,
        session: ChatSession,
        yPosition: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        var y = yPosition
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.label
        ]
        let titleText = "Moomo AI Chat"
        let titleSize = titleText.size(withAttributes: titleAttributes)
        titleText.draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: titleAttributes
        )
        y += titleSize.height + 10
        
        // Session title
        let sessionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let sessionTitleSize = session.title.size(withAttributes: sessionTitleAttributes)
        session.title.draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: sessionTitleAttributes
        )
        y += sessionTitleSize.height + 5
        
        // Metadata
        let metaAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let metaText = "Created: \(formatDate(session.createdAt)) • \(session.messageCount) messages"
        let metaSize = metaText.size(withAttributes: metaAttributes)
        metaText.draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: metaAttributes
        )
        y += metaSize.height + 20
        
        // Divider
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        context.strokePath()
        y += 20
        
        return y
    }
    
    private func drawMessage(
        context: CGContext,
        message: ChatMessage,
        index: Int,
        yPosition: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat
    ) -> CGFloat {
        var y = yPosition
        
        // Role and timestamp
        let role = message.role == .user ? "You" : "Moomo AI"
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: message.role == .user ? UIColor.systemBlue : UIColor.systemGreen
        ]
        let roleText = "\(role) • \(formatTime(message.timestamp))"
        let headerSize = roleText.size(withAttributes: headerAttributes)
        roleText.draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: headerAttributes
        )
        y += headerSize.height + 5
        
        // Message content
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]
        
        let boundingRect = CGRect(
            x: margin,
            y: y,
            width: contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        let contentRect = message.content.boundingRect(
            with: boundingRect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        
        message.content.draw(
            with: boundingRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        
        y += contentRect.height + 15
        
        return y
    }
    
    private func drawFooter(
        context: CGContext,
        pageRect: CGRect,
        margin: CGFloat
    ) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let footerText = "Exported from Moomo AI • \(formatDate(Date()))"
        let footerSize = footerText.size(withAttributes: footerAttributes)
        
        footerText.draw(
            at: CGPoint(
                x: (pageRect.width - footerSize.width) / 2,
                y: pageRect.height - margin + 10
            ),
            withAttributes: footerAttributes
        )
    }
    
    private func calculateMessageHeight(
        message: ChatMessage,
        index: Int,
        contentWidth: CGFloat
    ) -> CGFloat {
        let headerHeight: CGFloat = 20
        let spacing: CGFloat = 20
        
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12)
        ]
        
        let contentRect = message.content.boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        
        return headerHeight + contentRect.height + spacing
    }
    
    // MARK: - File Helpers
    
    private func saveToFile(_ content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            #if DEBUG
            print("Error saving TXT file: \(error)")
            #endif
            return nil
        }
    }
    
    private func saveToFile(_ data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            #if DEBUG
            print("Error saving PDF file: \(error)")
            #endif
            return nil
        }
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Date Formatters (creating DateFormatter is expensive — reuse them)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}
