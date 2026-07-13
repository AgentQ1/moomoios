//
//  MockAIService.swift
//  MoomoAI
//
//  Lightweight chat-model metadata. Real generation runs through
//  GenerationService (Cloud Functions + Gemini); this file only holds the
//  model enum the chat UI references.
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
