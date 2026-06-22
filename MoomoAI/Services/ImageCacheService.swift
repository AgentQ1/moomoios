//
//  ImageCacheService.swift
//  MoomoAI
//
//  High-performance image caching service with memory and disk cache
//  Dramatically improves News feature performance by preventing re-downloads
//

import Foundation
import UIKit

class ImageCacheService {
    static let shared = ImageCacheService()
    
    // MARK: - Cache Layers
    
    /// In-memory cache for instant access (limit: 50MB)
    private let memoryCache = NSCache<NSString, UIImage>()
    
    /// Disk cache for persistent storage
    private let diskCacheURL: URL
    
    /// Queue for disk operations
    private let diskQueue = DispatchQueue(label: "com.moomo.imagecache", qos: .utility)
    
    /// Active download tasks to prevent duplicate downloads
    private var downloadTasks: [String: Task<UIImage, Error>] = [:]
    private let taskLock = NSLock()
    
    // MARK: - Configuration
    
    private let maxMemoryCost = 50 * 1024 * 1024 // 50MB
    private let maxDiskCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let maxDiskCacheSize = 200 * 1024 * 1024 // 200MB
    
    // MARK: - Initialization
    
    private init() {
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCost
        memoryCache.countLimit = 100 // Max 100 images in memory
        
        // Setup disk cache directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDir.appendingPathComponent("NewsImageCache", isDirectory: true)
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Clean old cache on init
        cleanExpiredDiskCache()
        
        // Setup memory warning observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Load image from cache or download if not cached
    /// - Parameter urlString: The image URL
    /// - Returns: UIImage if successful, nil otherwise
    func loadImage(from urlString: String) async throws -> UIImage {
        let cacheKey = cacheKeyForURL(urlString)
        
        // 1. Check memory cache (fastest - < 1ms)
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }
        
        // 2. Check if download is already in progress
        taskLock.lock()
        if let existingTask = downloadTasks[cacheKey] {
            taskLock.unlock()
            return try await existingTask.value
        }
        taskLock.unlock()
        
        // 3. Check disk cache (fast - 5-10ms)
        if let diskImage = await loadFromDisk(cacheKey: cacheKey) {
            // Save to memory for next time
            saveToMemory(image: diskImage, key: cacheKey)
            return diskImage
        }
        
        // 4. Download from network (slow - 100-500ms)
        let downloadTask = Task<UIImage, Error> {
            try await downloadImage(from: urlString, cacheKey: cacheKey)
        }
        
        // Store active download task
        taskLock.lock()
        downloadTasks[cacheKey] = downloadTask
        taskLock.unlock()
        
        do {
            let image = try await downloadTask.value
            
            // Cleanup task
            taskLock.lock()
            downloadTasks.removeValue(forKey: cacheKey)
            taskLock.unlock()
            
            return image
        } catch {
            // Cleanup failed task
            taskLock.lock()
            downloadTasks.removeValue(forKey: cacheKey)
            taskLock.unlock()
            
            throw error
        }
    }
    
    /// Prefetch images in background (for scroll performance)
    func prefetchImages(urls: [String]) {
        Task.detached(priority: .utility) {
            for urlString in urls {
                try? await self.loadImage(from: urlString)
            }
        }
    }
    
    /// Clear all cached images
    func clearCache() {
        memoryCache.removeAllObjects()
        
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.diskCacheURL)
            try? FileManager.default.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }
    }
    
    /// Get current cache size
    func getCacheSize() -> (memory: Int, disk: Int) {
        let memorySize = memoryCache.totalCostLimit
        
        var diskSize = 0
        diskQueue.sync {
            if let enumerator = FileManager.default.enumerator(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        diskSize += fileSize
                    }
                }
            }
        }
        
        return (memory: memorySize, disk: diskSize)
    }
    
    // MARK: - Private Methods
    
    /// Generate cache key from URL
    private func cacheKeyForURL(_ urlString: String) -> String {
        // Use hash to create shorter, filesystem-safe key
        return urlString.data(using: .utf8)?.base64EncodedString().replacingOccurrences(of: "/", with: "_") ?? urlString
    }
    
    /// Download image from network
    private func downloadImage(from urlString: String, cacheKey: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw ImageCacheError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }
        
        // Optimize image size if too large (reduce memory footprint)
        let optimizedImage = optimizeImage(image)
        
        // Save to both caches
        saveToMemory(image: optimizedImage, key: cacheKey)
        await saveToDisk(image: optimizedImage, cacheKey: cacheKey)
        
        return optimizedImage
    }
    
    /// Save image to memory cache
    private func saveToMemory(image: UIImage, key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Rough memory size
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    /// Load image from disk cache
    private func loadFromDisk(cacheKey: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let fileURL = self.diskCacheURL.appendingPathComponent(cacheKey)
                
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Check if file is expired
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let modificationDate = attributes[.modificationDate] as? Date,
                   Date().timeIntervalSince(modificationDate) > self.maxDiskCacheAge {
                    try? FileManager.default.removeItem(at: fileURL)
                    continuation.resume(returning: nil)
                    return
                }
                
                // Load image
                if let data = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Save image to disk cache
    private func saveToDisk(image: UIImage, cacheKey: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            diskQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let fileURL = self.diskCacheURL.appendingPathComponent(cacheKey)
                
                // Compress image to JPEG for disk storage
                if let data = image.jpegData(compressionQuality: 0.8) {
                    try? data.write(to: fileURL, options: .atomic)
                }
                
                continuation.resume()
            }
        }
    }
    
    /// Optimize image to reduce memory footprint
    private func optimizeImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 800
        let size = image.size
        
        // Don't optimize if already small
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // Render optimized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let optimized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return optimized
    }
    
    /// Clean expired disk cache
    private func cleanExpiredDiskCache() {
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let enumerator = FileManager.default.enumerator(
                at: self.diskCacheURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            ) else { return }
            
            var totalSize = 0
            var filesToRemove: [(URL, Date)] = []
            
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modificationDate = resourceValues.contentModificationDate,
                      let fileSize = resourceValues.fileSize else {
                    continue
                }
                
                totalSize += fileSize
                
                // Mark expired files for removal
                if Date().timeIntervalSince(modificationDate) > self.maxDiskCacheAge {
                    filesToRemove.append((fileURL, modificationDate))
                }
            }
            
            // Remove expired files
            for (fileURL, _) in filesToRemove {
                try? FileManager.default.removeItem(at: fileURL)
            }
            
            // If still over size limit, remove oldest files
            if totalSize > self.maxDiskCacheSize {
                let sortedFiles = filesToRemove.sorted { $0.1 < $1.1 }
                var removedSize = 0
                
                for (fileURL, _) in sortedFiles {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        try? FileManager.default.removeItem(at: fileURL)
                        removedSize += fileSize
                        
                        if totalSize - removedSize <= self.maxDiskCacheSize {
                            break
                        }
                    }
                }
            }
        }
    }
    
    /// Handle memory warnings
    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
        print("⚠️ ImageCache: Cleared memory cache due to memory warning")
    }
}

// MARK: - Error Types

enum ImageCacheError: Error {
    case invalidURL
    case invalidImageData
    case downloadFailed
}
