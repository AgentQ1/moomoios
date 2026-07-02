//
//  LoginView.swift
//  MoomoAI
//
//  Welcome screen — designed to feel calm, premium, intelligent, and timeless.
//  Warm-white canvas, a softly breathing ambient halo, an elegant serif Moomo
//  wordmark, and three sign-in options of identical visual weight (Google,
//  Apple, Guest). All auth actions route through the shared AuthService.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

    // Brand palette (fixed — this is a deliberately light, branded canvas).
    private let canvas = Color(hex: "FAF8F5")
    private let royalPurple = Color(hex: "432874")
    private let violet = Color(hex: "8B5CF6")
    private let gold = Color(hex: "C2A878")
    private let subtitle = Color(hex: "8A8694")

    @State private var breathe = false

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                // Logo cluster framed by the breathing halo.
                ZStack {
                    AmbientHalo(breathe: breathe, violet: violet, gold: gold)
                        .frame(width: 340, height: 340)
                        .offset(y: 14)

                    VStack(spacing: 0) {
                        sparkleStack
                            .padding(.bottom, 18)

                        welcomeKicker
                            .padding(.bottom, 10)

                        wordmark
                    }
                }
                .frame(height: 340)

                Text("Your way to smarter, happier connections.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 6)

                divider
                    .padding(.top, 22)

                Spacer(minLength: 28)

                // Three identical sign-in options.
                VStack(spacing: 14) {
                    AuthButtonRow(
                        title: "Continue with Google",
                        icon: .google,
                        textColor: royalPurple,
                        borderColor: Color(hex: "ECE8F5")
                    ) {
                        authService.errorMessage = nil
                        authService.signInWithGoogle()
                    }

                    AuthButtonRow(
                        title: "Continue with Apple",
                        icon: .apple,
                        textColor: royalPurple,
                        borderColor: Color(hex: "ECE8F5")
                    ) {
                        authService.errorMessage = nil
                        authService.signInWithApple()
                    }

                    AuthButtonRow(
                        title: "Continue as Guest",
                        icon: .guest(royalPurple),
                        textColor: royalPurple,
                        borderColor: Color(hex: "ECE8F5")
                    ) {
                        authService.errorMessage = nil
                        authService.continueAsGuest()
                    }
                }
                .padding(.horizontal, 32)

                if authService.isLoading {
                    ProgressView()
                        .tint(royalPurple)
                        .padding(.top, 16)
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                }

                Spacer(minLength: 24)

                pageDots
                    .padding(.bottom, 24)

                legal
                    .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.light)
        .onAppear { breathe = true }
    }

    // MARK: - Logo cluster

    private var sparkleStack: some View {
        VStack(spacing: 2) {
            SparkleShape().fill(violet).frame(width: 22, height: 22)
            SparkleShape().fill(gold.opacity(0.85)).frame(width: 11, height: 11)
        }
    }

    private var welcomeKicker: some View {
        HStack(spacing: 10) {
            Rectangle().fill(gold.opacity(0.6)).frame(width: 18, height: 1)
            Text("WELCOME TO")
                .font(.system(size: 12, weight: .semibold))
                .tracking(4)
                .foregroundColor(gold)
            Rectangle().fill(gold.opacity(0.6)).frame(width: 18, height: 1)
        }
    }

    private var wordmark: some View {
        Text("Moomo")
            .font(.system(size: 66, weight: .bold, design: .serif))
            .foregroundColor(royalPurple)
            .overlay(alignment: .topTrailing) {
                SparkleShape()
                    .fill(gold)
                    .frame(width: 16, height: 16)
                    .offset(x: 14, y: 2)
            }
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(gold.opacity(0.45)).frame(width: 44, height: 1)
            SparkleShape().fill(gold).frame(width: 9, height: 9)
            Rectangle().fill(gold.opacity(0.45)).frame(width: 44, height: 1)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 9) {
            ForEach(0..<3, id: \.self) { _ in dot }
            SparkleShape().fill(violet).frame(width: 14, height: 14)
            ForEach(0..<3, id: \.self) { _ in dot }
        }
    }

    private var dot: some View {
        Circle().fill(Color.black.opacity(0.12)).frame(width: 5, height: 5)
    }

    private var legal: some View {
        VStack(spacing: 6) {
            Text("By continuing, you agree to our")
                .font(.system(size: 12))
                .foregroundColor(subtitle)

            HStack(spacing: 4) {
                Link("Privacy Policy", destination: URL(string: "https://moomopro-72876.web.app/privacy-policy.html")!)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(royalPurple)
                Text("and").font(.system(size: 12)).foregroundColor(subtitle)
                Link("Terms of Service", destination: URL(string: "https://moomopro-72876.web.app/terms-of-service.html")!)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(royalPurple)
            }
        }
    }
}

// MARK: - Login option button (identical visual weight for all three)

struct AuthButtonRow: View {
    enum IconKind {
        case google
        case apple
        case guest(Color)
    }

    let title: String
    let icon: IconKind
    let textColor: Color
    let borderColor: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.light()
            action()
        } label: {
            ZStack {
                // Icon pinned left, arrow pinned right.
                HStack {
                    ZStack {
                        Circle().fill(Color(hex: "F5F2FB")).frame(width: 36, height: 36)
                        iconView
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
                // Title centered within the full button width.
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressableScaleStyle())
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .google:
            GoogleGGlyph(size: 20)
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.black)
        case .guest(let color):
            Image(systemName: "person.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
        }
    }
}

/// Scales to 0.98 on press with a soft spring (per design spec).
private struct PressableScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Ambient halo

private struct AmbientHalo: View {
    let breathe: Bool
    let violet: Color
    let gold: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(violet.opacity(0.16))
                .frame(width: 230, height: 230)
                .blur(radius: 70)
                .offset(x: -92, y: -26)
            Circle()
                .fill(gold.opacity(0.18))
                .frame(width: 230, height: 230)
                .blur(radius: 70)
                .offset(x: 96, y: -8)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            violet.opacity(0.55),
                            gold.opacity(0.55),
                            Color.white.opacity(0.0),
                            violet.opacity(0.35),
                        ]),
                        center: .center,
                        angle: .degrees(-90)
                    ),
                    lineWidth: 1.4
                )
                .frame(width: 320, height: 320)
        }
        .scaleEffect(breathe ? 1.05 : 0.97)
        .opacity(breathe ? 1.0 : 0.82)
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: breathe)
    }
}

// MARK: - Google "G" glyph (multicolor, drawn — no trademark asset bundled)

struct GoogleGGlyph: View {
    var size: CGFloat = 20

    private let blue = Color(hex: "4285F4")
    private let red = Color(hex: "EA4335")
    private let yellow = Color(hex: "FBBC05")
    private let green = Color(hex: "34A853")

    var body: some View {
        let lineWidth = size * 0.26
        ZStack {
            Circle().trim(from: 0.03, to: 0.24).stroke(green, style: StrokeStyle(lineWidth: lineWidth))
            Circle().trim(from: 0.25, to: 0.49).stroke(yellow, style: StrokeStyle(lineWidth: lineWidth))
            Circle().trim(from: 0.50, to: 0.74).stroke(red, style: StrokeStyle(lineWidth: lineWidth))
            Circle().trim(from: 0.75, to: 0.96).stroke(blue, style: StrokeStyle(lineWidth: lineWidth))
            // Blue crossbar of the "G"
            Rectangle()
                .fill(blue)
                .frame(width: size * 0.40, height: lineWidth)
                .offset(x: size * 0.21)
        }
        .frame(width: size, height: size)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView().environmentObject(AuthService())
    }
}
