//
//  PaywallView.swift
//  MoomoAI
//
//  Moomo Premium paywall — warm cream canvas, navy typography, restrained gold
//  accents, in the app's luxury visual language. Presented when a free user
//  attempts a query beyond the daily allowance (their draft stays untouched
//  underneath) and from Settings. Purchases only ever run through Apple's
//  StoreKit confirmation sheet; closing this screen changes nothing.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var showManageSubscriptions = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false

    var body: some View {
        ZStack {
            K.Colors.cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: 28) {
                        titleBlock
                        benefitsCard
                        purchaseBlock
                        footerLinks
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 36)
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalDocumentSheet(
                title: LegalDocuments.privacyPolicyTitle,
                text: LegalDocuments.privacyPolicy
            )
        }
        .sheet(isPresented: $showTermsOfUse) {
            LegalDocumentSheet(
                title: LegalDocuments.termsOfServiceTitle,
                text: LegalDocuments.termsOfService
            )
        }
        .task {
            await storeService.loadProducts()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .onChange(of: storeService.isPremium) { isPremium in
            // A verified, active subscription is the only thing that closes
            // this screen on its own.
            if isPremium { dismiss() }
        }
    }

    // MARK: - Header (close)

    private var header: some View {
        HStack {
            Spacer()
            Button {
                HapticFeedback.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(K.Colors.slate)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(K.Colors.backgroundSecondary))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 14) {
            SparkleMark(color: K.Colors.gold, size: 30)
                .padding(.top, 4)

            Text("MOOMO PREMIUM")
                .font(.system(size: 13, weight: .semibold))
                .tracking(3.4)
                .foregroundColor(K.Colors.gold)

            Text("Upgrade to Moomo Premium")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundColor(K.Colors.navy)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("You get 10 free questions every day. Premium unlocks unlimited chat and Moomo's complete AI experience.")
                .font(.system(size: 15.5))
                .foregroundColor(K.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    // MARK: - Benefits

    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    private let benefits: [Benefit] = [
        .init(icon: "bubble.left.and.bubble.right.fill", text: "Unlimited chat"),
        .init(icon: "wand.and.stars", text: "Image generation and editing"),
        .init(icon: "books.vertical.fill", text: "Library access for generated images and files"),
        .init(icon: "bolt.fill", text: "Priority AI responses"),
        .init(icon: "brain.head.profile", text: "Personalization and memory"),
        .init(icon: "doc.text.magnifyingglass", text: "File analysis"),
    ]

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(benefits) { benefit in
                HStack(spacing: 14) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(K.Colors.gold)
                        .frame(width: 26)
                    Text(benefit.text)
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundColor(K.Colors.ink)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(K.Colors.goldSoft.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: K.Colors.gold.opacity(0.10), radius: 18, y: 6)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // MARK: - Purchase

    /// "3 days free" style phrase, derived from the product's actual StoreKit
    /// introductory offer — nil unless a real free-trial offer is configured, so
    /// the UI never advertises a trial that App Store Connect doesn't grant.
    private var freeTrialPhrase: String? {
        guard let offer = storeService.monthlyProduct?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day:   unit = n == 1 ? "day" : "days"
        case .week:  unit = n == 1 ? "week" : "weeks"
        case .month: unit = n == 1 ? "month" : "months"
        case .year:  unit = n == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return "\(n) \(unit) free"
    }

    private var priceLine: String {
        guard let product = storeService.monthlyProduct else { return "Cancel anytime" }
        if let trial = freeTrialPhrase {
            return "\(trial), then \(product.displayPrice)/month"
        }
        return "\(product.displayPrice)/month · Cancel anytime"
    }

    /// Purchase CTA — names the trial when one exists so the button itself sets
    /// the expectation, per App Review guidance on introductory offers.
    private var ctaTitle: String {
        freeTrialPhrase != nil ? "Start Free Trial" : "Continue with Premium"
    }

    /// Auto-renewal disclosure required by App Review Guideline 3.1.2. Built from
    /// the live StoreKit price so it always matches what Apple will charge.
    private var renewalDisclosure: String {
        let price = storeService.monthlyProduct?.displayPrice
        if let trial = freeTrialPhrase, let price {
            return "Free for your first \(trial.replacingOccurrences(of: " free", with: "")), then \(price) per month. The subscription auto-renews monthly and your Apple ID is charged \(price) unless you cancel at least 24 hours before the period ends. Manage or cancel anytime in your App Store settings."
        }
        if let price {
            return "\(price) per month. The subscription auto-renews monthly and your Apple ID is charged \(price) unless you cancel at least 24 hours before the period ends. Manage or cancel anytime in your App Store settings."
        }
        return "The subscription auto-renews monthly until canceled. Manage or cancel anytime in your App Store settings."
    }

    private var purchaseBlock: some View {
        VStack(spacing: 14) {
            Button {
                HapticFeedback.medium()
                Task { await storeService.purchase() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(K.Colors.navy)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(K.Colors.gold.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: K.Colors.navy.opacity(0.25), radius: 14, y: 6)

                    if storeService.isPurchasing {
                        ProgressView()
                            .tint(K.Colors.cream)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(K.Colors.cream)
                    }
                }
                .frame(height: 56)
            }
            .disabled(storeService.isPurchasing || storeService.isRestoring)

            Text(priceLine)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(K.Colors.slate)

            // Auto-renewal disclosure required by App Review Guideline 3.1.2 —
            // shown on the paywall itself, not only in the linked Terms.
            Text(renewalDisclosure)
                .font(.system(size: 11.5))
                .foregroundColor(K.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Matches the fair-use clause in the Terms of Service.
            Text("Unlimited chat is subject to a fair-use limit of 500 requests per day.")
                .font(.system(size: 11.5))
                .foregroundColor(K.Colors.textSecondary)
                .multilineTextAlignment(.center)

            if let message = storeService.statusMessage {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(K.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 16) {
            Button {
                HapticFeedback.light()
                Task { await storeService.restorePurchases() }
            } label: {
                if storeService.isRestoring {
                    ProgressView().tint(K.Colors.slate)
                } else {
                    Text("Restore Purchases")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(K.Colors.navyText)
                }
            }
            .disabled(storeService.isPurchasing || storeService.isRestoring)

            if storeService.isPremium {
                Button("Manage Subscription") { showManageSubscriptions = true }
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(K.Colors.navyText)
            }

            // Bundled documents shown in-app (K.Legal URLs stay the public,
            // App Store Connect-facing copies of the same documents).
            HStack(spacing: 18) {
                Button("Privacy Policy") { showPrivacyPolicy = true }
                Text("·").foregroundColor(K.Colors.slate)
                Button("Terms of Use") { showTermsOfUse = true }
            }
            .font(.system(size: 13))
            .foregroundColor(K.Colors.slate)
        }
        .padding(.top, 2)
        .opacity(appeared ? 1 : 0)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreService.shared)
}
