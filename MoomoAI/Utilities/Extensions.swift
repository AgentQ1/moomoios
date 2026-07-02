//
//  Extensions.swift
//  MoomoAI
//
//  Useful extensions
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - String Extensions
extension String {
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func containsIgnoringCase(_ other: String) -> Bool {
        self.lowercased().contains(other.lowercased())
    }
}

// MARK: - Shimmer (loading skeletons)

private struct ShimmerModifier: ViewModifier {
    @State private var animating = false
    func body(content: Content) -> some View {
        content
            .opacity(animating ? 0.4 : 0.85)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
    }
}

extension View {
    /// A subtle pulsing effect used on placeholder cells while content loads.
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Color hex

extension Color {
    /// Create a Color from a hex string like "#FAF8F5" or "FAF8F5".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - UIImage downscaling (compress large uploads)

#if canImport(UIKit)
extension UIImage {
    /// Returns a copy scaled so its longest side is at most `maxDimension`.
    /// Caps the resolution of large photos before they enter the upload pipeline.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return self }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
#endif
