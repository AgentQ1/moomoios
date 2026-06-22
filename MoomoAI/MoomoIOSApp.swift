//
//  MoomoIOSApp.swift
//  MoomoIOS
//
//  Native iOS Implementation of Moomo AI Assistant (frontend-only shell).
//
//  TODO: BACKEND INTEGRATION — Firebase configuration, Google Sign-In URL
//  handling, and app-session analytics were removed during the frontend-only
//  reset. Re-add backend bootstrapping here when rebuilding the backend.
//

import SwiftUI

@main
struct MoomoIOSApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var chatViewModel = ChatViewModel()

    init() {
        // No backend initialization in the frontend-only shell.
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(chatViewModel)
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "BackgroundPrimary")
        appearance.titleTextAttributes = [.foregroundColor: UIColor(named: "TextPrimary") ?? .label]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(named: "BackgroundSecondary")

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
