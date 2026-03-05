import SwiftUI
import StoreKit

/// The Pro upgrade paywall screen, showing feature benefits, pricing,
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

/// The scrollable paywall body: hero icon, benefit list, price, and action buttons.
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

                // Price and purchase
                VStack(spacing: 14) {
                    if let product = viewModel.proProduct {
                        Text(product.displayPrice)
                            .font(.title)
                            .bold()

                        Text("One-time purchase")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await viewModel.purchase() }
                    } label: {
                        Group {
                            if viewModel.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.isProUser ? "Already Purchased" : "Upgrade to Pro")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(AppTheme.brandGradient, in: .capsule)
                    }
                    .disabled(viewModel.isPurchasing || viewModel.isProUser)

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
}

#Preview {
    NavigationStack {
        PaywallView()
    }
    .environment(StoreKitManager())
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
