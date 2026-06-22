//
//  AuthViewModel.swift
//  MoomoAI
//
//  ViewModel for authentication — Google sign-in, Apple sign-in + guest mode
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isGuest = false
    
    private let persistence = PersistenceService.shared
    private let firebaseService = FirebaseService.shared
    
    /// Nonce used for the current Apple Sign In request (unhashed)
    private var currentNonce: String?
    
    init() {
        checkAuthState()
    }
    
    // MARK: - Authentication
    
    func checkAuthState() {
        // Check Firebase Auth state
        if let firebaseUser = Auth.auth().currentUser {
            loadUserFromFirebase(firebaseUser)
        } else {
            // Load from local storage (could be signed-in or guest user)
            currentUser = persistence.loadUser()
            if let user = currentUser {
                isSignedIn = true
                isGuest = user.provider == "guest"
            }
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithEmail() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Get the root view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw AuthError.noRootViewController
            }
            
            // Configure Email Sign In
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthError.noClientID
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Sign in with email provider
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                throw AuthError.noIDToken
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            let firebaseUser = authResult.user
            
            // Create user object
            let moomoUser = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                name: firebaseUser.displayName ?? "",
                picture: firebaseUser.photoURL?.absoluteString,
                provider: "firebase-google"
            )
            
            // Save user
            currentUser = moomoUser
            isSignedIn = true
            persistence.saveUser(moomoUser)
            
            // Save to Firebase (non-fatal — don't block sign-in if DB write fails)
            do {
                try await firebaseService.saveUser(moomoUser)
            } catch {
                print("⚠️ Firebase save failed (non-fatal): \(error.localizedDescription)")
            }
            
            // Set analytics user
            firebaseService.setAnalyticsUser(userId: moomoUser.id, email: moomoUser.email)
            firebaseService.trackSignIn(method: "google")
            
            print("✅ Successfully signed in with Google: \(moomoUser.email)")
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Sign in error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Sign in with Apple
    
    /// Generate a cryptographically secure nonce for Apple Sign In
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    /// SHA256 hash of the nonce for Apple's request
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Prepare and return an ASAuthorizationAppleIDRequest with nonce
    func prepareAppleSignInRequest() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }
    
    /// Handle the completed Apple Sign In authorization
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid Apple credential type"
                isLoading = false
                return
            }
            
            guard let nonce = currentNonce else {
                errorMessage = "Invalid state: no nonce found"
                isLoading = false
                return
            }
            
            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to get Apple ID token"
                isLoading = false
                return
            }
            
            do {
                // Create Firebase credential from Apple token
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                // Sign in to Firebase
                let authResult = try await Auth.auth().signIn(with: credential)
                let firebaseUser = authResult.user
                
                // Apple only provides name on first sign-in; use Firebase's displayName as fallback
                let displayName: String
                if let givenName = appleIDCredential.fullName?.givenName {
                    let familyName = appleIDCredential.fullName?.familyName ?? ""
                    displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                } else {
                    displayName = firebaseUser.displayName ?? ""
                }
                
                // Apple may hide the real email; Firebase resolves it
                let email = firebaseUser.email ?? appleIDCredential.email ?? ""
                
                let moomoUser = User(
                    id: firebaseUser.uid,
                    email: email,
                    name: displayName,
                    picture: firebaseUser.photoURL?.absoluteString,
                    provider: "firebase-apple"
                )
                
                // Save user
                currentUser = moomoUser
                isSignedIn = true
                persistence.saveUser(moomoUser)
                
                // Save to Firebase (non-fatal — don't block sign-in if DB write fails)
                do {
                    try await firebaseService.saveUser(moomoUser)
                } catch {
                    print("⚠️ Firebase save failed (non-fatal): \(error.localizedDescription)")
                }
                
                // Analytics
                firebaseService.setAnalyticsUser(userId: moomoUser.id, email: moomoUser.email)
                firebaseService.trackSignIn(method: "apple")
                
                print("✅ Successfully signed in with Apple: \(moomoUser.email)")
                
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Apple Sign In Firebase error: \(error.localizedDescription)")
            }
            
        case .failure(let error):
            // User cancelled is not an error worth showing
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
                print("❌ Apple Sign In error: \(error.localizedDescription)")
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Guest Mode
    
    func continueAsGuest() {
        let guestId = UUID().uuidString
        let guestUser = User(
            id: guestId,
            email: "guest_\(guestId.prefix(8))@local",
            name: "Guest",
            provider: "guest"
        )
        
        currentUser = guestUser
        isSignedIn = true
        isGuest = true
        persistence.saveUser(guestUser)
        
        print("✅ Continuing as guest: \(guestUser.id)")
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            if !isGuest {
                // Sign out from Firebase
                try Auth.auth().signOut()
                
                // Sign out from Google
                GIDSignIn.sharedInstance.signOut()
                
                // Track sign out in Firebase Database
                if let user = currentUser {
                    Task {
                        let userKey = user.email.replacingOccurrences(of: ".", with: "_")
                        let userRef = Database.database().reference().child("users").child(userKey)
                        _ = try? await userRef.updateChildValues([
                            "lastSignOut": ISO8601DateFormatter().string(from: Date())
                        ])
                    }
                }
            }
            
            // Clear local data
            currentUser = nil
            isSignedIn = false
            isGuest = false
            errorMessage = nil
            persistence.clearUser()
            
            print("✅ Successfully signed out")
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Sign out error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Account Deletion (Guideline 5.1.1(v))
    
    func deleteAccount() async -> Bool {
        // Guest users just clear local data
        if isGuest {
            currentUser = nil
            isSignedIn = false
            isGuest = false
            persistence.clearUser()
            persistence.clearAllSessions()
            persistence.clearCurrentSessionId()
            PersistenceService.shared.setAIDataSharingConsent(false)
            print("✅ Guest data cleared")
            return true
        }
        
        guard let firebaseUser = Auth.auth().currentUser else {
            errorMessage = "No authenticated user found"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Re-authenticate before deletion (required by Firebase for sensitive operations)
            try await reauthenticateUser(firebaseUser)
            
            // 2. Delete user data from Firebase Realtime Database
            if let email = currentUser?.email {
                let userKey = email.replacingOccurrences(of: ".", with: "_")
                let userRef = Database.database().reference().child("users").child(userKey)
                try await userRef.removeValue()
                print("✅ User data deleted from Firebase Database")
            }
            
            // 3. Delete the Firebase Auth account
            try await firebaseUser.delete()
            print("✅ Firebase Auth account deleted")
            
            // 4. Sign out from Google
            GIDSignIn.sharedInstance.signOut()
            
            // 5. Clear all local data
            currentUser = nil
            isSignedIn = false
            isGuest = false
            persistence.clearUser()
            persistence.clearAllSessions()
            persistence.clearCurrentSessionId()
            
            // Clear AI consent so it re-prompts on new account
            PersistenceService.shared.setAIDataSharingConsent(false)
            
            print("✅ Account fully deleted")
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            print("❌ Account deletion error: \(error.localizedDescription)")
            isLoading = false
            return false
        }
    }
    
    /// Re-authenticate the user before sensitive operations like account deletion
    private func reauthenticateUser(_ firebaseUser: FirebaseAuth.User) async throws {
        // Check if user signed in with Apple
        if firebaseUser.providerData.contains(where: { $0.providerID == "apple.com" }) {
            // Re-authenticate with Apple
            let nonce = randomNonceString()
            currentNonce = nonce
            let hashedNonce = sha256(nonce)
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            
            let result = try await performAppleAuth(request: request)
            
            guard let appleIDCredential = result as? ASAuthorizationAppleIDCredential,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AuthError.noIDToken
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            try await firebaseUser.reauthenticate(with: credential)
            
        } else {
            // Re-authenticate with Google
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw AuthError.noRootViewController
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.noIDToken
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await firebaseUser.reauthenticate(with: credential)
        }
    }
    
    /// Helper to perform Apple Sign-In authorization flow
    private func performAppleAuth(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationCredential {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            // Retain delegate until completion
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.delegate = delegate
            controller.performRequests()
        }
    }
    
    // MARK: - Helpers
    
    private func loadUserFromFirebase(_ firebaseUser: FirebaseAuth.User) {
        // Detect provider from Firebase user's provider data
        let provider: String
        if firebaseUser.providerData.contains(where: { $0.providerID == "apple.com" }) {
            provider = "firebase-apple"
        } else {
            provider = "firebase-google"
        }
        
        let email = firebaseUser.email ?? ""
        
        var user = User(
            id: firebaseUser.uid,
            email: email,
            name: firebaseUser.displayName ?? "",
            picture: firebaseUser.photoURL?.absoluteString,
            provider: provider
        )
        
        currentUser = user
        isSignedIn = true
        isGuest = false
        persistence.saveUser(user)
        
        // Set analytics user
        firebaseService.setAnalyticsUser(userId: user.id, email: user.email)
        
        // Fetch stats from Firebase Database in background
        if !email.isEmpty {
            Task {
                if let stats = await firebaseService.fetchUserStats(email: email) {
                    user.totalMessages = stats.totalMessages
                    user.totalSessions = stats.totalSessions
                    user.totalSearches = stats.totalSearches
                    currentUser = user
                    persistence.saveUser(user)
                }
            }
        }
    }
}

// MARK: - Apple Sign In Delegate for re-authentication
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorizationCredential, Error>
    
    init(continuation: CheckedContinuation<ASAuthorizationCredential, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization.credential)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

// MARK: - Error Types
enum AuthError: LocalizedError {
    case noRootViewController
    case noClientID
    case noIDToken
    
    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Cannot find root view controller"
        case .noClientID:
            return "Cannot find Firebase client ID"
        case .noIDToken:
            return "Cannot get ID token from Google"
        }
    }
}
