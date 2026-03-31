import Foundation
import StoreKit

/// Manages FluxList Pro subscriptions and lifetime purchase using StoreKit 2.
///
/// Responsibilities:
/// - Loading available products (monthly, yearly, lifetime) from the App Store.
/// - Processing purchases and verifying receipts.
/// - Restoring previous purchases on new devices.
/// - Listening for transaction updates (e.g. renewals, refunds) in the background.
///
/// Other managers check ``isProUser`` to gate premium features like
/// Firestore sync and auto-favorite suggestions.
@MainActor @Observable
final class StoreKitManager {
    // MARK: - Product Identifiers

    /// Monthly auto-renewable subscription.
    static let monthlyProductID = "com.garsontech.fluxlist.monthly"
    /// Yearly auto-renewable subscription.
    static let yearlyProductID = "com.garsontech.fluxlist.yearly"
    /// One-time lifetime purchase (the original Pro product).
    static let lifetimeProductID = "com.garsontech.fluxlist.pro"

    /// All product identifiers that grant Pro access.
    static let allProductIDs: Set<String> = [
        monthlyProductID,
        yearlyProductID,
        lifetimeProductID
    ]

    // MARK: - State

    /// All products fetched from the App Store.
    private(set) var products: [Product] = []
    /// Product IDs the user currently owns. Populated on launch and after purchases.
    private(set) var purchasedProductIDs: Set<String> = []
    /// `true` while products are being fetched from the App Store.
    private(set) var isLoading = false

    // MARK: - Computed Properties

    /// Whether the current user has an active Pro entitlement
    /// (any active subscription or lifetime purchase).
    var isProUser: Bool {
        !purchasedProductIDs.isDisjoint(with: Self.allProductIDs)
    }

    /// The monthly subscription product.
    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    /// The yearly subscription product.
    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    /// The one-time lifetime purchase product.
    var lifetimeProduct: Product? {
        products.first { $0.id == Self.lifetimeProductID }
    }

    /// Fetches all Pro product metadata from the App Store.
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.allProductIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    /// Initiates a purchase flow for the given product.
    /// Returns `true` if the purchase succeeded, `false` if cancelled or pending.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    /// Iterates over current entitlements to restore previously purchased products.
    /// Call this on launch to ensure Pro status is accurate on new devices.
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
    }

    /// Runs indefinitely, listening for new or updated transactions (e.g. renewals, refunds).
    /// Should be started once at app launch via a long-lived `Task`.
    func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
            }
        }
    }

    /// Unwraps a StoreKit verification result, throwing if the transaction is unverified.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
