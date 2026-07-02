//
//  DocumentProcessor.swift
//  MoomoAI
//
//  Extracts readable text from attached documents (PDF, plain text, RTF, and a
//  best-effort attempt at Word docs) so the user can ask questions about a file.
//  Extraction runs entirely on-device — no binary is uploaded — and the text is
//  bounded so it never blows the model's prompt budget.
//

import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
#endif

enum DocumentProcessorError: LocalizedError {
    case unsupported(String)
    case empty
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupported(let name): return "“\(name)” isn’t a supported document type yet."
        case .empty: return "This document doesn’t contain any readable text."
        case .unreadable: return "Couldn’t read this document. It may be corrupted or password-protected."
        }
    }
}

/// Result of extracting text from a document.
struct ExtractedDocument: Equatable {
    let text: String
    let pageCount: Int?
    let truncated: Bool
}

enum DocumentProcessor {
    /// Max characters of extracted text forwarded to the model (keeps prompts bounded).
    static let maxCharacters = 12_000

    /// File extensions we can read text from. (Word .doc/.docx require a parser
    /// iOS doesn't ship — they're reported as unsupported with a clear message.)
    private static let textExtensions: Set<String> = ["txt", "md", "markdown", "csv", "json", "log", "xml", "yaml", "yml", "rtf"]

    /// Quick check used by the composer to decide whether a non-image file can be processed.
    static func isSupported(fileName: String, mimeType: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if ext == "pdf" || mimeType == "application/pdf" { return true }
        if textExtensions.contains(ext) || mimeType.hasPrefix("text/") || mimeType == "application/json" { return true }
        return false
    }

    /// Extract bounded text from a document. Throws a friendly error only when the
    /// file is genuinely unsupported or unreadable — files are never silently dropped.
    static func extractText(from data: Data, fileName: String, mimeType: String) throws -> ExtractedDocument {
        let ext = (fileName as NSString).pathExtension.lowercased()

        if ext == "pdf" || mimeType == "application/pdf" {
            return try extractPDF(data)
        }
        if textExtensions.contains(ext) || mimeType.hasPrefix("text/") || mimeType == "application/json" {
            return try extractPlainText(data, ext: ext)
        }
        throw DocumentProcessorError.unsupported(fileName)
    }

    // MARK: - Extractors

    private static func extractPDF(_ data: Data) throws -> ExtractedDocument {
        guard let doc = PDFDocument(data: data) else { throw DocumentProcessorError.unreadable }
        let pages = doc.pageCount
        var text = ""
        for index in 0..<pages {
            if let page = doc.page(at: index), let pageText = page.string {
                text += pageText + "\n"
                if text.count > maxCharacters { break }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DocumentProcessorError.empty }
        return bounded(trimmed, pageCount: pages)
    }

    private static func extractPlainText(_ data: Data, ext: String) throws -> ExtractedDocument {
        #if canImport(UIKit)
        if ext == "rtf",
           let attributed = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil) {
            let trimmed = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw DocumentProcessorError.empty }
            return bounded(trimmed, pageCount: nil)
        }
        #endif
        guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw DocumentProcessorError.unreadable
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DocumentProcessorError.empty }
        return bounded(trimmed, pageCount: nil)
    }

    // MARK: - Helpers

    private static func bounded(_ text: String, pageCount: Int?) -> ExtractedDocument {
        if text.count > maxCharacters {
            let endIndex = text.index(text.startIndex, offsetBy: maxCharacters)
            return ExtractedDocument(text: String(text[..<endIndex]), pageCount: pageCount, truncated: true)
        }
        return ExtractedDocument(text: text, pageCount: pageCount, truncated: false)
    }
}
