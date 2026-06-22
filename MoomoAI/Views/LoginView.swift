//
//  LoginView.swift
//  MoomoAI
//
//  Minimalist welcome screen (frontend-only shell).
//
//  TODO: BACKEND INTEGRATION — Apple Sign-In and Google Sign-In were removed
//  during the frontend-only reset. The app no longer requires login (see
//  AuthViewModel, which auto-provisions a local mock user). This screen is only
//  reachable after an explicit sign-out and just re-enters the app locally.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            // Background
            K.Colors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Text("Moomo")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(K.Colors.textPrimary)
                        .padding(.bottom, 8)

                    // Enter the app locally (no backend auth).
                    Button(action: {
                        HapticFeedback.medium()
                        authViewModel.continueAsGuest()
                    }) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(K.Colors.accentColor)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)

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
