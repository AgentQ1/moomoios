//
//  GenerationService.swift
//  MoomoAI
//
//  Single shared entry point for ALL Gemini generation/editing. Every call goes
//  through a Firebase callable Cloud Function, which attaches the verified auth
//  token automatically. No API keys or model logic live in the app.
//

import Foundation
import FirebaseFunctions

final class GenerationService {
    static let shared = GenerationService()
    private lazy var functions = Functions.functions()
    private init() {}

    enum GenerationError: LocalizedError {
        case badResponse
        case server(String)   // already-friendly message, safe to show to the user
        var errorDescription: String? {
            switch self {
            case .badResponse: return "Something went wrong. Please try again."
            case .server(let message): return message
            }
        }
    }

    // MARK: - Public API (one method per Cloud Function)

    /// Plain chat. Sends the new user message plus recent conversation history and
    /// (optionally) the user-memory summary; the backend assembles the final prompt
    /// and system instruction.
    func generateText(message: String,
                      history: [[String: String]],
                      memory: String?,
                      language: String,
                      languageCode: String) async throws -> GenerationResult {
        var payload: [String: Any] = [
            "message": message,
            "history": history,
            "language": language,
            "languageCode": languageCode,
        ]
        if let memory, !memory.isEmpty { payload["memory"] = memory }
        return try await call("generateText", payload)
    }

    func generateImage(_ prompt: String) async throws -> GenerationResult {
        try await call("generateImage", ["prompt": prompt])
    }

    func editText(_ text: String, instruction: String) async throws -> GenerationResult {
        try await call("editGeneratedText", ["text": text, "instruction": instruction])
    }

    func editImage(path: String, instruction: String) async throws -> GenerationResult {
        try await call("editGeneratedImage", ["path": path, "instruction": instruction])
    }

    /// Edit a user-supplied (attached) image. The raw image bytes are sent inline
    /// as base64 — there is no Storage path for a freshly attached photo.
    func editImage(imageData: Data, mimeType: String = "image/jpeg", instruction: String) async throws -> GenerationResult {
        try await call("editGeneratedImage", [
            "imageBase64": imageData.base64EncodedString(),
            "mimeType": mimeType,
            "instruction": instruction,
        ])
    }

    /// Delete the caller's memory profile. Memory is client-read-only, so the
    /// actual delete happens server-side (Admin SDK). Best-effort; throws so the
    /// caller can decide whether to surface a failure.
    func clearMemory() async throws {
        _ = try await functions.httpsCallable("clearMemory").call([:])
    }

    /// Ask the backend to fold recent conversation into the user-memory summary.
    /// Best-effort: failures are logged in DEBUG only and never surface to the UI.
    func updateMemory(history: [[String: String]]) async {
        do {
            _ = try await functions.httpsCallable("updateMemory").call(["history": history])
        } catch {
            #if DEBUG
            print("MEMORY updateMemory error=\(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Shared transport

    private func call(_ name: String, _ data: [String: Any]) async throws -> GenerationResult {
        do {
            let response = try await functions.httpsCallable(name).call(data)
            guard let dict = response.data as? [String: Any],
                  let result = GenerationResult(from: dict) else {
                throw GenerationError.badResponse
            }
            return result
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: error.code) ?? .internal
            let serverMessage = error.localizedDescription
            #if DEBUG
            print("GENERATION_ERROR fn=\(name) code=\(code.rawValue) message=\(serverMessage)")
            #endif
            throw GenerationError.server(Self.friendlyMessage(code: code, serverMessage: serverMessage))
        }
    }

    /// Map a Cloud Functions error to something safe to show the user. Codes that
    /// carry a deliberate, user-facing message from the backend (rate limits, auth,
    /// bad input) are shown as-is; everything else collapses to a generic message.
    /// DEBUG builds additionally surface the code for easier diagnosis.
    private static func friendlyMessage(code: FunctionsErrorCode, serverMessage: String) -> String {
        let userFacing: String
        switch code {
        case .resourceExhausted, .unauthenticated, .permissionDenied, .invalidArgument, .notFound:
            userFacing = serverMessage
        default:
            userFacing = "Something went wrong. Please try again."
        }
        #if DEBUG
        return "[\(code.rawValue)] \(serverMessage)"
        #else
        return userFacing
        #endif
    }
}
