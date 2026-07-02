//
//  SettingsView.swift
//  MoomoAI
//
//  Personalization & Memory settings: toggle memory on/off, view the stored
//  memory summary, and clear it. Designed to be pushed inside ProfileMenuView's
//  navigation stack.
//

import SwiftUI

struct SettingsView: View {
    // Shares the same UserDefaults key MemoryService reads from the ViewModel.
    @AppStorage("moomo.memoryEnabled") private var memoryEnabled = true

    @State private var memory: UserMemory?
    @State private var isLoading = false
    @State private var showClearConfirmation = false

    var body: some View {
        List {
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
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
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
