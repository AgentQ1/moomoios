//
//  ContentView.swift
//  MoomoAI
//
//  Main content view with sidebar and chat interface.
//
//  TODO: BACKEND INTEGRATION — Firebase session sync and the post-login AI data
//  consent flow were removed during the frontend-only reset. The app opens
//  directly into the main UI (AuthViewModel auto-provisions a local mock user).
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showSidebar = false
    @State private var showLanguageSelection = false

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                // Main app — shown immediately in the frontend-only shell.
                mainAppView
            } else {
                // Welcome screen (reachable only after an explicit sign-out).
                LoginView()
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
