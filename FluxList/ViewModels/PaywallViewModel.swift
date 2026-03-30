import Foundation
import StoreKit

/// The subscription tier the user can select on the paywall.
enum ProTier: String, CaseIterable, Identifiable {
    case yearly
    case monthly
    case lifetime

    var id: String { rawValue }
}

/// Backs the Pro upgrade paywall screen, exposing product info, purchase state,
/// and actions to buy or restore FluxList Pro.
@MainActor @Observable
final class PaywallViewModel {
    private let storeKitManager: StoreKitManager

    /// `true` while a purchase transaction is being processed.
    var isPurchasing = false
    /// User-facing error message if the purchase fails.
    var errorMessage: String?
    /// The currently selected subscription tier.
    var selectedTier: ProTier = .yearly

    // MARK: - Products

    /// The monthly subscription product.
    var monthlyProduct: Product? {
        storeKitManager.monthlyProduct
    }

    /// The yearly subscription product.
    var yearlyProduct: Product? {
        storeKitManager.yearlyProduct
    }

    /// The one-time lifetime purchase product.
    var lifetimeProduct: Product? {
        storeKitManager.lifetimeProduct
    }

    /// Whether the user already owns Pro (used to show a "purchased" state).
    var isProUser: Bool {
        storeKitManager.isProUser
    }

    /// The product matching the currently selected tier.
    var selectedProduct: Product? {
        switch selectedTier {
        case .monthly: monthlyProduct
        case .yearly: yearlyProduct
        case .lifetime: lifetimeProduct
        }
    }

    /// The label for the purchase button based on the selected tier.
    var purchaseButtonLabel: String {
        if isProUser { return "Already Subscribed" }
        switch selectedTier {
        case .monthly: return "Subscribe Monthly"
        case .yearly: return "Subscribe Yearly"
        case .lifetime: return "Purchase Lifetime"
        }
    }

    init(storeKitManager: StoreKitManager) {
        self.storeKitManager = storeKitManager
    }

    /// Initiates the App Store purchase flow for the selected tier.
    func purchase() async {
        guard let product = selectedProduct else { return }
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
