//
//  ContentView.swift
//  MoomoAI
//
//  Root view: gates on auth, then opens directly into the chat experience.
//  Image and text generation both happen inline in the chat composer
//  (ChatGPT/Gemini style) — there is no separate Create tab.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showSidebar = false
    @State private var showLanguageSelection = false
    // Legal gate: consent is recorded by AuthService when a sign-in succeeds
    // from the welcome screen's checkbox flow. If either document's version is
    // bumped, the stored values no longer match and even a signed-in returning
    // user is routed back to the welcome screen for renewed acceptance.
    @AppStorage(LegalConsent.acceptedPrivacyVersionKey) private var acceptedPrivacyVersion = ""
    @AppStorage(LegalConsent.acceptedTermsVersionKey) private var acceptedTermsVersion = ""

    private var hasCurrentLegalConsent: Bool {
        acceptedPrivacyVersion == LegalDocuments.privacyPolicyVersion
            && acceptedTermsVersion == LegalDocuments.termsOfServiceVersion
    }

    var body: some View {
        Group {
            if authService.isSignedIn && hasCurrentLegalConsent {
                chatRoot
            } else {
                LoginView()
            }
        }
        // Luxury warm-white canvas is a fixed light theme app-wide.
        .preferredColorScheme(.light)
        // Reset transient UI on every auth transition so a fresh login always
        // opens to the home chat with the sidebar closed (no stale drawer state),
        // and a new user never inherits the previous account's chats. Keyed on
        // the uid (not isSignedIn) so guest → account switches are caught too.
        .onChange(of: authService.currentUser?.id) { uid in
            showSidebar = false
            showLanguageSelection = false
            chatViewModel.handleAuthChange(uid: uid)
            // Refresh the StoreKit entitlement + backend Premium record for the
            // new account (and clear paywall presentation state on sign-out).
            StoreService.shared.handleAuthChange(uid: uid)
        }
        // The auth listener can restore a persisted session before this view is
        // installed, in which case onChange never observes the transition —
        // reconcile once at appear so the cloud chat list always syncs.
        .onAppear {
            chatViewModel.handleAuthChange(uid: authService.currentUser?.id)
            StoreService.shared.handleAuthChange(uid: authService.currentUser?.id)
        }
    }

    // MARK: - Chat Root (chat shell + full-screen sidebar overlay)

    private var chatRoot: some View {
        ZStack {
            // Main Chat Area
            ChatView(showSidebar: $showSidebar)

            // Full-screen, Gemini-style navigation drawer.
            if showSidebar {
                FullScreenSidebarView(
                    showSidebar: $showSidebar,
                    showLanguageSelection: $showLanguageSelection
                )
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSidebar)
        .accentColor(K.Colors.accentColor)
        .sheet(isPresented: $showLanguageSelection) {
            LanguageSelectionView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthService())
            .environmentObject(ChatViewModel())
            .preferredColorScheme(.light)
    }
}
