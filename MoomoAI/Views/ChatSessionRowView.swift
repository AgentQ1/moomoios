//
//  ChatSessionRowView.swift
//  MoomoAI
//
//  Individual chat session row in sidebar - matches web app chat list items
//

import SwiftUI

struct ChatSessionRowView: View {
    let session: ChatSession
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onTogglePin: () -> Void
    let onToggleImportant: () -> Void
    let onToggleArchive: () -> Void
    let onShare: (ExportFormat) -> Void
    
    @State private var showRenameAlert = false
    @State private var newTitle = ""
    @State private var showContextMenu = false
    @State private var showShareAlert = false
    
    enum ExportFormat {
        case txt
        case pdf
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Chat icon
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? K.Colors.accentColor : K.Colors.textSecondary)
                    .frame(width: 24)
                
                // Title and preview
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(session.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(K.Colors.textPrimary)
                            .lineLimit(1)
                        
                        // Pin indicator
                        if session.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(K.Colors.accentColor)
                        }
                    }
                    
                    if !session.messages.isEmpty {
                        Text(session.preview)
                            .font(.system(size: 12))
                            .foregroundColor(K.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Context menu button
                Button(action: { showContextMenu = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(K.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, K.Layout.padding)
            .padding(.vertical, 10)
            .background(isSelected ? K.Colors.backgroundTertiary : Color.clear)
            .cornerRadius(K.Layout.smallCornerRadius)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .contextMenu {
            contextMenuContent
        }
        .alert("Rename Chat", isPresented: $showRenameAlert) {
            TextField("New title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if !newTitle.trimmed.isEmpty {
                    onRename(newTitle.trimmed)
                }
            }
        }
        .confirmationDialog("Chat Options", isPresented: $showContextMenu) {
            Button(session.isPinned ? "Unpin" : "Pin") {
                onTogglePin()
            }
            Button(session.isImportant ? "Remove from Important" : "Mark as Important") {
                onToggleImportant()
            }
            Button(session.isArchived ? "Unarchive" : "Archive") {
                onToggleArchive()
            }
            Button("Rename") {
                newTitle = session.title
                showRenameAlert = true
            }
            Button("Share") {
                showShareAlert = true
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Share Format", isPresented: $showShareAlert) {
            Button("Text File (.txt)") {
                onShare(.txt)
            }
            Button("PDF Document (.pdf)") {
                onShare(.pdf)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var contextMenuContent: some View {
        Group {
            Button(action: onTogglePin) {
                Label(session.isPinned ? "Unpin" : "Pin", systemImage: session.isPinned ? "pin.slash" : "pin")
            }
            
            Button(action: onToggleImportant) {
                Label(session.isImportant ? "Remove from Important" : "Mark as Important", systemImage: session.isImportant ? "star.slash" : "star")
            }
            
            Button(action: onToggleArchive) {
                Label(session.isArchived ? "Unarchive" : "Archive", systemImage: session.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            
            Button(action: {
                newTitle = session.title
                showRenameAlert = true
            }) {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(action: {
                showShareAlert = true
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct ChatSessionRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatSessionRowView(
                session: ChatSession.sample,
                isSelected: true,
                onTap: {},
                onDelete: {},
                onRename: { _ in },
                onTogglePin: {},
                onToggleImportant: {},
                onToggleArchive: {},
                onShare: { _ in }
            )
            
            ChatSessionRowView(
                session: ChatSession.sample,
                isSelected: false,
                onTap: {},
                onDelete: {},
                onRename: { _ in },
                onTogglePin: {},
                onToggleImportant: {},
                onToggleArchive: {},
                onShare: { _ in }
            )
        }
        .background(K.Colors.backgroundSecondary)
        .preferredColorScheme(.dark)
    }
}
