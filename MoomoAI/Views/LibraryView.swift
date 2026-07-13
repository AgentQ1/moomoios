//
//  LibraryView.swift
//  MoomoAI
//
//  Library of everything a user has created or uploaded (generated images,
//  edited images, uploaded files) — everything except plain text. Supports grid
//  view, type filter, search, full-screen image preview, asset detail, and
//  paginated loading with loading skeletons.
//

import SwiftUI

// MARK: - Store

@MainActor
final class LibraryStore: ObservableObject {
    @Published var assets: [LibraryAsset] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published private(set) var reachedEnd = false

    private var lastPage: AssetLibraryService.Page?
    private let pageSize = 30

    func loadInitial() async {
        guard assets.isEmpty else { return }
        isLoading = true
        let page = await AssetLibraryService.shared.loadAssets(pageSize: pageSize)
        assets = page.assets
        lastPage = page
        reachedEnd = page.reachedEnd
        isLoading = false
    }

    func refresh() async {
        let page = await AssetLibraryService.shared.loadAssets(pageSize: pageSize)
        assets = page.assets
        lastPage = page
        reachedEnd = page.reachedEnd
    }

    func loadMoreIfNeeded(current asset: LibraryAsset) async {
        guard !reachedEnd, !isLoadingMore, let last = assets.last, last.id == asset.id else { return }
        isLoadingMore = true
        let page = await AssetLibraryService.shared.loadAssets(pageSize: pageSize, after: lastPage?.cursor)
        assets.append(contentsOf: page.assets)
        lastPage = page
        reachedEnd = page.reachedEnd
        isLoadingMore = false
    }

    func delete(_ asset: LibraryAsset) {
        assets.removeAll { $0.id == asset.id }
        AssetLibraryService.shared.deleteAsset(id: asset.id)
    }
}

// MARK: - Filter

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case images = "Images"
    case edited = "Edited"
    case files = "Files"

    var id: String { rawValue }

    func matches(_ asset: LibraryAsset) -> Bool {
        switch self {
        case .all: return true
        case .images: return asset.type == .generatedImage
        case .edited: return asset.type == .editedImage
        case .files: return asset.type == .uploadedFile
        }
    }
}

// MARK: - Library View

struct LibraryView: View {
    @StateObject private var store = LibraryStore()
    @Environment(\.dismiss) private var dismiss

    @State private var filter: LibraryFilter
    @State private var searchText = ""
    @State private var previewAsset: LibraryAsset?
    @State private var detailAsset: LibraryAsset?

    init(initialFilter: LibraryFilter = .all) {
        _filter = State(initialValue: initialFilter)
    }

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 10)]

    private var visibleAssets: [LibraryAsset] {
        store.assets.filter { asset in
            guard filter.matches(asset) else { return false }
            guard !searchText.isEmpty else { return true }
            return asset.prompt.containsIgnoringCase(searchText)
                || (asset.name?.containsIgnoringCase(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                content
            }
            .background(K.Colors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search by prompt or name")
        }
        .task { await store.loadInitial() }
        .fullScreenCover(item: $previewAsset) { asset in
            if let urlString = asset.url, let url = URL(string: urlString) {
                ImagePreviewView(source: .remote(url), caption: asset.prompt)
            }
        }
        .sheet(item: $detailAsset) { asset in
            AssetDetailView(asset: asset)
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { item in
                    Button(action: {
                        HapticFeedback.light()
                        withAnimation(.spring(response: 0.3)) { filter = item }
                    }) {
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(filter == item ? .white : K.Colors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(filter == item ? K.Colors.accentColor : K.Colors.backgroundTertiary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            skeletonGrid
        } else if visibleAssets.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(visibleAssets) { asset in
                        LibraryCell(asset: asset)
                            .onTapGesture { open(asset) }
                            .contextMenu {
                                Button(role: .destructive) { store.delete(asset) } label: {
                                    Label("Remove from Library", systemImage: "trash")
                                }
                            }
                            .task { await store.loadMoreIfNeeded(current: asset) }
                    }
                }
                .padding(16)

                if store.isLoadingMore {
                    ProgressView().tint(K.Colors.textSecondary).padding(.bottom, 20)
                }
            }
            .refreshable { await store.refresh() }
        }
    }

    private var skeletonGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<9, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(K.Colors.backgroundTertiary)
                        .aspectRatio(1, contentMode: .fit)
                        .shimmer()
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.stack")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(K.Colors.textSecondary.opacity(0.6))
            Text(searchText.isEmpty ? "Nothing here yet" : "No matches")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(K.Colors.textPrimary)
            Text(searchText.isEmpty
                 ? "Generated images, edits, and uploaded files will appear here."
                 : "Try a different search.")
                .font(.system(size: 14))
                .foregroundColor(K.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func open(_ asset: LibraryAsset) {
        HapticFeedback.light()
        if asset.type.isImage, asset.url != nil {
            previewAsset = asset
        } else {
            detailAsset = asset
        }
    }
}

// MARK: - Library Cell

private struct LibraryCell: View {
    let asset: LibraryAsset

    var body: some View {
        // Reserve a fixed square first, then draw the (possibly oversized)
        // content inside it — scaledToFill alone would push the cell past its
        // grid slot and overlap neighbors.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(cellContent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomLeading) {
                if asset.type == .editedImage {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(K.Colors.borderColor.opacity(0.3), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var cellContent: some View {
        if asset.type.isImage, let urlString = asset.url, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Rectangle().fill(K.Colors.backgroundTertiary)
                    ProgressView().tint(K.Colors.textSecondary)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: asset.type.systemImage)
                    .font(.system(size: 26))
                    .foregroundColor(K.Colors.accentColor)
                Text(asset.name ?? asset.type.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(K.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(K.Colors.backgroundTertiary)
        }
    }
}

// MARK: - Asset Detail (for files / non-image assets)

struct AssetDetailView: View {
    let asset: LibraryAsset
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: asset.type.systemImage)
                            .font(.system(size: 26))
                            .foregroundColor(K.Colors.accentColor)
                            .frame(width: 48, height: 48)
                            .background(K.Colors.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(asset.name ?? asset.type.title)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                            Text(asset.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !asset.prompt.isEmpty {
                    Section("Prompt") { Text(asset.prompt) }
                }
                if let mime = asset.mimeType {
                    Section("Type") { Text(mime) }
                }
                if let model = asset.model {
                    Section("Model") { Text(model) }
                }
            }
            .navigationTitle("Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
