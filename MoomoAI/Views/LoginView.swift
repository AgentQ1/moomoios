//
//  LoginView.swift
//  MoomoAI
//
//  Welcome screen — the app's single onboarding and legal-consent surface.
//  Warm-ivory canvas, a softly breathing ambient halo, an elegant serif Moomo
//  wordmark, an explicit Privacy Policy / Terms of Service consent checkbox,
//  and three sign-in options of identical visual weight (Google, Apple,
//  Guest). The sign-in options stay visibly disabled until the checkbox is
//  checked; consent is persisted by AuthService only after a sign-in actually
//  succeeds (see AuthService.pendingConsentMethod). All auth actions route
//  through the shared AuthService.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var agreedToLegal = false
    @State private var showConsentHint = false

    // Brand palette (fixed — this is a deliberately light, branded canvas).
    private let canvas = Color(hex: "FCF8F2")       // warm ivory
    private let navy = Color(hex: "253B86")         // primary navy
    private let navyPressed = Color(hex: "1C2F70")  // dark navy (pressed/selected edge)
    private let gold = Color(hex: "C6A46A")         // warm gold
    private let subtitle = Color(hex: "8D8B98")     // secondary text
    private let cardBorder = Color(hex: "EAE4D7")   // warm hairline on white cards

    @State private var breathe = false

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()

            // Scrolls only when the content is taller than the screen
            // (small iPhones, large Dynamic Type sizes).
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    content
                        .frame(minHeight: geo.size.height)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear { breathe = true }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentSheet(
                title: LegalDocuments.privacyPolicyTitle,
                text: LegalDocuments.privacyPolicy
            )
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentSheet(
                title: LegalDocuments.termsOfServiceTitle,
                text: LegalDocuments.termsOfService
            )
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // Logo cluster framed by the breathing halo.
            ZStack {
                AmbientHalo(breathe: breathe, navy: navy, gold: gold)
                    .frame(width: 320, height: 320)
                    .offset(y: 10)

                VStack(spacing: 0) {
                    sparkleStack
                        .padding(.bottom, 18)

                    welcomeKicker
                        .padding(.bottom, 10)

                    wordmark
                }
            }
            // Tall enough to fully contain the 320pt halo at its 1.05×
            // breathing peak (~336pt) so the ring's bottom arc never bleeds
            // into the tagline below.
            .frame(height: 360)

            Text("Your way to smarter, happier connections.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(subtitle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 6)

            // Golden divider line with its small star.
            divider
                .padding(.top, 22)

            // Consent checkbox sits directly below the divider and directly
            // above the sign-in options — checking it is what enables all three.
            consentSection
                .padding(.horizontal, 32)
                .padding(.top, 20)

            // Three identical sign-in options, gated on the consent checkbox.
            VStack(spacing: 14) {
                AuthButtonRow(
                    title: "Continue with Google",
                    icon: .google,
                    textColor: navy,
                    borderColor: cardBorder,
                    isEnabled: agreedToLegal
                ) {
                    attemptSignIn(method: "google") { authService.signInWithGoogle() }
                }

                AuthButtonRow(
                    title: "Continue with Apple",
                    icon: .apple,
                    textColor: navy,
                    borderColor: cardBorder,
                    isEnabled: agreedToLegal
                ) {
                    attemptSignIn(method: "apple") { authService.signInWithApple() }
                }

                AuthButtonRow(
                    title: "Continue as Guest",
                    icon: .guest(navy),
                    textColor: navy,
                    borderColor: cardBorder,
                    isEnabled: agreedToLegal
                ) {
                    attemptSignIn(method: "guest") { authService.continueAsGuest() }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 18)

            if authService.isLoading {
                ProgressView()
                    .tint(navy)
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

            Spacer(minLength: 28)

            pageDots
                .padding(.bottom, 28)
        }
    }

    // MARK: - Consent gating

    /// The consent checkbox is the single agreement method: sign-in only
    /// proceeds once it is checked, and a tap on a dimmed button surfaces a
    /// gentle inline reminder instead of authenticating.
    private func attemptSignIn(method: String, _ start: () -> Void) {
        // Debounce: ignore taps while a sign-in is already running so a second
        // tap can never launch a second auth session.
        guard !authService.isLoading else { return }
        guard agreedToLegal else {
            withAnimation(.easeInOut(duration: 0.2)) { showConsentHint = true }
            return
        }
        showConsentHint = false
        authService.errorMessage = nil
        authService.pendingConsentMethod = method
        start()
    }

    private func toggleConsent() {
        HapticFeedback.light()
        agreedToLegal.toggle()
        if agreedToLegal {
            withAnimation(.easeInOut(duration: 0.2)) { showConsentHint = false }
        }
    }

    private var consentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // 44pt tappable area around the 24pt visual box, pinned to the top
                // so it stays beside the first line as the label wraps at large
                // Dynamic Type sizes (instead of floating to the vertical center).
                Button(action: toggleConsent) {
                    checkboxSquare
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("I have read and agree to the Privacy Policy and Terms of Service")
                .accessibilityValue(agreedToLegal ? "Checked" : "Unchecked")

                // One wrapping Text with inline Markdown links. A single Text
                // reflows as normal prose at any text size — unlike separate
                // buttons in an HStack, which hyphenate mid-word ("Pri-vacy") and
                // collide. openURL routes each link to its in-app reader sheet.
                Text("I have read and agree to the [Privacy Policy](moomo://privacy) and [Terms of Service](moomo://terms)")
                    .font(.footnote)
                    .foregroundColor(Color(hex: "3A3542"))
                    .tint(navy)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)   // centers the label against the 44pt box at default sizes
                    .environment(\.openURL, OpenURLAction { url in
                        if url.host == "terms" { showTerms = true } else { showPrivacy = true }
                        return .handled
                    })
            }

            if showConsentHint {
                Text("Please accept the Privacy Policy and Terms of Service to continue.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "A9503F"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
    }

    private var checkboxSquare: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(agreedToLegal ? navy : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(agreedToLegal ? navyPressed : subtitle.opacity(0.55), lineWidth: 1.5)
            )
            .overlay {
                if agreedToLegal {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 24, height: 24)
    }

    // MARK: - Logo cluster

    private var sparkleStack: some View {
        VStack(spacing: 2) {
            SparkleShape().fill(navy).frame(width: 22, height: 22)
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
            .foregroundColor(navy)
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
            SparkleShape().fill(navy).frame(width: 14, height: 14)
            ForEach(0..<3, id: \.self) { _ in dot }
        }
    }

    private var dot: some View {
        Circle().fill(Color.black.opacity(0.12)).frame(width: 5, height: 5)
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
    var isEnabled: Bool = true
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
                        Circle().fill(Color(hex: "F4EFE5")).frame(width: 36, height: 36)
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
            // Dimmed until the consent checkbox is checked; the tap still
            // lands so the view can show the inline consent reminder (the
            // action itself refuses to authenticate — see attemptSignIn).
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(PressableScaleStyle())
        .accessibilityHint(isEnabled ? "" : "Accept the Privacy Policy and Terms of Service first")
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
    let navy: Color
    let gold: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(navy.opacity(0.12))
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
                            navy.opacity(0.45),
                            gold.opacity(0.55),
                            Color.white.opacity(0.0),
                            navy.opacity(0.30),
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

// MARK: - In-app legal document reader

/// Scrollable full-text reader used by the welcome screen's consent links,
/// the paywall, and the profile menu — the entire document is readable
/// without leaving the app or needing a network connection.
struct LegalDocumentSheet: View {
    let title: String
    let text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "3A3542"))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Color(hex: "FCF8F2").ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "253B86"))
                }
            }
        }
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
