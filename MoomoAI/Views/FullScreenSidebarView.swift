//
//  FullScreenSidebarView.swift
//  MoomoAI
//
//  Full-screen, Gemini-style navigation drawer branded for Moomo. Sections:
//  New chat, Search chats, Images, Library, Recent chats, and Profile/Settings
//  pinned to the bottom. (Daily brief and Videos are intentionally hidden until
//  those features ship.) Replaces the old half-width SidebarView.
//

import SwiftUI

struct FullScreenSidebarView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var authService: AuthService
    @Binding var showSidebar: Bool
    @Binding var showLanguageSelection: Bool

    @State private var searchText = ""
    @State private var showProfileMenu = false
    @State private var showLibrary = false
    @State private var libraryFilter: LibraryFilter = .all
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    if searchText.isEmpty {
                        navSection
                        recentHeader
                    }
                    recentChats
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.Colors.backgroundPrimary.ignoresSafeArea())
        .fullScreenCover(isPresented: $showLibrary) {
            LibraryView(initialFilter: libraryFilter)
        }
        .sheet(isPresented: $showProfileMenu) { ProfileMenuView() }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL { ShareSheet(items: [shareURL]) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(size: 22)
            Text("Moomo")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(K.Colors.royalBlue)
            Spacer()
            Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showSidebar = false } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(K.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(K.Colors.backgroundTertiary))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(K.Colors.textSecondary)
            TextField("Search chats", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(K.Colors.textPrimary)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(K.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(K.Colors.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Navigation section

    private var navSection: some View {
        VStack(spacing: 2) {
            navRow(icon: "square.and.pencil", title: "New chat") {
                HapticFeedback.medium()
                chatViewModel.createNewSession()
                close()
            }
            navRow(icon: "viewfinder", title: "Temporary chat") {
                HapticFeedback.medium()
                chatViewModel.createTemporarySession()
                close()
            }
            navRow(icon: "photo.on.rectangle.angled", title: "Images") {
                libraryFilter = .images
                showLibrary = true
            }
            navRow(icon: "square.stack.3d.up", title: "Library") {
                libraryFilter = .all
                showLibrary = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func navRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(K.Colors.textPrimary)
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(K.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarRowButtonStyle())
    }

    // MARK: - Recent chats

    private var recentHeader: some View {
        HStack {
            Text("Recent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(K.Colors.textSecondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var recentChats: some View {
        LazyVStack(spacing: 0) {
            ForEach(recentSessions) { session in
                ChatSessionRowView(
                    session: session,
                    isSelected: chatViewModel.currentSession?.id == session.id,
                    onTap: {
                        HapticFeedback.light()
                        chatViewModel.selectSession(session)
                        close()
                    },
                    onDelete: { HapticFeedback.medium(); chatViewModel.deleteSession(session) },
                    onRename: { newTitle in chatViewModel.renameSession(session, newTitle: newTitle) },
                    onTogglePin: { HapticFeedback.light(); chatViewModel.togglePinSession(session) },
                    onToggleImportant: { HapticFeedback.light(); chatViewModel.toggleImportantSession(session) },
                    onToggleArchive: { HapticFeedback.light(); chatViewModel.toggleArchiveSession(session) },
                    onShare: { format in handleExport(session: session, format: format) }
                )
            }

            if recentSessions.isEmpty {
                Text(searchText.isEmpty ? "No chats yet" : "No matches")
                    .font(.system(size: 14))
                    .foregroundColor(K.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            }
        }
        .padding(.horizontal, 8)
    }

    private var recentSessions: [ChatSession] {
        let base = chatViewModel.sessions
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.title.containsIgnoringCase(searchText) || $0.preview.containsIgnoringCase(searchText)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().background(K.Colors.borderColor.opacity(0.4))

            VStack(spacing: 8) {
                Button(action: { HapticFeedback.light(); showLanguageSelection = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 17))
                            .foregroundColor(K.Colors.textSecondary)
                            .frame(width: 26)
                        Text(chatViewModel.selectedLanguage.flag + "  " + chatViewModel.selectedLanguage.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(K.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(K.Colors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SidebarRowButtonStyle())

                profileRow
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var profileRow: some View {
        if let user = authService.currentUser {
            Button(action: { HapticFeedback.light(); showProfileMenu = true }) {
                HStack(spacing: 12) {
                    avatar(for: user)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(K.Colors.textPrimary)
                            .lineLimit(1)
                        Text(user.email)
                            .font(.system(size: 12))
                            .foregroundColor(K.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(K.Colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(SidebarRowButtonStyle())
        }
    }

    private func avatar(for user: User) -> some View {
        Group {
            if let pictureURL = user.picture, let url = URL(string: pictureURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Circle().fill(K.Colors.accentColor)
                        Text(user.initials).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(K.Colors.accentColor)
                    Text(user.initials).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                }
                .frame(width: 38, height: 38)
            }
        }
    }

    // MARK: - Helpers

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showSidebar = false }
    }

    private func handleExport(session: ChatSession, format: ChatSessionRowView.ExportFormat) {
        let url = (format == .txt)
            ? chatViewModel.exportSessionToTXT(session)
            : chatViewModel.exportSessionToPDF(session)
        if let url {
            shareURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Brand mark (gold Moomo sparkle)

struct BrandMark: View {
    var size: CGFloat = 22

    var body: some View {
        SparkleMark(color: K.Colors.gold, size: size)
    }
}

// MARK: - Row button style

private struct SidebarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isPressed ? K.Colors.backgroundTertiary : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct FullScreenSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        FullScreenSidebarView(showSidebar: .constant(true), showLanguageSelection: .constant(false))
            .environmentObject(ChatViewModel())
            .environmentObject(AuthService())
            .preferredColorScheme(.light)
    }
}
