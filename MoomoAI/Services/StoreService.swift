//
//  StoreService.swift
//  MoomoAI
//
//  StoreKit 2 subscription manager for Moomo Premium. Owns product loading,
//  purchase, Restore Purchases, the Transaction.updates listener, and syncing
//  the Apple-signed transaction (JWS) to the backend, which is authoritative
//  for AI access. Premium is only ever unlocked from VERIFIED transactions —
//  never from a local flag or an unverified payload.
//

import Foundation
import StoreKit
import FirebaseAuth
import CryptoKit

@MainActor
final class StoreService: ObservableObject {
    static let shared = StoreService()

    /// Auto-renewable monthly subscription configured in App Store Connect
    /// (subscription group "Moomo Premium", $4.99/month US).
    static let monthlyProductID = "com.moomo.io.premium.monthly"

    /// Local mirror of the verified StoreKit entitlement. UI gating only —
    /// every AI request is re-checked server-side.
    @Published private(set) var isPremium = false
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    /// User-visible outcome message for restore/purchase problems (nil = none).
    @Published var statusMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var started = false
    /// uid whose entitlement was last pushed to the backend, so login/account
    /// switches re-sync exactly once instead of on every refresh.
    private var syncedUid: String?

    private init() {}

    // MARK: - Lifecycle

    /// Idempotent startup: begin listening for transaction updates (renewals,
    /// revocations, purchases finished on other devices / App Store) and load
    /// the current entitlement + product.
    func start() {
        guard !started else { return }
        started = true
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update: update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    /// Called when the signed-in Firebase user changes (login, logout, account
    /// switch). Clears per-account presentation state and re-syncs the Apple
    /// entitlement to the new account's backend record.
    func handleAuthChange(uid: String?) {
        statusMessage = nil
        guard uid != nil, uid != syncedUid else { return }
        Task {
            await refreshEntitlements()
            await syncEntitlementWithBackend()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        guard monthlyProduct == nil else { return }
        do {
            let products = try await Product.products(for: [Self.monthlyProductID])
            monthlyProduct = products.first
            #if DEBUG
            print("STORE products loaded=\(products.map(\.id))")
            #endif
        } catch {
            #if DEBUG
            print("STORE product load failed: \(error)")
            #endif
        }
    }

    // MARK: - Entitlements

    /// Recompute Premium from StoreKit's verified current entitlements.
    /// `currentEntitlements` only yields active subscriptions (including grace
    /// period) and skips revoked/refunded ones; unverified results are ignored.
    func refreshEntitlements() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.monthlyProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        if isPremium != active {
            isPremium = active
        }
    }

    /// Push the freshest verified transaction JWS to the backend so the
    /// server-side entitlement (which gates AI access) matches Apple's state.
    /// Safe to call repeatedly; no-ops when signed out or not subscribed.
    func syncEntitlementWithBackend() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var latest: (transaction: Transaction, jws: String)?
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.monthlyProductID else { continue }
            if latest == nil || transaction.purchaseDate > latest!.transaction.purchaseDate {
                latest = (transaction, entitlement.jwsRepresentation)
            }
        }
        guard let latest else { return }
        do {
            try await GenerationService.shared.verifyAppStorePurchase(jws: latest.jws)
            syncedUid = uid
        } catch {
            #if DEBUG
            print("STORE backend sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Purchase

    /// Run the StoreKit purchase sheet. Returns true when Premium is active
    /// afterwards. Never charges without the user confirming Apple's sheet.
    @discardableResult
    func purchase() async -> Bool {
        guard !isPurchasing else { return false }
        if monthlyProduct == nil { await loadProducts() }
        guard let product = monthlyProduct else {
            statusMessage = "The subscription is unavailable right now. Please try again later."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            var options: Set<Product.PurchaseOption> = []
            if let uid = Auth.auth().currentUser?.uid {
                options.insert(.appAccountToken(Self.appAccountToken(for: uid)))
            }
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    statusMessage = "Your purchase could not be verified. Please try Restore Purchases."
                    return false
                }
                // Deliver first (backend entitlement), then finish.
                try? await GenerationService.shared.verifyAppStorePurchase(jws: verification.jwsRepresentation)
                await transaction.finish()
                await refreshEntitlements()
                syncedUid = Auth.auth().currentUser?.uid
                return isPremium
            case .userCancelled:
                return false
            case .pending:
                statusMessage = "Your purchase is awaiting approval. Premium unlocks automatically once it's approved."
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = "The purchase didn't go through. Please try again."
            #if DEBUG
            print("STORE purchase failed: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Restore

    /// Restore Purchases — required by App Review. Syncs with the App Store,
    /// then refreshes local + backend entitlement.
    @discardableResult
    func restorePurchases() async -> Bool {
        guard !isRestoring else { return false }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch {
            // sync() throws when the user cancels the App Store sign-in — not an error.
            #if DEBUG
            print("STORE restore sync: \(error.localizedDescription)")
            #endif
        }
        await refreshEntitlements()
        await syncEntitlementWithBackend()
        statusMessage = isPremium
            ? "Moomo Premium restored."
            : "No active subscription was found for this Apple ID."
        return isPremium
    }

    // MARK: - Transaction.updates

    /// Renewals, Ask to Buy approvals, refunds/revocations, and purchases made
    /// on other devices all arrive here. Verified transactions update local
    /// state, sync to the backend, and are finished.
    private func handle(update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        guard transaction.productID == Self.monthlyProductID else {
            await transaction.finish()
            return
        }
        if transaction.revocationDate == nil {
            try? await GenerationService.shared.verifyAppStorePurchase(jws: update.jwsRepresentation)
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    // MARK: - App account token

    /// Deterministic UUID derived from the Firebase uid, attached to purchases
    /// as `appAccountToken` so Apple-side records can be tied to the account.
    static func appAccountToken(for uid: String) -> UUID {
        let digest = SHA256.hash(data: Data(uid.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40   // version 4 layout
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
