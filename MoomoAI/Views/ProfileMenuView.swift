//
//  ProfileMenuView.swift
//  MoomoAI
//
//  User profile menu - matches web app profile menu
//

import SwiftUI

struct ProfileMenuView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showClearChatsConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeletionError = false
    @State private var deletionErrorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                if let user = authService.currentUser {
                    // User info section
                    Section {
                        HStack(spacing: 12) {
                            // Avatar
                            if let pictureURL = user.picture, let url = URL(string: pictureURL) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Text(user.initials)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 56, height: 56)
                                .background(K.Colors.accentColor)
                                .clipShape(Circle())
                            } else {
                                Text(user.initials)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(K.Colors.accentColor)
                                    .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(K.Colors.textPrimary)
                                
                                Text(user.email)
                                    .font(.system(size: 14))
                                    .foregroundColor(K.Colors.textSecondary)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                    
                                    Text(user.provider == "firebase-apple" ? "Signed in with Apple" : "Signed in with Google")
                                        .font(.system(size: 12))
                                        .foregroundColor(K.Colors.textSecondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Personalization & Memory
                    Section {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Personalization & Memory", systemImage: "brain.head.profile")
                        }
                    }

                    // Privacy section
                    Section("Privacy") {
                        Link(destination: URL(string: "https://moomopro-72876.web.app/privacy-policy.html")!) {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                        }
                        
                        Link(destination: URL(string: "https://moomopro-72876.web.app/terms-of-service.html")!) {
                            Label("Terms of Service", systemImage: "doc.text.fill")
                        }
                    }
                    
                    // Actions section
                    Section {
                        Button(action: {
                            showClearChatsConfirmation = true
                        }) {
                            Label("Clear All Chats", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            authService.signOut()
                            dismiss()
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Account Deletion (Apple Guideline 5.1.1(v))
                    Section {
                        Button(action: {
                            showDeleteAccountConfirmation = true
                        }) {
                            Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                                .foregroundColor(.red)
                        }
                    } footer: {
                        Text("Permanently deletes your account and all associated data. This action cannot be undone.")
                            .font(.system(size: 12))
                            .foregroundColor(K.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear All Chats", isPresented: $showClearChatsConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    chatViewModel.clearAllSessions()
                }
            } message: {
                Text("This will delete all your chat history. This action cannot be undone.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        let success = await authService.deleteAccount()
                        if success {
                            dismiss()
                        } else {
                            deletionErrorMessage = authService.errorMessage ?? "Unknown error occurred"
                            showDeletionError = true
                        }
                    }
                }
            } message: {
                Text("This will permanently delete your account, all chat history, and associated data. This action cannot be undone.")
            }
            .alert("Deletion Failed", isPresented: $showDeletionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deletionErrorMessage)
            }
        }
    }
}

struct ProfileMenuView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileMenuView()
            .environmentObject(AuthService())
            .environmentObject(ChatViewModel())
            .preferredColorScheme(.dark)
    }
}
