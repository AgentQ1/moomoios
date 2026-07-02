//
//  AuthService.swift
//  MoomoAI
//
//  Single shared authentication service backed by Firebase Auth.
//  Handles Google Sign-In, Apple Sign-In, and Guest (anonymous) sign-in, and
//  keeps the session persistent via Firebase's auth-state listener. This is the
//  ONLY place auth logic lives — views observe it as an @EnvironmentObject.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isSignedIn = false
    @Published var isGuest = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var stateHandle: AuthStateDidChangeListenerHandle?
    private var appleNonce: String?

    override init() {
        super.init()
        // Firebase persists the session across launches; this listener restores it.
        stateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, fbUser in
            Task { @MainActor in self?.sync(fbUser) }
        }
    }

    // MARK: - State mapping

    private func sync(_ fbUser: FirebaseAuth.User?) {
        guard let fbUser else {
            currentUser = nil; isSignedIn = false; isGuest = false; return
        }
        isGuest = fbUser.isAnonymous
        currentUser = User(
            id: fbUser.uid,
            email: fbUser.email ?? (fbUser.isAnonymous ? "guest@local" : ""),
            name: fbUser.displayName ?? (fbUser.isAnonymous ? "Guest" : (fbUser.email ?? "Moomo User")),
            picture: fbUser.photoURL?.absoluteString,
            provider: fbUser.isAnonymous ? "guest" : (fbUser.providerData.first?.providerID ?? "firebase")
        )
        isSignedIn = true
    }

    // MARK: - Guest

    func continueAsGuest() {
        isLoading = true
        Task { @MainActor in
            do { _ = try await Auth.auth().signInAnonymously() }
            catch { fail(error) }
            isLoading = false
        }
    }

    // MARK: - Google

    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let root = Self.rootViewController() else {
            setError("Google Sign-In is not configured."); return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: root) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let error { self.fail(error); return }
                guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                    self.fail(AuthError.message("Google Sign-In failed.")); return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                await self.completeSignIn(with: credential)
            }
        }
    }

    // MARK: - Apple

    func signInWithApple() {
        let nonce = Self.randomNonceString()
        appleNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        isLoading = true
        controller.performRequests()
    }

    // MARK: - Sign out / delete

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch { setError(error.localizedDescription) }
    }

    func deleteAccount() async -> Bool {
        do { try await Auth.auth().currentUser?.delete(); return true }
        catch { setError(error.localizedDescription); return false }
    }

    // MARK: - Shared credential handling

    /// If the user is currently an anonymous guest, link the new credential so
    /// their uid (and history) is preserved; otherwise sign in normally.
    private func completeSignIn(with credential: AuthCredential) async {
        do {
            if let current = Auth.auth().currentUser, current.isAnonymous {
                _ = try await current.link(with: credential)
            } else {
                _ = try await Auth.auth().signIn(with: credential)
            }
        } catch {
            // Account already exists (e.g. guest upgrade collision) — fall back to a plain sign-in.
            do { _ = try await Auth.auth().signIn(with: credential) }
            catch { fail(error); return }
        }
        isLoading = false
    }

    private func fail(_ error: Error) { setError(error.localizedDescription); isLoading = false }
    private func setError(_ message: String) { errorMessage = message }

    enum AuthError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
    }
}

// MARK: - Apple Sign-In delegates

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let applecredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = appleNonce,
              let tokenData = applecredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            fail(AuthError.message("Apple Sign-In failed.")); return
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: applecredential.fullName
        )
        Task { @MainActor in await completeSignIn(with: credential) }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // User cancellation is not an error worth surfacing.
        if (error as? ASAuthorizationError)?.code == .canceled { isLoading = false; return }
        fail(error)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        Self.keyWindow() ?? ASPresentationAnchor()
    }
}

// MARK: - UIKit / crypto helpers

private extension AuthService {
    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    static func rootViewController() -> UIViewController? {
        keyWindow()?.rootViewController
    }

    static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var byte: UInt8 = 0
                _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
                return byte
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
