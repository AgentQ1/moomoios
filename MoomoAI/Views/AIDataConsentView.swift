//
//  AIDataConsentView.swift
//  MoomoAI
//
//  The AI data-sharing permission screen, shown BEFORE any of the user's content
//  can reach the third-party AI provider (App Review Guidelines 5.1.1(i) and
//  5.1.2(i)). It states plainly what is sent, what is not sent, who receives it
//  and why, then offers a real choice: Accept or Decline.
//
//  Declining is not a dead end — the app stays fully usable (history, library,
//  export, settings) with AI responses switched off, and the decision can be
//  changed at any time in Settings → AI data sharing.
//
//  All copy comes from AIDataSharingDisclosure so this screen, Settings and the
//  privacy policy cannot drift apart.
//

import SwiftUI

struct AIDataConsentView: View {
    /// Called with the user's decision so the presenter can dismiss and react.
    /// `true` = accepted, `false` = declined.
    let onDecision: (Bool) -> Void

    @ObservedObject private var consent = AIDataSharingConsent.shared
    @State private var showPrivacyPolicy = false

    // Brand palette, matching LoginView's fixed light canvas.
    private let canvas = Color(hex: "FCF8F2")
    private let navy = Color(hex: "253B86")
    private let gold = Color(hex: "C6A46A")
    private let subtitle = Color(hex: "8D8B98")
    private let cardBorder = Color(hex: "EAE4D7")
    private let bodyInk = Color(hex: "3A3542")

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        summaryCard
                        sentSection
                        notSentSection
                        recipientSection
                        cautionSection
                        policyLink
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                actions
            }
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled()
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalDocumentSheet(
                title: LegalDocuments.privacyPolicyTitle,
                text: LegalDocuments.privacyPolicy
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(navy.opacity(0.07))
                    .frame(width: 76, height: 76)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(navy)
            }
            .padding(.top, 32)

            Text(AIDataSharingDisclosure.title)
                .font(.system(size: 27, weight: .bold, design: .serif))
                .foregroundColor(navy)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Rectangle().fill(gold.opacity(0.45)).frame(width: 34, height: 1)
                SparkleShape().fill(gold).frame(width: 9, height: 9)
                Rectangle().fill(gold.opacity(0.45)).frame(width: 34, height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 22)
    }

    private var summaryCard: some View {
        Text(AIDataSharingDisclosure.summary)
            .font(.system(size: 15.5))
            .foregroundColor(bodyInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            )
            .padding(.bottom, 24)
    }

    // MARK: - Disclosure sections

    private var sentSection: some View {
        section(
            title: "What is sent",
            icon: "arrow.up.right.circle.fill",
            iconColor: navy
        ) {
            ForEach(AIDataSharingDisclosure.itemsSent, id: \.self) { item in
                bullet(item, symbol: "checkmark", color: navy)
            }
        }
    }

    private var notSentSection: some View {
        section(
            title: "What is never sent",
            icon: "xmark.circle.fill",
            iconColor: Color(hex: "6F8F6B")
        ) {
            ForEach(AIDataSharingDisclosure.itemsNotSent, id: \.self) { item in
                bullet(item, symbol: "xmark", color: Color(hex: "6F8F6B"))
            }
        }
    }

    private var recipientSection: some View {
        section(
            title: "Who receives it",
            icon: "building.2.fill",
            iconColor: gold
        ) {
            Text(AIDataSharingDisclosure.recipient)
                .font(.system(size: 14.5))
                .foregroundColor(bodyInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cautionSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "A9803F"))
                .padding(.top, 1)
            Text(AIDataSharingDisclosure.caution)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(Color(hex: "6B5326"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FBF3E2"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "EBDCBE"), lineWidth: 1)
        )
        .padding(.bottom, 18)
    }

    private var policyLink: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showPrivacyPolicy = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                    Text("Read the full Privacy Policy")
                        .font(.system(size: 14.5, weight: .semibold))
                }
                .foregroundColor(navy)
            }
            .buttonStyle(.plain)

            Link(destination: AIProvider.privacyURL) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 13))
                    Text("Read \(AIProvider.shortName)'s Gemini API terms")
                        .font(.system(size: 14.5, weight: .semibold))
                }
                .foregroundColor(navy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Text(AIDataSharingDisclosure.consentSentence)
                .font(.system(size: 12.5))
                .foregroundColor(subtitle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            Button {
                HapticFeedback.light()
                consent.grant()
                onDecision(true)
            } label: {
                Text("Accept")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(navy)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Allows Moomo to send your messages and attachments to \(AIProvider.company) to generate responses")

            Button {
                HapticFeedback.light()
                consent.decline()
                onDecision(false)
            } label: {
                Text("Decline")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(navy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Keeps using Moomo with AI responses turned off. You can change this later in Settings")

            Text("You can change this any time in Settings → AI data sharing.")
                .font(.system(size: 12))
                .foregroundColor(subtitle)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            canvas
                .overlay(Rectangle().fill(cardBorder).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.4)
                    .foregroundColor(subtitle)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
    }

    private func bullet(_ text: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .frame(width: 16)
                .padding(.top, 3)
            Text(text)
                .font(.system(size: 14.5))
                .foregroundColor(bodyInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct AIDataConsentView_Previews: PreviewProvider {
    static var previews: some View {
        AIDataConsentView { _ in }
    }
}
