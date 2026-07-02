//
//  MockAIService.swift
//  MoomoAI
//
//  Lightweight chat-model metadata and error type. Real generation now runs
//  through GenerationService (Cloud Functions + Gemini); this file only holds
//  the small enums the chat UI still references.
//

import Foundation

/// Chat model identifier shown in the model picker.
enum AIModel: String, CaseIterable {
    case Q1 = "Q1"

    var displayName: String {
        switch self {
        case .Q1: return "Q1"
        }
    }

    var description: String {
        switch self {
        case .Q1: return "Moomo default model"
        }
    }
}

/// Error type used by the chat UI's error-handling paths.
enum ModelAPIError: LocalizedError {
    case invalidModel
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidModel: return "Invalid model selected"
        case .invalidResponse: return "Invalid response"
        case .httpError(let code): return "Error: \(code)"
        case .apiError(let message): return "Error: \(message)"
        }
    }
}
