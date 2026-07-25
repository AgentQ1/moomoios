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

    /// Consent method ("google" / "apple" / "guest") staged by the welcome
    /// screen when the user taps a sign-in option with the legal checkbox
    /// checked. It is recorded (with the current document versions) only once
    /// the sign-in actually succeeds, so cancelling or failing authentication
    /// never persists consent.
    var pendingConsentMethod: String?

    private var stateHandle: AuthStateDidChangeListenerHandle?
    /// Resumed by the ASAuthorizationController delegate so the Apple flow can be
    /// awaited — used for both first-time sign-in and delete-time re-authentication.
    private var appleAuthContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

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
        guard !isLoading else { return }
        isLoading = true
        Task { @MainActor in
            do {
                _ = try await Auth.auth().signInAnonymously()
                recordPendingConsent()
            } catch { fail(error) }
            isLoading = false
        }
    }

    // MARK: - Google

    func signInWithGoogle() {
        // A sign-in is already presenting — don't launch a second Google
        // (ASWebAuthenticationSession) flow on top of it.
        guard !isLoading else { return }
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
        guard !isLoading else { return }
        isLoading = true
        Task { @MainActor in
            do {
                let (appleCredential, nonce) = try await requestAppleCredential()
                guard let tokenData = appleCredential.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8) else {
                    fail(AuthError.message("Apple Sign-In failed.")); return
                }
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idToken, rawNonce: nonce, fullName: appleCredential.fullName)
                await completeSignIn(with: credential)
            } catch {
                // A user-cancelled sheet is not an error worth surfacing, but it
                // must still clear any staged consent and the loading state.
                if isUserCancellation(error) {
                    pendingConsentMethod = nil
                    isLoading = false
                } else {
                    fail(error)
                }
            }
        }
    }

    /// Presents Sign in with Apple and returns the raw Apple ID credential along
    /// with the nonce requested with it. Backs both first-time sign-in and the
    /// re-authentication performed during account deletion.
    private func requestAppleCredential() async throws -> (credential: ASAuthorizationAppleIDCredential, nonce: String) {
        let nonce = Self.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        let credential = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            appleAuthContinuation = cont
            controller.performRequests()
        }
        return (credential, nonce)
    }

    // MARK: - Sign out / delete

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch { setError(error.localizedDescription) }
    }

    func deleteAccount() async -> Bool {
        guard !isLoading, let user = Auth.auth().currentUser else { return false }
        isLoading = true
        defer { isLoading = false }

        let providerIDs = user.providerData.map { $0.providerID }
        let isApple = providerIDs.contains("apple.com")
        let isGoogle = providerIDs.contains("google.com")

        // 1. Wipe server-side data first (Firestore tree, usage counter, generation
        //    log, generated images) via the deleteUserData Cloud Function — deleting
        //    only the Auth user would orphan all of it. Best-effort and idempotent:
        //    if the wipe fails, deletion still proceeds so the promise is kept.
        do {
            try await GenerationService.shared.deleteUserData()
        } catch {
            #if DEBUG
            print("AUTH deleteUserData error=\(error.localizedDescription)")
            #endif
        }

        // 2. Sign in with Apple requires the token be revoked on deletion (App
        //    Review Guideline 5.1.1(v)). Re-authenticating up front yields a fresh
        //    authorization code to revoke AND satisfies Firebase's recent-login
        //    requirement, so the delete below succeeds without a retry.
        do {
            var appleAuthCode: String?
            if isApple {
                appleAuthCode = try await reauthenticateWithApple(user)
            }
            try await finalizeDeletion(user, isApple: isApple, appleAuthCode: appleAuthCode)
            return true
        } catch {
            // 3. Firebase demands a recent login (typical for Google / guest, or if
            //    the proactive Apple re-auth was skipped) — re-authenticate with the
            //    user's provider and retry once.
            guard AuthErrorCode(rawValue: (error as NSError).code) == .requiresRecentLogin else {
                return handleDeletionFailure(error)
            }
            do {
                var appleAuthCode: String?
                if isApple {
                    appleAuthCode = try await reauthenticateWithApple(user)
                } else if isGoogle {
                    _ = try await user.reauthenticate(with: googleCredential())
                } else {
                    // Anonymous (guest) account: Firebase exposes no credential to
                    // re-authenticate with, so user.delete() cannot clear the
                    // requiresRecentLogin state and there is no "sign in again" the
                    // guest could perform. The server-side data wipe above already
                    // ran and the residual anonymous Auth record carries no PII, so
                    // honor the deletion by signing the guest out instead of
                    // dead-ending them on an impossible instruction (5.1.1(v)).
                    signOut()
                    return true
                }
                try await finalizeDeletion(user, isApple: isApple, appleAuthCode: appleAuthCode)
                return true
            } catch {
                return handleDeletionFailure(error)
            }
        }
    }

    /// Revokes the Sign in with Apple token (Guideline 5.1.1(v)) then deletes the
    /// Firebase Auth user. Revocation is best-effort — the deletion the user
    /// explicitly asked for must never be blocked by a revoke hiccup.
    private func finalizeDeletion(_ user: FirebaseAuth.User, isApple: Bool, appleAuthCode: String?) async throws {
        if isApple, let code = appleAuthCode {
            do {
                try await Auth.auth().revokeToken(withAuthorizationCode: code)
            } catch {
                #if DEBUG
                print("AUTH revokeToken error=\(error.localizedDescription)")
                #endif
            }
        }
        try await user.delete()
    }

    /// Re-runs Sign in with Apple, reauthenticates the Firebase user with the fresh
    /// credential, and returns the fresh authorization code used to revoke the token.
    private func reauthenticateWithApple(_ user: FirebaseAuth.User) async throws -> String? {
        let (appleCredential, nonce) = try await requestAppleCredential()
        guard let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.message("Apple re-authentication failed.")
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken, rawNonce: nonce, fullName: appleCredential.fullName)
        _ = try await user.reauthenticate(with: credential)
        if let codeData = appleCredential.authorizationCode {
            return String(data: codeData, encoding: .utf8)
        }
        return nil
    }

    /// Presents Google Sign-In and returns a fresh Firebase credential for re-auth.
    private func googleCredential() async throws -> AuthCredential {
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let root = Self.rootViewController() else {
            throw AuthError.message("Google Sign-In is not configured.")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result: GIDSignInResult = try await withCheckedThrowingContinuation { cont in
            GIDSignIn.sharedInstance.signIn(withPresenting: root) { signInResult, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let signInResult {
                    cont.resume(returning: signInResult)
                } else {
                    cont.resume(throwing: AuthError.message("Google Sign-In failed."))
                }
            }
        }
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.message("Google Sign-In failed.")
        }
        return GoogleAuthProvider.credential(
            withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
    }

    private func handleDeletionFailure(_ error: Error) -> Bool {
        setError(isUserCancellation(error) ? "Account deletion was canceled." : error.localizedDescription)
        return false
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        if (error as? ASAuthorizationError)?.code == .canceled { return true }
        let ns = error as NSError
        // GoogleSignIn reports a cancelled flow as code -5 in its own error domain.
        if ns.domain == "com.google.GIDSignIn", ns.code == -5 { return true }
        return false
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
        recordPendingConsent()
        isLoading = false
    }

    /// Persists the staged legal consent after a successful sign-in.
    private func recordPendingConsent() {
        guard let method = pendingConsentMethod else { return }
        LegalConsent.recordAcceptance(method: method)
        pendingConsentMethod = nil
    }

    private func fail(_ error: Error) {
        pendingConsentMethod = nil
        setError(error.localizedDescription)
        isLoading = false
    }
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
        let continuation = appleAuthContinuation
        appleAuthContinuation = nil
        if let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: appleCredential)
        } else {
            continuation?.resume(throwing: AuthError.message("Apple Sign-In failed."))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Cancellation vs. real failure is classified by the awaiting caller
        // (signInWithApple / deleteAccount) — just forward the error here.
        let continuation = appleAuthContinuation
        appleAuthContinuation = nil
        continuation?.resume(throwing: error)
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
