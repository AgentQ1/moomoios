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
        case offline
        case server(String)   // already-friendly message, safe to show to the user
        /// The free daily allowance is spent — the UI presents the Premium
        /// paywall instead of an error bubble, so there is no message here.
        case freeQuotaExhausted
        /// The user has not granted (or has withdrawn) permission to send their
        /// content to the third-party AI provider. The UI presents the consent
        /// screen; nothing left the device.
        case consentRequired
        var errorDescription: String? {
            switch self {
            case .badResponse: return "Something went wrong. Please try again."
            case .offline: return "You're offline. Check your connection and try again."
            case .server(let message): return message
            case .freeQuotaExhausted: return "Upgrade to Moomo Premium for unlimited access."
            case .consentRequired: return AIDataSharingDisclosure.blockedMessage
            }
        }
    }

    /// An image sent inline with a chat message (multimodal understanding).
    struct InlineImage {
        let data: Data
        let mimeType: String
    }

    // MARK: - Third-party AI consent gate

    /// Hard precondition for every call that forwards user content to the AI
    /// provider (App Review 5.1.1(i) / 5.1.2(i)). The UI presents the consent
    /// screen before the user can reach these paths, but enforcing it here too
    /// means a background task, a future call site, or a race after the user
    /// revokes permission still cannot put content on the wire.
    ///
    /// Deliberately NOT applied to verifyAppStorePurchase, clearMemory or
    /// deleteUserData: none of them reach Gemini, and gating account deletion or
    /// a memory wipe behind consent would break Guideline 5.1.1(v) and trap data
    /// the user is trying to remove.
    private func requireAIConsent() throws {
        guard AIDataSharingConsent.isGrantedSnapshot else {
            #if DEBUG
            print("GENERATION_BLOCKED reason=aiDataSharingConsentMissing")
            #endif
            throw GenerationError.consentRequired
        }
    }

    // MARK: - Public API (one method per Cloud Function)

    /// Chat, optionally multimodal. Sends the new user message plus recent
    /// conversation history, (optionally) the user-memory summary, and any
    /// attached images — text and images travel in the SAME request so the model
    /// answers based on the visual content.
    func generateText(message: String,
                      history: [[String: String]],
                      memory: String?,
                      language: String,
                      languageCode: String,
                      images: [InlineImage] = [],
                      requestId: String = UUID().uuidString) async throws -> GenerationResult {
        try requireAIConsent()
        var payload: [String: Any] = [
            "message": message,
            "history": history,
            "language": language,
            "languageCode": languageCode,
            "requestId": requestId,
        ]
        if let memory, !memory.isEmpty { payload["memory"] = memory }
        if !images.isEmpty {
            payload["images"] = images.map {
                ["data": $0.data.base64EncodedString(), "mimeType": $0.mimeType]
            }
        }
        #if DEBUG
        // Counts and sizes only — never image bytes or message content.
        print("GENERATION_REQUEST fn=generateText parts=\(1 + images.count) images=\(images.count) imageBytes=\(images.map(\.data.count)) mimes=\(images.map(\.mimeType)) historyTurns=\(history.count)")
        #endif
        return try await call("generateText", payload)
    }

    func generateImage(_ prompt: String, requestId: String = UUID().uuidString) async throws -> GenerationResult {
        try requireAIConsent()
        return try await call("generateImage", ["prompt": prompt, "requestId": requestId])
    }

    func editImage(path: String, instruction: String, requestId: String = UUID().uuidString) async throws -> GenerationResult {
        try requireAIConsent()
        return try await call("editGeneratedImage", ["path": path, "instruction": instruction, "requestId": requestId])
    }

    /// Edit a user-supplied (attached) image. The raw image bytes are sent inline
    /// as base64 — there is no Storage path for a freshly attached photo.
    func editImage(imageData: Data, mimeType: String = "image/jpeg", instruction: String, requestId: String = UUID().uuidString) async throws -> GenerationResult {
        try requireAIConsent()
        return try await call("editGeneratedImage", [
            "imageBase64": imageData.base64EncodedString(),
            "mimeType": mimeType,
            "instruction": instruction,
            "requestId": requestId,
        ])
    }

    /// Send an Apple-signed transaction (JWS) to the backend, which verifies it
    /// against Apple's root CAs and records the Premium entitlement for the
    /// signed-in user. The backend — not this call's result — gates AI access.
    func verifyAppStorePurchase(jws: String) async throws {
        _ = try await functions.httpsCallable("verifyAppStorePurchase").call(["jws": jws])
    }

    /// Delete the caller's memory profile. Memory is client-read-only, so the
    /// actual delete happens server-side (Admin SDK). Best-effort; throws so the
    /// caller can decide whether to surface a failure.
    func clearMemory() async throws {
        _ = try await functions.httpsCallable("clearMemory").call([:])
    }

    /// Wipe all of the caller's server-side data (Firestore tree, usage counter,
    /// generation log, generated images in Storage). Used by account deletion.
    func deleteUserData() async throws {
        _ = try await functions.httpsCallable("deleteUserData").call([:])
    }

    /// Ask the backend to fold recent conversation into the user-memory summary.
    /// Best-effort: failures are logged in DEBUG only and never surface to the UI.
    ///
    /// Consent-gated: this ships conversation text to Gemini for summarization,
    /// and it runs from a detached background task after a reply lands — exactly
    /// the kind of path that would otherwise keep sending content after the user
    /// revoked permission.
    func updateMemory(history: [[String: String]]) async {
        guard AIDataSharingConsent.isGrantedSnapshot else {
            #if DEBUG
            print("MEMORY updateMemory skipped=aiDataSharingConsentMissing")
            #endif
            return
        }
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
            // The backend marks a spent free allowance with a machine-readable
            // details code — the UI shows the paywall, not an error bubble.
            if let details = error.userInfo[FunctionsErrorDetailsKey] as? [String: Any],
               details["moomoCode"] as? String == "FREE_QUOTA_EXHAUSTED" {
                throw GenerationError.freeQuotaExhausted
            }
            throw GenerationError.server(Self.friendlyMessage(code: code, serverMessage: serverMessage))
        } catch let error as NSError where error.domain == NSURLErrorDomain {
            // No connectivity never reaches the Functions layer — surface it
            // honestly instead of the generic "something went wrong".
            #if DEBUG
            print("GENERATION_ERROR fn=\(name) urlError=\(error.code)")
            #endif
            throw GenerationError.offline
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
