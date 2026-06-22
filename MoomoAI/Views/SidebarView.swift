//
//  SidebarView.swift
//  MoomoAI
//
//  Sidebar with chat history and settings - matches web app sidebar exactly
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showSidebar: Bool
    @Binding var showLanguageSelection: Bool
    
    @State private var showProfileMenu = false
    @State private var searchText = ""
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var selectedFilter: FilterType = .all
    @State private var collapsedGroups: Set<String> = []
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case pinned = "Pinned"
        case important = "Important"
        case archived = "Archived"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .pinned: return "pin.fill"
            case .important: return "star.fill"
            case .archived: return "archivebox.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with logo and new chat button
            sidebarHeader
                .padding(.top, getSafeAreaTop())
            
            // New chat button (prominent)
            newChatButton
            
            // Search bar
            searchBar
            
            // Filter chips
            filterChips
            
            // Chat sessions list with groups
            chatSessionsList
            
            // Footer with language and sign in/profile
            sidebarFooter
        }
        .frame(maxWidth: .infinity)
        .background(K.Colors.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(K.Colors.backgroundTertiary.opacity(0.5))
                .frame(width: 1),
            alignment: .trailing
        )
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // Helper to get safe area top inset
    private func getSafeAreaTop() -> CGFloat {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return keyWindow?.safeAreaInsets.top ?? 0
    }
    
    // MARK: - Sidebar Header
    private var sidebarHeader: some View {
        HStack(spacing: 8) {
            // Logo with horizontal colorful bars (stacked vertically like Google logo)
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                    .frame(width: 24, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.92, green: 0.26, blue: 0.21))
                    .frame(width: 24, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.98, green: 0.74, blue: 0.02))
                    .frame(width: 24, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.20, green: 0.66, blue: 0.33))
                    .frame(width: 24, height: 4)
            }
            .frame(height: 22)
            
            Text("Moomo")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(K.Colors.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, K.Layout.padding)
        .padding(.top, K.Layout.padding)
        .padding(.bottom, 12)
    }
    
    // MARK: - New Chat Button
    private var newChatButton: some View {
        Button(action: {
            HapticFeedback.medium()
            chatViewModel.createNewSession()
            showSidebar = false
        }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(K.Colors.accentColor)
                
                Text("New Chat")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(K.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
                    .foregroundColor(K.Colors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(K.Colors.backgroundTertiary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(K.Colors.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, K.Layout.padding)
        .padding(.bottom, 10)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(K.Colors.textSecondary)
            
            TextField("Search chats...", text: $searchText)
                .font(.system(size: 14))
                .foregroundColor(K.Colors.textPrimary)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(K.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(K.Colors.backgroundTertiary)
        .cornerRadius(8)
        .padding(.horizontal, K.Layout.padding)
        .padding(.bottom, 12)
    }
    
    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(action: {
                        HapticFeedback.light()
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(selectedFilter == filter ? .white : K.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedFilter == filter 
                                ? K.Colors.accentColor 
                                : K.Colors.backgroundTertiary
                        )
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, K.Layout.padding)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Chat Sessions List
    private var chatSessionsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(groupedSessions.keys.sorted(by: { groupOrder($0) < groupOrder($1) }), id: \.self) { groupName in
                    if let sessions = groupedSessions[groupName], !sessions.isEmpty {
                        ChatGroupView(
                            groupName: groupName,
                            sessions: sessions,
                            isCollapsed: collapsedGroups.contains(groupName),
                            currentSessionId: chatViewModel.currentSession?.id,
                            onToggleCollapse: {
                                withAnimation(.spring(response: 0.3)) {
                                    if collapsedGroups.contains(groupName) {
                                        collapsedGroups.remove(groupName)
                                    } else {
                                        collapsedGroups.insert(groupName)
                                    }
                                }
                            },
                            onSelectSession: { session in
                                chatViewModel.selectSession(session)
                                showSidebar = false
                            },
                            onDeleteSession: { session in
                                chatViewModel.deleteSession(session)
                            },
                            onRenameSession: { session, newTitle in
                                chatViewModel.renameSession(session, newTitle: newTitle)
                            },
                            onTogglePin: { session in
                                chatViewModel.togglePinSession(session)
                            },
                            onToggleImportant: { session in
                                chatViewModel.toggleImportantSession(session)
                            },
                            onToggleArchive: { session in
                                chatViewModel.toggleArchiveSession(session)
                            },
                            onShare: { session, format in
                                handleExport(session: session, format: format)
                            }
                        )
                    }
                }
            }
            .padding(.top, 4)
        }
    }
    
    private var filteredSessions: [ChatSession] {
        var sessions = chatViewModel.sessions
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .pinned:
            sessions = sessions.filter { $0.isPinned }
        case .important:
            sessions = sessions.filter { $0.isImportant }
        case .archived:
            sessions = sessions.filter { $0.isArchived }
        }
        
        // Apply search
        if !searchText.isEmpty {
            sessions = sessions.filter { 
                $0.title.containsIgnoringCase(searchText) ||
                $0.preview.containsIgnoringCase(searchText)
            }
        }
        
        return sessions.sorted { lhs, rhs in
            // Pinned sessions first
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            // Then by updated date
            return lhs.updatedAt > rhs.updatedAt
        }
    }
    
    private var groupedSessions: [String: [ChatSession]] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [String: [ChatSession]] = [
            "Today": [],
            "Yesterday": [],
            "Last 7 Days": [],
            "Last 30 Days": [],
            "Older": []
        ]
        
        for session in filteredSessions {
            if calendar.isDateInToday(session.updatedAt) {
                groups["Today"]?.append(session)
            } else if calendar.isDateInYesterday(session.updatedAt) {
                groups["Yesterday"]?.append(session)
            } else if let daysAgo = calendar.dateComponents([.day], from: session.updatedAt, to: now).day {
                if daysAgo <= 7 {
                    groups["Last 7 Days"]?.append(session)
                } else if daysAgo <= 30 {
                    groups["Last 30 Days"]?.append(session)
                } else {
                    groups["Older"]?.append(session)
                }
            }
        }
        
        return groups
    }
    
    private func groupOrder(_ groupName: String) -> Int {
        switch groupName {
        case "Today": return 0
        case "Yesterday": return 1
        case "Last 7 Days": return 2
        case "Last 30 Days": return 3
        case "Older": return 4
        default: return 5
        }
    }
    
    // MARK: - Sidebar Footer
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
                .background(K.Colors.backgroundTertiary)
            
            VStack(spacing: 10) {
                // Language selector
                Button(action: { 
                    HapticFeedback.light()
                    showLanguageSelection = true 
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 16))
                            .foregroundColor(K.Colors.textSecondary)
                        
                        Text(chatViewModel.selectedLanguage.flag + " " + chatViewModel.selectedLanguage.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(K.Colors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(K.Colors.textSecondary)
                    }
                    .padding(12)
                    .background(K.Colors.backgroundTertiary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Sign in / Profile button
                if let user = authViewModel.currentUser {
                    Button(action: { 
                        HapticFeedback.light()
                        showProfileMenu = true 
                    }) {
                        HStack(spacing: 12) {
                            // Avatar
                            if let pictureURL = user.picture, let url = URL(string: pictureURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ZStack {
                                        Circle()
                                            .fill(K.Colors.accentColor)
                                        Text(user.initials)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(K.Colors.accentColor)
                                    Text(user.initials)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 36, height: 36)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(K.Colors.textPrimary)
                                    .lineLimit(1)
                                
                                Text(user.email)
                                    .font(.system(size: 11))
                                    .foregroundColor(K.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(K.Colors.textSecondary)
                        }
                        .padding(12)
                        .background(K.Colors.backgroundTertiary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showProfileMenu) {
                        ProfileMenuView()
                    }
                } else {
                    // Sign in with Google
                    Button(action: {
                        HapticFeedback.medium()
                        Task {
                            await authViewModel.signInWithEmail()
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(K.Colors.accentColor)
                            
                            Text("Sign in with Google")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(K.Colors.textPrimary)
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(K.Colors.backgroundTertiary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(K.Colors.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(K.Layout.padding)
        }
    }
    
    // MARK: - Export Handler
    
    private func handleExport(session: ChatSession, format: ChatSessionRowView.ExportFormat) {
        let url: URL?
        let formatString: String
        
        switch format {
        case .txt:
            url = chatViewModel.exportSessionToTXT(session)
            formatString = "txt"
        case .pdf:
            url = chatViewModel.exportSessionToPDF(session)
            formatString = "pdf"
        }
        
        if let url = url {
            // Track export
            FirebaseService.shared.trackExport(
                format: formatString,
                sessionId: session.id,
                messageCount: session.messageCount
            )
            
            shareURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Chat Group View

struct ChatGroupView: View {
    let groupName: String
    let sessions: [ChatSession]
    let isCollapsed: Bool
    let currentSessionId: String?
    let onToggleCollapse: () -> Void
    let onSelectSession: (ChatSession) -> Void
    let onDeleteSession: (ChatSession) -> Void
    let onRenameSession: (ChatSession, String) -> Void
    let onTogglePin: (ChatSession) -> Void
    let onToggleImportant: (ChatSession) -> Void
    let onToggleArchive: (ChatSession) -> Void
    let onShare: (ChatSession, ChatSessionRowView.ExportFormat) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Group header
            Button(action: {
                HapticFeedback.light()
                onToggleCollapse()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(K.Colors.textSecondary)
                        .frame(width: 12)
                    
                    Text(groupName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(K.Colors.textSecondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text("\(sessions.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(K.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(K.Colors.backgroundTertiary)
                        .cornerRadius(10)
                }
                .padding(.horizontal, K.Layout.padding)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Group items
            if !isCollapsed {
                ForEach(sessions) { session in
                    ChatSessionRowView(
                        session: session,
                        isSelected: currentSessionId == session.id,
                        onTap: {
                            HapticFeedback.light()
                            onSelectSession(session)
                        },
                        onDelete: {
                            HapticFeedback.medium()
                            onDeleteSession(session)
                        },
                        onRename: { newTitle in
                            onRenameSession(session, newTitle)
                        },
                        onTogglePin: {
                            HapticFeedback.light()
                            onTogglePin(session)
                        },
                        onToggleImportant: {
                            HapticFeedback.light()
                            onToggleImportant(session)
                        },
                        onToggleArchive: {
                            HapticFeedback.light()
                            onToggleArchive(session)
                        },
                        onShare: { format in
                            onShare(session, format)
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(
            showSidebar: .constant(true),
            showLanguageSelection: .constant(false)
        )
        .environmentObject(ChatViewModel())
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
    }
}
