import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @EnvironmentObject var premiumStore: PremiumStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if premiumStore.isPremium {
                    alreadyPremiumContent
                } else {
                    paywallContent
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .task { await premiumStore.loadProducts() }
        .overlay(alignment: .top) {
            if let error = premiumStore.purchaseError {
                ErrorBanner(message: error) {
                    premiumStore.purchaseError = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: premiumStore.purchaseError)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: premiumStore.purchaseError)
    }

    // MARK: - Already Premium

    private var alreadyPremiumContent: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 80)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: premiumStore.isPremium)

            VStack(spacing: 8) {
                Text("You're Premium!")
                    .font(.system(size: 28, weight: .bold))

                Text("Enjoy full access to all Calibrate features.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Paywall

    private var paywallContent: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.top, 40)
                .padding(.bottom, 36)

            featuresSection
                .padding(.bottom, 36)

            productsSection
                .padding(.bottom, 24)

            restoreButton
                .padding(.bottom, 16)

            legalText
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("Calibrate Premium")
                    .font(.system(size: 28, weight: .bold))

                Text("Unlock your full calibration potential")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRow(
                icon: "waveform.path.ecg",
                title: "Calibration Curve",
                description: "Visualize exactly how your confidence compares to reality"
            )

            Divider().padding(.leading, 56)

            FeatureRow(
                icon: "person.2.fill",
                title: "Friend Groups",
                description: "Compete with friends on private leaderboards"
            )

            Divider().padding(.leading, 56)

            FeatureRow(
                icon: "sparkles",
                title: "Coming Soon",
                description: "Domain-specific scores and more"
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Products

    @ViewBuilder
    private var productsSection: some View {
        if premiumStore.products.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 12) {
                ForEach(premiumStore.products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isPurchasing: premiumStore.isPurchasing
                    ) {
                        Task { await premiumStore.purchase(product) }
                    }
                }
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await premiumStore.restore() }
        }
        .buttonStyle(.plain)
        .font(.subheadline)
        .foregroundStyle(.tint)
    }

    // MARK: - Legal

    private var legalText: some View {
        Text("By subscribing you agree to our ")
            .font(.caption)
            .foregroundStyle(.tertiary)
        + Text("Terms of Use")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .underline()
        + Text(" and ")
            .font(.caption)
            .foregroundStyle(.tertiary)
        + Text("Privacy Policy")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .underline()
        + Text(".")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Product Card

private struct ProductCard: View {
    let product: Product
    let isPurchasing: Bool
    let onPurchase: () -> Void

    private var isMonthly: Bool {
        product.id == Constants.StoreKit.monthlyProductID
    }

    private var trialCallout: String {
        isMonthly ? "Free 3-day trial" : "Free 7-day trial"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)
                            .fontWeight(.bold)

                        Text(trialCallout)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green, in: Capsule())
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Button(action: onPurchase) {
                Group {
                    if isPurchasing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .tint(.white)
                            Text("Processing…")
                        }
                    } else {
                        Text("Start Free Trial")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            if !isMonthly {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
    }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview("Paywall — Loading") {
    let store = PremiumStore()
    return NavigationStack {
        PremiumUpgradeView()
            .navigationTitle("Go Premium")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(store)
}

#Preview("Already Premium") {
    let store = PremiumStore()
    store.isPremium = true
    return NavigationStack {
        PremiumUpgradeView()
    }
    .environmentObject(store)
}

#Preview("With Error") {
    let store = PremiumStore()
    store.purchaseError = "Your purchase could not be completed. Please try again."
    return NavigationStack {
        PremiumUpgradeView()
    }
    .environmentObject(store)
}
