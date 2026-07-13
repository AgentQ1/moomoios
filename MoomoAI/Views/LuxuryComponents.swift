//
//  LuxuryComponents.swift
//  MoomoAI
//
//  Reusable building blocks for the luxury "warm white + navy + gold" UI.
//  These components are shared across the login, empty-home, and active-chat
//  screens so the brand reads identically everywhere.
//

import SwiftUI

// MARK: - Sparkle (four-point star)

/// A crisp four-point star. Shared by every sparkle accent in the app.
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let waist = r * 0.16  // smaller waist = sharper points
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + waist, y: c.y - waist))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + waist, y: c.y + waist))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - waist, y: c.y + waist))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - waist, y: c.y - waist))
        p.closeSubpath()
        return p
    }
}

/// A filled sparkle at a fixed size — the reusable brand mark.
struct SparkleMark: View {
    var color: Color = K.Colors.gold
    var size: CGFloat = 18

    var body: some View {
        SparkleShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Top-right header button (white circle + gold symbol)

/// What the header circle shows: an SF Symbol, or the brand gold sparkle
/// (the four-point star) — used as the Exit button in Temporary Chat.
enum HeaderCircleIcon: Equatable {
    case symbol(String)
    case sparkle

    /// Stable identity for the crossfade animation between icons.
    var key: String {
        switch self {
        case .symbol(let name): return name
        case .sparkle: return "moomo.sparkle"
        }
    }
}

/// The circular white action button pinned to the top-right of the chat header.
/// The gold symbol inside is caller-supplied so the icon can be state-driven
/// (e.g. Temporary Chat on an empty conversation, New Chat once one is active).
struct HeaderCircleButton: View {
    var icon: HeaderCircleIcon
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(K.Colors.goldSoft.opacity(0.5), lineWidth: 1))
                    .shadow(color: K.Colors.navy.opacity(0.08), radius: 10, x: 0, y: 4)
                // Keyed by the icon identity so an icon change crossfades in
                // place while the circle itself never moves or re-animates.
                iconView
                    .id(icon.key)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
            .frame(width: 44, height: 44)
            .animation(.easeInOut(duration: 0.18), value: icon.key)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(K.Colors.gold)
        case .sparkle:
            SparkleMark(color: K.Colors.gold, size: 18)
        }
    }
}

// MARK: - "— LAB AI —" divider label (active-chat header center)

/// Gold, letter-spaced "LAB AI" flanked by thin gold rules.
struct LabAIHeader: View {
    var lineWidth: CGFloat = 26

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(K.Colors.gold.opacity(0.55)).frame(width: lineWidth, height: 1)
            Text("LAB AI")
                .font(.system(size: 13, weight: .semibold))
                .tracking(4)
                .foregroundColor(K.Colors.gold)
            Rectangle().fill(K.Colors.gold.opacity(0.55)).frame(width: lineWidth, height: 1)
        }
    }
}

// MARK: - Full Moomo brand cluster (empty-home header center)

/// Small gold sparkle • "Moomo" royal-blue serif • "LAB AI" gold rule.
struct MoomoBrandHeader: View {
    var body: some View {
        VStack(spacing: 2) {
            SparkleMark(color: K.Colors.gold, size: 12)
                .padding(.bottom, 2)
            Text("Moomo")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundColor(K.Colors.royalBlue)
            LabAIHeader(lineWidth: 22)
                .padding(.top, 1)
        }
    }
}

// MARK: - Divider with a centered sparkle

/// Thin gold rule • gold sparkle • thin gold rule.
struct MoomoDivider: View {
    var lineWidth: CGFloat = 44

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(K.Colors.gold.opacity(0.45)).frame(width: lineWidth, height: 1)
            SparkleMark(color: K.Colors.gold, size: 9)
            Rectangle().fill(K.Colors.gold.opacity(0.45)).frame(width: lineWidth, height: 1)
        }
    }
}

// MARK: - Warm-white luxury background

/// The shared warm-white canvas with soft ambient glows. Drop behind content.
struct LuxuryBackground: View {
    var body: some View {
        ZStack {
            K.Colors.cream
            // Faint warm glow low-center (matches the empty-home screenshot).
            RadialGradient(
                gradient: Gradient(colors: [K.Colors.gold.opacity(0.10), .clear]),
                center: UnitPoint(x: 0.5, y: 0.60),
                startRadius: 0,
                endRadius: 340
            )
            // Very subtle cool wash near the top.
            RadialGradient(
                gradient: Gradient(colors: [K.Colors.royalBlue.opacity(0.04), .clear]),
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glowing sparkle orb (empty-home centerpiece)

/// A softly glowing halo containing one large royal-blue sparkle and two small
/// gold sparkles — the hero mark on the empty chat home.
struct GlowingSparkleOrb: View {
    var body: some View {
        ZStack {
            // Soft glow halo.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.9), K.Colors.gold.opacity(0.12), .clear]),
                        center: .center,
                        startRadius: 2,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 2)

            // Main royal-blue sparkle.
            SparkleMark(color: K.Colors.royalBlue, size: 44)
                .offset(y: -4)

            // Two smaller gold sparkles.
            SparkleMark(color: K.Colors.gold, size: 18)
                .offset(x: -26, y: 26)
            SparkleMark(color: K.Colors.gold.opacity(0.85), size: 13)
                .offset(x: 24, y: 22)
        }
        .frame(width: 180, height: 180)
    }
}

// MARK: - Read receipt (double check)

/// Two overlapping check marks — the "delivered" indicator on user messages.
struct ReadReceipt: View {
    var color: Color = K.Colors.slate

    var body: some View {
        ZStack {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .offset(x: -3)
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .offset(x: 2)
        }
        .foregroundColor(color)
    }
}

// MARK: - Assistant message action bar

/// copy • thumbs-up • thumbs-down • regenerate, shown beneath assistant replies.
struct MessageActionBar: View {
    var isLiked: Bool
    var isDisliked: Bool
    var onCopy: () -> Void
    var onLike: () -> Void
    var onDislike: () -> Void
    var onRegenerate: (() -> Void)?

    var body: some View {
        HStack(spacing: 22) {
            actionButton(system: "doc.on.doc", filled: false, active: false, action: onCopy)
            actionButton(system: "hand.thumbsup", filled: isLiked, active: isLiked, action: onLike)
            actionButton(system: "hand.thumbsdown", filled: isDisliked, active: isDisliked, action: onDislike)
            if let onRegenerate {
                actionButton(system: "arrow.clockwise", filled: false, active: false, action: onRegenerate)
            }
        }
        .padding(.top, 4)
    }

    private func actionButton(system: String, filled: Bool, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            Image(systemName: filled ? "\(system).fill" : system)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(active ? K.Colors.navy : K.Colors.textSecondary.opacity(0.8))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}
