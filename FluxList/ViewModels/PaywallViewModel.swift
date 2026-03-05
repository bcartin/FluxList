import Foundation
import StoreKit

/// Backs the Pro upgrade paywall screen, exposing product info, purchase state,
/// and actions to buy or restore the FluxList Pro subscription.
@MainActor @Observable
final class PaywallViewModel {
    private let storeKitManager: StoreKitManager

    /// `true` while a purchase transaction is being processed.
    var isPurchasing = false
    /// User-facing error message if the purchase fails.
    var errorMessage: String?

    /// The StoreKit `Product` for the Pro upgrade (price, display name, etc.).
    var proProduct: Product? {
        storeKitManager.proProduct
    }

    /// Whether the user already owns Pro (used to show a "purchased" state).
    var isProUser: Bool {
        storeKitManager.isProUser
    }

    init(storeKitManager: StoreKitManager) {
        self.storeKitManager = storeKitManager
    }

    /// Initiates the App Store purchase flow for the Pro product.
    func purchase() async {
        guard let product = proProduct else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let success = try await storeKitManager.purchase(product)
            if !success {
                errorMessage = "Purchase was cancelled or is pending."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Restores previous purchases (e.g. on a new device).
    func restore() async {
        await storeKitManager.restorePurchases()
    }
}
