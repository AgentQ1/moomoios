//
//  AuthViewModel.swift
//  MoomoAI
//
//  Frontend-only authentication shell.
//
//  TODO: BACKEND INTEGRATION — All real auth (Firebase Auth, Google Sign-In,
//  Apple Sign-In, guest provisioning, account deletion) was removed during the
//  frontend-only reset. This view model now auto-provisions a local mock user so
//  the app opens directly into the main UI with no sign-in required. Re-implement
//  real authentication here when rebuilding the backend.
//

import Foundation

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isGuest = false

    init() {
        // Auto sign-in with a local mock user — no login gate in the frontend shell.
        signInWithMockUser()
    }

    // MARK: - Mock Session

    /// Local mock user used to render profile/account UI without a backend.
    private func makeMockUser() -> User {
        User(
            id: "local-mock-user",
            email: "you@example.com",
            name: "Moomo User",
            picture: nil,
            provider: "local"
        )
    }

    private func signInWithMockUser() {
        currentUser = makeMockUser()
        isSignedIn = true
        isGuest = false
        errorMessage = nil
    }

    // MARK: - Frontend Stubs (kept so existing views keep compiling)

    /// TODO: BACKEND INTEGRATION — replace with real email/Google sign-in.
    func signInWithEmail() async {
        signInWithMockUser()
    }

    func continueAsGuest() {
        currentUser = User(
            id: "local-guest",
            email: "guest@local",
            name: "Guest",
            provider: "guest"
        )
        isSignedIn = true
        isGuest = true
    }

    func signOut() {
        // Return to the (frontend-only) welcome screen.
        currentUser = nil
        isSignedIn = false
        isGuest = false
        errorMessage = nil
    }

    /// TODO: BACKEND INTEGRATION — replace with real account deletion.
    func deleteAccount() async -> Bool {
        signOut()
        return true
    }
}
