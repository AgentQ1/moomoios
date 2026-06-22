//
//  MockAIService.swift
//  MoomoAI
//
//  Frontend-only placeholder for AI chat generation.
//
//  TODO: BACKEND INTEGRATION — Replace this mock with the real AI generation
//  service. Implement `sendMessage(...)` to call your backend / model provider
//  (e.g. an Anthropic Claude endpoint) and return the generated text. This file
//  intentionally makes NO network calls and embeds NO API keys.
//

import Foundation

/// Chat model identifier used by ChatViewModel/MockAIService.
/// Kept minimal (single model) for the frontend-only shell.
enum AIModel: String, CaseIterable {
    case Q1 = "Q1"

    var displayName: String {
        switch self {
        case .Q1: return "Q1"
        }
    }

    var description: String {
        switch self {
        case .Q1: return "Frontend preview model"
        }
    }
}

/// Local, offline stand-in for the former `ModelAPIService`.
/// Returns canned placeholder text so the chat UI renders and flows end-to-end
/// without any backend.
final class MockAIService {
    static let shared = MockAIService()

    init() {}

    /// Returns a placeholder assistant response after a short simulated delay.
    ///
    /// TODO: BACKEND INTEGRATION — swap the body for a real network request to
    /// your generation backend.
    func sendMessage(
        model: AIModel,
        messages: [ChatMessage],
        systemPrompt: String? = nil,
        attachments: [AttachmentItem] = []
    ) async throws -> String {
        // Simulate network/generation latency so the typing indicator is visible.
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s

        let lastUserMessage = messages.last(where: { $0.role == .user })?.content ?? ""
        let attachmentNote = attachments.isEmpty
            ? ""
            : "\n\n_(\(attachments.count) attachment(s) received — not processed in frontend-only mode.)_"

        return """
        This is a placeholder response from the frontend-only build of Moomo. \
        No AI backend is connected yet.

        You said: "\(lastUserMessage)"\(attachmentNote)

        TODO: Connect a real generation backend to replace this mock.
        """
    }
}

/// Error type preserved for the chat UI's error-handling paths.
enum ModelAPIError: LocalizedError {
    case invalidModel
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidModel:
            return "Invalid model selected"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "Error: \(code)"
        case .apiError(let message):
            return "Error: \(message)"
        }
    }
}
