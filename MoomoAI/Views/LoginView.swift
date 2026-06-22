//
//  LoginView.swift
//  MoomoAI
//
//  Minimalist welcome screen — Google sign-in, Apple sign-in + Guest access
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Background
            K.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Sign-in actions (centered)
                VStack(spacing: 14) {
                        // Sign in with Apple (Guideline 4.8)
                        SignInWithAppleButton(.signIn) { request in
                            let appleRequest = authViewModel.prepareAppleSignInRequest()
                            request.requestedScopes = appleRequest.requestedScopes
                            request.nonce = appleRequest.nonce
                        } onCompletion: { result in
                            Task {
                                await authViewModel.handleAppleSignIn(result: result)
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .cornerRadius(12)
                    
                        // Sign in with Google (optional — for cloud sync)
                        Button(action: {
                            HapticFeedback.medium()
                            Task {
                                await authViewModel.signInWithEmail()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                
                                Text("Continue with Google")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(K.Colors.accentColor)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Continue as Guest
                        Button(action: {
                            HapticFeedback.light()
                            authViewModel.continueAsGuest()
                        }) {
                            Text("Continue as Guest")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(K.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 32)
                
                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }
                
                // Loading indicator
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: K.Colors.accentColor))
                        .padding(.top, 12)
                }
                
                Spacer()
                
                // Privacy links
                VStack(spacing: 6) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 12))
                        .foregroundColor(K.Colors.textSecondary)
                    
                    HStack(spacing: 4) {
                        Link("Privacy Policy", destination: URL(string: "https://moomopro-72876.web.app/privacy-policy.html")!)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(K.Colors.accentColor)
                        
                        Text("and")
                            .font(.system(size: 12))
                            .foregroundColor(K.Colors.textSecondary)
                        
                        Link("Terms of Service", destination: URL(string: "https://moomopro-72876.web.app/terms-of-service.html")!)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(K.Colors.accentColor)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
