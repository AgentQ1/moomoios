//
//  ModelAPIService.swift
//  MoomoAI
//
//  Single-model service: Q1 (Gemini Flash) via the server-side geminiProxy.
//

import Foundation

enum AIModel: String, CaseIterable {
    case Q1 = "Q1"

    var displayName: String {
        switch self {
        case .Q1: return "Q1"
        }
    }

    var description: String {
        switch self {
        case .Q1: return "Fast responses with web search"
        }
    }
}

class ModelAPIService {
    static let shared = ModelAPIService()

    // Model configuration. Gemini key is held server-side by geminiProxy; the app
    // embeds no API keys.
    private let models: [AIModel: ModelConfig] = [
        .Q1: ModelConfig(
            name: "gemini-2.5-flash",
            endpoint: "https://us-central1-moomopro-72876.cloudfunctions.net/geminiProxy"
        )
    ]

    init() {}

    // MARK: - Main Send Message Method

    func sendMessage(model: AIModel, messages: [ChatMessage], systemPrompt: String? = nil, attachments: [AttachmentItem] = []) async throws -> String {
        guard let config = models[model] else {
            throw ModelAPIError.invalidModel
        }
        return try await sendGeminiMessage(config: config, model: model, messages: messages, systemPrompt: systemPrompt, attachments: attachments)
    }

    // MARK: - Gemini API (Q1)

    private func sendGeminiMessage(config: ModelConfig, model: AIModel, messages: [ChatMessage], systemPrompt: String?, attachments: [AttachmentItem] = []) async throws -> String {
        var contents: [[String: Any]] = []
        
        // Add system message as first exchange if provided
        if let systemPrompt = systemPrompt {
            contents.append([
                "role": "user",
                "parts": [["text": systemPrompt]]
            ])
            contents.append([
                "role": "model",
                "parts": [["text": "Understood. I will follow these instructions."]]
            ])
        }
        
        // Add conversation history
        for message in messages {
            // For the last user message, include attachments
            if message.role == .user && message.id == messages.last?.id && !attachments.isEmpty {
                var parts: [[String: Any]] = [["text": message.content]]
                
                // Add image attachments as base64
                for attachment in attachments where attachment.type == .image {
                    let base64String = attachment.data.base64EncodedString()
                    parts.append([
                        "inlineData": [
                            "mimeType": "image/jpeg",
                            "data": base64String
                        ]
                    ])
                }
                
                contents.append([
                    "role": "user",
                    "parts": parts
                ])
            } else {
                contents.append([
                    "role": message.role == .user ? "user" : "model",
                    "parts": [["text": message.content]]
                ])
            }
        }
        
        var requestBody: [String: Any] = [
            // Routing field consumed by geminiProxy to pick the model server-side.
            "model": config.name,
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.95,
                "topK": 40,
                "maxOutputTokens": 16384  // Increased for long document generation
            ]
        ]
        
        // Q1 uses Google Search grounding.
        requestBody["tools"] = [
            ["googleSearch": [:]]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // Gemini key is held server-side by geminiProxy; no key embedded in the app.
        var request = URLRequest(url: URL(string: config.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorDict["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ModelAPIError.apiError(message)
            }
            throw ModelAPIError.httpError(httpResponse.statusCode)
        }
        
        guard let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = responseDict["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw ModelAPIError.invalidResponse
        }
        
        return text
    }
}

// MARK: - Supporting Types

private struct ModelConfig {
    let name: String
    let endpoint: String
}

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
            return "Invalid response from API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}
