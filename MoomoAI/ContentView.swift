//
//  ContentView.swift
//  MoomoAI
//
//  Main content view with sidebar and chat interface
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showSidebar = false
    @State private var showLanguageSelection = false
    @State private var showAIConsentAfterLogin = false

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                // Main app — accessible after sign-in or guest
                mainAppView
            } else {
                // Welcome screen with Google sign-in + guest option
                LoginView()
            }
        }
        .onChange(of: authViewModel.isSignedIn) { isSignedIn in
            if isSignedIn, !authViewModel.isGuest, let userEmail = authViewModel.currentUser?.email {
                // Enable Firebase sync only for signed-in (non-guest) users
                chatViewModel.enableFirebaseSync(userEmail: userEmail)
                chatViewModel.syncAllSessionsToFirebase(userEmail: userEmail)
                
                // Show AI data consent dialog immediately after login (Guideline 5.1.1(i))
                if !PersistenceService.shared.hasAIDataSharingConsent() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showAIConsentAfterLogin = true
                    }
                }
            } else {
                // Disable sync when user signs out
                chatViewModel.disableFirebaseSync()
            }
        }
        .onAppear {
            // Enable sync if user is already signed in (non-guest)
            if authViewModel.isSignedIn, !authViewModel.isGuest, let userEmail = authViewModel.currentUser?.email {
                chatViewModel.enableFirebaseSync(userEmail: userEmail)
            }
        }
    }
    
    // MARK: - Main App View
    
    private var mainAppView: some View {
        ZStack {
            // Main Chat Area
            ChatView(showSidebar: $showSidebar)
            
            // Sidebar overlay (shown when showSidebar is true)
            if showSidebar {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showSidebar = false
                        }
                    }
                
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        SidebarView(
                            showSidebar: $showSidebar,
                            showLanguageSelection: $showLanguageSelection
                        )
                        .frame(width: min(geometry.size.width * 0.85, 320))
                        .transition(.move(edge: .leading))
                        
                        Spacer()
                    }
                }
                .ignoresSafeArea(edges: .vertical)
            }
            
            // AI Data Consent shown proactively after login (Guideline 5.1.1(i) & 5.1.2(i))
            if showAIConsentAfterLogin {
                AIDataConsentView(
                    isPresented: $showAIConsentAfterLogin,
                    onAccept: {
                        PersistenceService.shared.setAIDataSharingConsent(true)
                    },
                    onDecline: {
                        // User declined — consent not granted, will be re-prompted before sending messages
                    }
                )
            }
        }
        .accentColor(Color("AccentColor"))
        .sheet(isPresented: $showLanguageSelection) {
            LanguageSelectionView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
            .environmentObject(ChatViewModel())
            .preferredColorScheme(.dark)
    }
}
