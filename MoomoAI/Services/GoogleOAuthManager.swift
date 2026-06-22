//
//  GoogleOAuthManager.swift
//  MoomoAI
//
//  Complete Google OAuth2 Manager - matches web app's google-auth.js
//  Handles authentication and token management for all Google APIs
//

import Foundation
import GoogleSignIn
import FirebaseAuth

class GoogleOAuthManager: ObservableObject {
    static let shared = GoogleOAuthManager()
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var tokenExpiry: Date?
    @Published var refreshToken: String?
    @Published var userEmail: String?
    @Published var userName: String?
    
    // Required scopes matching web app
    private let requiredScopes = [
        "https://www.googleapis.com/auth/drive.readonly",
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ]
    
    private init() {
        loadTokensFromStorage()
    }
    
    // MARK: - Authentication
    
    func signIn() async throws {
        let scenes = await UIApplication.shared.connectedScenes
        guard let scene = scenes.first as? UIWindowScene,
              let presentingVC =  scene.windows.first?.rootViewController else {
            throw GoogleOAuthError.noPresentingViewController
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingVC,
                hint: nil,
                additionalScopes: requiredScopes
            )
            
            let user = result.user
            
            // Store tokens
            self.accessToken = user.accessToken.tokenString
            self.tokenExpiry = user.accessToken.expirationDate
            self.refreshToken = user.refreshToken.tokenString
            self.userEmail = user.profile?.email
            self.userName = user.profile?.name
            self.isAuthenticated = true
            
            saveTokensToStorage()
            
            print("✅ Google OAuth: Signed in as \(userName ?? "Unknown")")
            
        } catch {
            print("❌ Google OAuth error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        
        accessToken = nil
        tokenExpiry = nil
        refreshToken = nil
        userEmail = nil
        userName = nil
        isAuthenticated = false
        
        clearTokensFromStorage()
        
        print("✅ Google OAuth: Signed out")
    }
    
    func restorePreviousSignIn() async {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            
            self.accessToken = user.accessToken.tokenString
            self.tokenExpiry = user.accessToken.expirationDate
            self.refreshToken = user.refreshToken.tokenString
            self.userEmail = user.profile?.email
            self.userName = user.profile?.name
            self.isAuthenticated = true
            
            saveTokensToStorage()
            
            print("✅ Google OAuth: Restored previous sign-in")
            
        } catch {
            print("ℹ️ No previous Google sign-in to restore")
            isAuthenticated = false
        }
    }
    
    // MARK: - Token Management
    
    func getValidAccessToken() async throws -> String {
        // Check if current token is valid
        if let token = accessToken,
           let expiry = tokenExpiry,
           expiry.timeIntervalSinceNow > 300 { // 5 minute buffer
            return token
        }
        
        // Token expired or missing, refresh it
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleOAuthError.notAuthenticated
        }
        
        do {
            try await user.refreshTokensIfNeeded()
            
            self.accessToken = user.accessToken.tokenString
            self.tokenExpiry = user.accessToken.expirationDate
            
            saveTokensToStorage()
            
            return user.accessToken.tokenString
            
        } catch {
            print("❌ Failed to refresh token: \(error.localizedDescription)")
            throw GoogleOAuthError.tokenRefreshFailed
        }
    }
    
    // MARK: - Storage
    
    private func loadTokensFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "google_auth_tokens"),
           let tokens = try? JSONDecoder().decode(TokenStorage.self, from: data) {
            self.accessToken = tokens.accessToken
            self.tokenExpiry = tokens.tokenExpiry
            self.refreshToken = tokens.refreshToken
            self.userEmail = tokens.userEmail
            self.userName = tokens.userName
            self.isAuthenticated = tokens.isAuthenticated
        }
    }
    
    func saveTokensToStorage() {
        let tokens = TokenStorage(
            accessToken: accessToken,
            tokenExpiry: tokenExpiry,
            refreshToken: refreshToken,
            userEmail: userEmail,
            userName: userName,
            isAuthenticated: isAuthenticated
        )
        
        if let data = try? JSONEncoder().encode(tokens) {
            UserDefaults.standard.set(data, forKey: "google_auth_tokens")
        }
    }
    
    private func clearTokensFromStorage() {
        UserDefaults.standard.removeObject(forKey: "google_auth_tokens")
    }
}

// MARK: - Token Storage Model

private struct TokenStorage: Codable {
    let accessToken: String?
    let tokenExpiry: Date?
    let refreshToken: String?
    let userEmail: String?
    let userName: String?
    let isAuthenticated: Bool
}

// MARK: - Errors

enum GoogleOAuthError: LocalizedError {
    case noPresentingViewController
    case notAuthenticated
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .noPresentingViewController:
            return "No view controller available for sign-in"
        case .notAuthenticated:
            return "User is not authenticated"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        }
    }
}
