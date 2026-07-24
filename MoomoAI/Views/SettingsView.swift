//
//  SettingsView.swift
//  MoomoAI
//
//  Personalization & Memory settings: toggle memory on/off, view the stored
//  memory summary, and clear it. Designed to be pushed inside ProfileMenuView's
//  navigation stack.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    // Shares the same UserDefaults key MemoryService reads from the ViewModel.
    @AppStorage("moomo.memoryEnabled") private var memoryEnabled = true

    @ObservedObject private var storeService = StoreService.shared
    @ObservedObject private var aiConsent = AIDataSharingConsent.shared
    @State private var memory: UserMemory?
    @State private var isLoading = false
    @State private var showClearConfirmation = false
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @State private var showAIDisclosure = false
    @State private var showAIConsentScreen = false
    @State private var showRevokeConfirmation = false

    var body: some View {
        List {
            Section {
                if storeService.isPremium {
                    HStack {
                        Label("Moomo Premium", systemImage: "sparkles")
                        Spacer()
                        Text("Active")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(K.Colors.gold)
                    }
                    Button {
                        showManageSubscriptions = true
                    } label: {
                        Label("Manage Subscription", systemImage: "creditcard")
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Moomo Premium", systemImage: "sparkles")
                    }
                }
                Button {
                    Task { await storeService.restorePurchases() }
                } label: {
                    if storeService.isRestoring {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Restoring…").foregroundColor(.secondary)
                        }
                    } else {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(storeService.isRestoring)
            } footer: {
                if let message = storeService.statusMessage {
                    Text(message)
                }
            }

            // AI data sharing — the permission required before any of the user's
            // content reaches the third-party AI provider (App Review 5.1.1(i)
            // and 5.1.2(i)). Viewable and revocable here at any time.
            Section {
                HStack {
                    Label("AI data sharing", systemImage: "sparkles")
                    Spacer()
                    Text(aiConsent.isGranted ? "On" : "Off")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(aiConsent.isGranted ? K.Colors.gold : .secondary)
                }

                Button {
                    showAIDisclosure = true
                } label: {
                    Label("What is shared, and with whom", systemImage: "info.circle")
                }

                if aiConsent.isGranted {
                    Button(role: .destructive) {
                        showRevokeConfirmation = true
                    } label: {
                        Label("Turn off AI data sharing", systemImage: "hand.raised.slash")
                    }
                } else {
                    Button {
                        showAIConsentScreen = true
                    } label: {
                        Label("Turn on AI data sharing", systemImage: "hand.raised")
                    }
                }
            } header: {
                Text("AI data sharing")
            } footer: {
                if aiConsent.isGranted {
                    Text(aiDataSharingGrantedFooter)
                } else {
                    Text(AIDataSharingDisclosure.declinedExplanation)
                }
            }

            Section {
                Toggle(isOn: $memoryEnabled) {
                    Label("Memory", systemImage: "brain.head.profile")
                }
                .tint(K.Colors.accentColor)
            } footer: {
                Text("When on, Moomo remembers helpful details across chats to personalize responses. Turn it off to stop using stored memory.")
            }

            Section("Memory summary") {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading…").foregroundColor(.secondary)
                    }
                } else if let memory, !memory.isEmpty {
                    if !memory.summary.isEmpty {
                        memoryRow(title: "Summary", value: memory.summary)
                    }
                    if !memory.preferences.isEmpty {
                        memoryRow(title: "Preferences", value: bulleted(memory.preferences))
                    }
                    if !memory.importantFacts.isEmpty {
                        memoryRow(title: "Important facts", value: bulleted(memory.importantFacts))
                    }
                    if !memory.projects.isEmpty {
                        memoryRow(title: "Projects", value: bulleted(memory.projects))
                    }
                } else {
                    Text("No memory stored yet. As you chat, Moomo will learn helpful details here.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("Clear memory", systemImage: "trash")
                }
                .disabled(memory?.isEmpty ?? true)
            } footer: {
                Text("Sensitive details are not stored unless you explicitly ask Moomo to remember them.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        // Read-only view of exactly what the user agreed to.
        .sheet(isPresented: $showAIDisclosure) {
            LegalDocumentSheet(
                title: AIDataSharingDisclosure.title,
                text: AIDataSharingDisclosure.plainText
            )
        }
        // Re-grant after a decline/revoke: the same screen shown on first run.
        .fullScreenCover(isPresented: $showAIConsentScreen) {
            AIDataConsentView { _ in showAIConsentScreen = false }
        }
        .confirmationDialog(
            "Turn off AI data sharing?",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Turn off", role: .destructive) { aiConsent.revoke() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Moomo will stop sending your content to \(AIProvider.company), and AI responses will be turned off until you turn this back on.")
        }
        .task { await reload() }
        .refreshable { await reload() }
        .confirmationDialog("Clear all stored memory?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear memory", role: .destructive) {
                Task {
                    await MemoryService.shared.clearMemory()
                    await reload()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes the personalization Moomo has learned about you.")
        }
    }

    private func bulleted(_ items: [String]) -> String {
        items.map { "• \($0)" }.joined(separator: "\n")
    }

    /// Footer for an active permission: names the recipient and shows when the
    /// user agreed, so the record is visible rather than implied.
    private var aiDataSharingGrantedFooter: String {
        var text = "Your messages, attachments and recent conversation context are sent to "
            + "\(AIProvider.company) to generate responses."
        if let decidedAt = aiConsent.decidedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            text += " You allowed this on \(formatter.string(from: decidedAt))."
        }
        return text
    }

    private func memoryRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    @MainActor
    private func reload() async {
        isLoading = true
        memory = await MemoryService.shared.loadMemory()
        isLoading = false
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { SettingsView() }
            .preferredColorScheme(.dark)
    }
}
