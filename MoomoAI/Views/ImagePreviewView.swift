//
//  ImagePreviewView.swift
//  MoomoAI
//
//  Full-screen image viewer with pinch-to-zoom, double-tap zoom, pan, a close
//  button, and share / save-to-Photos actions. Works for both AI-generated
//  images (remote URL, served through the cache) and attached images (local
//  UIImage). The originating prompt/caption is shown beneath the image.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Source of a previewable image.
enum ImageSource: Equatable {
    case remote(URL)
    case local(UIImage)

    static func == (lhs: ImageSource, rhs: ImageSource) -> Bool {
        switch (lhs, rhs) {
        case let (.remote(a), .remote(b)): return a == b
        case let (.local(a), .local(b)): return a === b
        default: return false
        }
    }
}

struct ImagePreviewView: View {
    let source: ImageSource
    var caption: String? = nil
    /// When set, a Report control is shown (AI-generated images only).
    var report: ReportableContent? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var uiImage: UIImage?
    @State private var loadFailed = false

    // Zoom / pan state
    @State private var scale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var showShareSheet = false
    @State private var saveToast: String?
    @State private var showControls = true
    @State private var reportTarget: ReportableContent?

    private let maxScale: CGFloat = 5
    private let minScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage {
                imageLayer(uiImage)
            } else if loadFailed {
                failureState
            } else {
                ProgressView().tint(.white)
            }

            controlsOverlay
        }
        .statusBarHidden(true)
        .onAppear(perform: loadImage)
        .sheet(isPresented: $showShareSheet) {
            if let uiImage { ShareSheet(items: [uiImage]) }
        }
        .sheet(item: $reportTarget) { target in
            ReportContentView(content: target)
        }
    }

    // MARK: - Image + gestures

    private func imageLayer(_ image: UIImage) -> some View {
        let effectiveScale = max(minScale, scale * gestureScale)

        return Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(effectiveScale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in state = value }
                    .onEnded { value in
                        scale = min(max(scale * value, minScale), maxScale)
                        if scale <= minScale { resetZoom() }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard effectiveScale > 1 else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if scale > 1 { resetZoom() } else { scale = 2.5 }
                }
            }
            .onTapGesture {
                withAnimation { showControls.toggle() }
            }
            .ignoresSafeArea()
    }

    private func resetZoom() {
        scale = 1
        offset = .zero
        lastOffset = .zero
    }

    private var failureState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.6))
            Text("Couldn’t load image")
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            // Top bar: close
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Bottom bar: caption + actions
            if showControls {
                VStack(spacing: 12) {
                    if let caption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 24)
                    }

                    HStack(spacing: 28) {
                        actionButton(icon: "square.and.arrow.up", label: "Share") {
                            showShareSheet = true
                        }
                        .disabled(uiImage == nil)
                        .opacity(uiImage == nil ? 0.4 : 1)

                        actionButton(icon: "square.and.arrow.down", label: "Save") {
                            saveToPhotos()
                        }
                        .disabled(uiImage == nil)
                        .opacity(uiImage == nil ? 0.4 : 1)

                        // Report stays enabled even if the thumbnail failed to
                        // load — the content is still reportable (Guideline 1.2).
                        if let report {
                            actionButton(icon: "flag", label: "Report") {
                                reportTarget = report
                            }
                        }
                    }
                }
                .padding(.bottom, 28)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .center) {
            if let saveToast {
                Text(saveToast)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .transition(.opacity)
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadImage() {
        switch source {
        case .local(let image):
            uiImage = image
        case .remote(let url):
            ImageCache.shared.load(url) { image in
                if let image { uiImage = image } else { loadFailed = true }
            }
        }
    }

    private func saveToPhotos() {
        guard let uiImage else { return }
        PhotoSaver.shared.save(uiImage) { success in
            HapticFeedback.success()
            withAnimation { saveToast = success ? "Saved to Photos" : "Couldn’t save" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { saveToast = nil }
            }
        }
    }
}

// MARK: - Photo saver

/// Tiny wrapper around UIImageWriteToSavedPhotosAlbum that reports completion.
/// Requires NSPhotoLibraryAddUsageDescription in Info.plist.
final class PhotoSaver: NSObject {
    static let shared = PhotoSaver()
    private var completion: ((Bool) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion?(error == nil)
        completion = nil
    }
}
