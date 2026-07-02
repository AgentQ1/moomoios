//
//  ImageCache.swift
//  MoomoAI
//
//  Lightweight two-tier (memory + disk) image cache plus a drop-in cached image
//  loader used instead of AsyncImage for generated images. Caching makes chat and
//  Library scrolling smooth (no re-downloads) and keeps local chat persistence
//  small by storing attached-image thumbnails on disk instead of in UserDefaults.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let remoteDir: URL
    private let thumbDir: URL
    private let io = DispatchQueue(label: "com.moomo.imagecache", qos: .utility)

    private init() {
        memory.countLimit = 150
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        remoteDir = caches.appendingPathComponent("moomo-remote-images", isDirectory: true)
        thumbDir = caches.appendingPathComponent("moomo-msg-thumbs", isDirectory: true)
        for dir in [remoteDir, thumbDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Remote images (by URL)

    func cachedImage(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        if let image = memory.object(forKey: key) { return image }
        let fileURL = remoteDir.appendingPathComponent(Self.fileName(for: url.absoluteString))
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key)
        return image
    }

    /// Load an image from cache or network. Completion is delivered on the main queue.
    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cachedImage(for: url) {
            completion(cached)
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.memory.setObject(image, forKey: url.absoluteString as NSString)
            self.io.async {
                let fileURL = self.remoteDir.appendingPathComponent(Self.fileName(for: url.absoluteString))
                try? data.write(to: fileURL, options: .atomic)
            }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    // MARK: - Attached-image thumbnails (by message id, persisted across launches)

    func storeThumbnail(_ data: Data, id: String) {
        io.async { [thumbDir] in
            try? data.write(to: thumbDir.appendingPathComponent("\(id).jpg"), options: .atomic)
        }
    }

    func loadThumbnail(id: String) -> Data? {
        try? Data(contentsOf: thumbDir.appendingPathComponent("\(id).jpg"))
    }

    func hasThumbnail(id: String) -> Bool {
        FileManager.default.fileExists(atPath: thumbDir.appendingPathComponent("\(id).jpg").path)
    }

    private static func fileName(for key: String) -> String {
        // Stable, filesystem-safe name from the URL string.
        String(UInt64(bitPattern: Int64(key.hashValue))) + ".img"
    }
}

// MARK: - Cached async image view

/// AsyncImage replacement that serves from the shared two-tier cache. Avoids the
/// flicker / re-download AsyncImage causes when cells are recycled while scrolling.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var failed = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard image == nil, let url else { return }
        if let cached = ImageCache.shared.cachedImage(for: url) {
            image = cached
            return
        }
        ImageCache.shared.load(url) { loaded in
            if let loaded { image = loaded } else { failed = true }
        }
    }
}
