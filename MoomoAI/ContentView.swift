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
        //
        // This modifier is on the Group, so it also runs while LoginView is
        // showing. Signing IN must therefore not sync from here — that would
        // pull conversations and upload the Apple purchase JWS while the user is
        // still being asked to accept the legal documents; that work is scoped
        // to chatRoot instead, past both gates.
        //
        // Signing OUT is handled here and only here, because chatRoot is torn
        // down by the transition and its onChange would never see it. The
        // nil-uid path of handleAuthChange is purely local teardown — it drops
        // the previous account's sessions from memory and disk and makes no
        // network call (its sync branch is guarded on `uid != nil`). Without
        // this, one user's chats would still be on disk when the next signs in.
        .onChange(of: authService.currentUser?.id) { uid in
            showSidebar = false
            showLanguageSelection = false
            if uid == nil {
                chatViewModel.handleAuthChange(uid: nil)
                StoreService.shared.handleAuthChange(uid: nil)
            }
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
        // Everything below is scoped to chatRoot on purpose: it only runs once
        // the user is signed in AND has accepted the current legal documents.
        //
        // Syncing conversations and re-verifying the App Store purchase are
        // network calls carrying personal data, so they must not fire while the
        // welcome screen is still asking for consent. Both handlers are
        // idempotent (they no-op unless the uid actually changed), so running
        // them from two places is safe: onAppear covers a session the auth
        // listener restored before this view existed, onChange covers a
        // sign-out or guest → account switch made from inside the chat.
        .onAppear {
            chatViewModel.handleAuthChange(uid: authService.currentUser?.id)
            StoreService.shared.handleAuthChange(uid: authService.currentUser?.id)
            // AI data-sharing permission (App Review 5.1.1(i)/5.1.2(i)) — asked
            // the moment the user first reaches the chat, before any composer
            // input can be sent. ChatView owns the presentation so the same
            // screen serves first run, a blocked send, and a Settings re-grant.
            chatViewModel.presentAIConsentIfUndecided()
        }
        .onChange(of: authService.currentUser?.id) { uid in
            chatViewModel.handleAuthChange(uid: uid)
            StoreService.shared.handleAuthChange(uid: uid)
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
