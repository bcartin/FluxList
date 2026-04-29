import SwiftUI
import StoreKit

/// The Pro upgrade paywall screen, showing feature benefits, plan options,
/// and purchase / restore buttons.
struct PaywallView: View {
    @Environment(StoreKitManager.self) private var storeKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PaywallViewModel?

    var body: some View {
        Group {
            if let viewModel {
                PaywallContentView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Upgrade to Pro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = PaywallViewModel(storeKitManager: storeKitManager)
            }
        }
    }
}

// MARK: - Content

/// The scrollable paywall body: hero icon, benefit list, plan cards, and action buttons.
private struct PaywallContentView: View {
    @Bindable var viewModel: PaywallViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header with gradient icon
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.brandGradient)
                            .frame(width: 88, height: 88)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }

                    Text("FluxList Pro")
                        .font(.largeTitle)
                        .bold()

                    Text("Unlock the full experience")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Benefits
                VStack(alignment: .leading, spacing: 20) {
                    BenefitRow(
                        icon: "icloud.fill",
                        color: AppTheme.gradientStart,
                        title: "Cloud Sync",
                        description: "Sync your lists across all your devices"
                    )
                    BenefitRow(
                        icon: "person.2.fill",
                        color: AppTheme.gradientMid,
                        title: "Shared Lists",
                        description: "Collaborate on lists with friends and family"
                    )
                    BenefitRow(
                        icon: "checkmark.rectangle.stack.fill",
                        color: AppTheme.gradientEnd,
                        title: "Unlimited Lists",
                        description: "Remove the list cap and create as many as you like"
                    )
                    BenefitRow(
                        icon: "sparkles",
                        color: AppTheme.accentMint,
                        title: "Smart Suggestions",
                        description: "Automaticaly add frequenly used items to your favorites."
                    )
                }
                .padding()
                .background(AppTheme.subtleGradient, in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.gradientMid.opacity(0.15), lineWidth: 1)
                )

                // Plan selection
                VStack(spacing: 12) {
                    if let yearly = viewModel.yearlyProduct {
                        PlanCard(
                            title: "Yearly",
                            price: yearly.displayPrice,
                            subtitle: "/year",
                            badge: bestValueBadge(monthly: viewModel.monthlyProduct, yearly: yearly),
                            isSelected: viewModel.selectedTier == .yearly
                        ) {
                            viewModel.selectedTier = .yearly
                        }
                    }

                    if let monthly = viewModel.monthlyProduct {
                        PlanCard(
                            title: "Monthly",
                            price: monthly.displayPrice,
                            subtitle: "/month",
                            badge: nil,
                            isSelected: viewModel.selectedTier == .monthly
                        ) {
                            viewModel.selectedTier = .monthly
                        }
                    }

                    if let lifetime = viewModel.lifetimeProduct {
                        PlanCard(
                            title: "Lifetime",
                            price: lifetime.displayPrice,
                            subtitle: "one-time purchase",
                            badge: nil,
                            isSelected: viewModel.selectedTier == .lifetime
                        ) {
                            viewModel.selectedTier = .lifetime
                        }
                    }
                }

                // Purchase action
                VStack(spacing: 14) {
                    Button {
                        Task { await viewModel.purchase() }
                    } label: {
                        Group {
                            if viewModel.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.purchaseButtonLabel)
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(AppTheme.brandGradient, in: .capsule)
                    }
                    .disabled(viewModel.isPurchasing || viewModel.isProUser)

                    if viewModel.selectedTier != .lifetime {
                        Text("Subscription auto-renews. Cancel anytime in Settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Restore Purchases") {
                        Task { await viewModel.restore() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.gradientMid)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
        }
    }

    /// Computes a savings badge like "Save 50%" for the yearly plan relative to monthly pricing.
    private func bestValueBadge(monthly: Product?, yearly: Product) -> String? {
        guard let monthly else { return nil }
        let yearlyPrice = yearly.price
        let annualMonthly = monthly.price * 12
        guard annualMonthly > 0 else { return nil }
        let savings = ((annualMonthly - yearlyPrice) / annualMonthly * 100)
            .formatted(.number.precision(.fractionLength(0)))
        return "Save \(savings)%"
    }
}

#Preview {
    NavigationStack {
        PaywallView()
    }
    .environment(StoreKitManager())
}

// MARK: - Plan Card

/// A selectable plan card showing title, price, and optional badge.
private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)

                        if let badge {
                            Text(badge)
                                .font(.caption)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppTheme.gradientMid.opacity(0.15), in: .capsule)
                                .foregroundStyle(AppTheme.gradientMid)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.title3)
                    .bold()
            }
            .padding()
            .background(
                isSelected ? AppTheme.subtleGradient : LinearGradient(
                    colors: [Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? AppTheme.gradientMid : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Benefit Row

/// A single feature benefit row with an icon, title, and description.
private struct BenefitRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .bold()
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
