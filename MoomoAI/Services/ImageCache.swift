//
//  ImageCache.swift
//  MoomoAI
//
//  Lightweight two-tier (memory + disk) image cache plus a drop-in cached image
//  loader used instead of AsyncImage for generated images. Caching makes chat and
//  Library scrolling smooth (no re-downloads) and keeps local chat persistence
//  small by storing attached-image thumbnails on disk instead of in UserDefaults.
//
//  Design notes:
//  - Disk keys are SHA-256 of the URL string. (They were previously derived from
//    String.hashValue, which is seeded per launch — the disk cache could never
//    hit across launches and orphaned files accumulated forever.)
//  - Decodes are downsampled via ImageIO so a single oversized image can't pin
//    tens of MB of pixels, and the memory cache is byte-bounded.
//  - Concurrent requests for the same URL share one download.
//

import SwiftUI
import CryptoKit
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let remoteDir: URL
    private let thumbDir: URL
    private let io = DispatchQueue(label: "com.moomo.imagecache", qos: .utility)

    /// Callbacks waiting on an in-flight load, keyed by URL. Guarded by `lock`.
    private let lock = NSLock()
    private var inFlight: [URL: [(UIImage?) -> Void]] = [:]

    /// Largest edge we ever decode into memory. Generated images are ~1024px;
    /// this keeps full-screen zoom crisp while bounding worst-case decodes.
    private static let maxDecodePixels: CGFloat = 2048

    private init() {
        memory.countLimit = 150
        memory.totalCostLimit = 96 * 1024 * 1024  // ~96 MB of decoded pixels
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        remoteDir = caches.appendingPathComponent("moomo-remote-images", isDirectory: true)
        thumbDir = caches.appendingPathComponent("moomo-msg-thumbs", isDirectory: true)
        for dir in [remoteDir, thumbDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // One-time sweep of files written under the old per-launch hash naming —
        // they can never be read back and would otherwise accumulate forever.
        io.async { [remoteDir] in
            let files = (try? FileManager.default.contentsOfDirectory(at: remoteDir, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.lastPathComponent.count != 68 { // 64 hex + ".img"
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Remote images (by URL)

    /// Synchronous memory-cache lookup only (no disk I/O — safe on the main thread).
    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url.absoluteString as NSString)
    }

    /// Load an image from memory, disk, or network — in that order. Disk reads and
    /// decodes run off the main thread; concurrent requests for the same URL are
    /// coalesced into one download. Completion is delivered on the main queue.
    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cachedImage(for: url) {
            completion(cached)
            return
        }

        lock.lock()
        if inFlight[url] != nil {
            inFlight[url]?.append(completion)
            lock.unlock()
            return
        }
        inFlight[url] = [completion]
        lock.unlock()

        let fileURL = remoteDir.appendingPathComponent(Self.fileName(for: url.absoluteString))
        io.async { [weak self] in
            guard let self else { return }
            if let data = try? Data(contentsOf: fileURL),
               let image = Self.decodeDownsampled(data: data) {
                self.store(image, key: url.absoluteString)
                self.finish(url, with: image)
                return
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self else { return }
                guard let data, let image = Self.decodeDownsampled(data: data) else {
                    self.finish(url, with: nil)
                    return
                }
                self.store(image, key: url.absoluteString)
                self.io.async {
                    try? data.write(to: fileURL, options: .atomic)
                }
                self.finish(url, with: image)
            }.resume()
        }
    }

    private func store(_ image: UIImage, key: String) {
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        memory.setObject(image, forKey: key as NSString, cost: cost)
    }

    private func finish(_ url: URL, with image: UIImage?) {
        lock.lock()
        let callbacks = inFlight.removeValue(forKey: url) ?? []
        lock.unlock()
        DispatchQueue.main.async {
            callbacks.forEach { $0(image) }
        }
    }

    // MARK: - Attached-image thumbnails (by message id, persisted across launches)

    func storeThumbnail(_ data: Data, id: String) {
        io.async { [thumbDir] in
            try? data.write(to: thumbDir.appendingPathComponent("\(id).jpg"), options: .atomic)
        }
    }

    /// Decoded thumbnail for a message, memory-cached. `data` (when the message
    /// still carries its bytes) wins; otherwise falls back to the on-disk copy —
    /// which is how thumbnails survive cloud hydration replacing the message.
    func messageThumbnail(id: String, data: Data?) -> UIImage? {
        let key = "thumb:\(id)" as NSString
        if let cached = memory.object(forKey: key) { return cached }
        let bytes = data ?? (try? Data(contentsOf: thumbDir.appendingPathComponent("\(id).jpg")))
        guard let bytes, let image = UIImage(data: bytes) else { return nil }
        store(image, key: "thumb:\(id)")
        return image
    }

    func hasThumbnail(id: String) -> Bool {
        FileManager.default.fileExists(atPath: thumbDir.appendingPathComponent("\(id).jpg").path)
    }

    /// Raw persisted thumbnail bytes for a message — used to rebuild multimodal
    /// request context (follow-ups, regenerate) after persistence stripped the
    /// inline copy from the message.
    func thumbnailData(id: String) -> Data? {
        try? Data(contentsOf: thumbDir.appendingPathComponent("\(id).jpg"))
    }

    /// Remove all persisted message thumbnails (sign-out / account switch).
    func clearThumbnails() {
        io.async { [thumbDir] in
            let files = (try? FileManager.default.contentsOfDirectory(at: thumbDir, includingPropertiesForKeys: nil)) ?? []
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    // MARK: - Helpers

    private static func fileName(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".img"
    }

    /// Decode image data capped at `maxDecodePixels` on its longest edge, via
    /// ImageIO thumbnailing (never inflates the full-resolution bitmap).
    private static func decodeDownsampled(data: Data) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDecodePixels,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
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
            image = loaded
        }
    }
}
