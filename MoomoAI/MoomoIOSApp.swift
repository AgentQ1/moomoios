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

    init() {
        FirebaseApp.configure()
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(chatViewModel)
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

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(K.Colors.backgroundSecondary)

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
