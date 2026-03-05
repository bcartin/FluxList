import Foundation
import StoreKit

/// Manages the FluxList Pro in-app purchase using StoreKit 2.
///
/// Responsibilities:
/// - Loading available products from the App Store.
/// - Processing purchases and verifying receipts.
/// - Restoring previous purchases on new devices.
/// - Listening for transaction updates (e.g. renewals, refunds) in the background.
///
/// Other managers check ``isProUser`` to gate premium features like
/// Firestore sync and auto-favorite suggestions.
@MainActor @Observable
final class StoreKitManager {
    /// The App Store Connect product identifier for the Pro upgrade.
    static let proProductID = "com.garsontech.fluxlist.pro"

    /// All products fetched from the App Store (currently just the Pro product).
    private(set) var products: [Product] = []
    /// Product IDs the user currently owns. Populated on launch and after purchases.
    private(set) var purchasedProductIDs: Set<String> = []
    /// `true` while products are being fetched from the App Store.
    private(set) var isLoading = false

    /// Whether the current user has purchased FluxList Pro.
    /// Hardcoded to `false` during development; toggle to enable Pro features.
    var isProUser: Bool {
        purchasedProductIDs.contains(Self.proProductID)
    }

    /// The StoreKit `Product` object for Pro, used to display price and initiate purchase.
    var proProduct: Product? {
        products.first { $0.id == Self.proProductID }
    }

    /// Fetches the Pro product metadata from the App Store.
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: [Self.proProductID])
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
