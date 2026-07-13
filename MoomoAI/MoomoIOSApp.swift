//
//  MoomoIOSApp.swift
//  MoomoIOS
//
//  Native iOS implementation of Moomo AI Assistant.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct MoomoIOSApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var storeService = StoreService.shared

    init() {
        FirebaseApp.configure()
        configureAppearance()
        // Begin observing StoreKit transaction updates (renewals, refunds,
        // Ask to Buy approvals) as early as possible so none are missed.
        StoreService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(chatViewModel)
                .environmentObject(storeService)
                .onOpenURL { url in
                    // Lets Google Sign-In complete its OAuth callback.
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(K.Colors.backgroundPrimary)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(K.Colors.textPrimary)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
