import StoreKit
import SwiftUI

struct PaywallView: View {
    @Bindable var storeKit: StoreKitManager
    var onDismiss: () -> Void

    private let freeFeatures = [
        ("checkmark.circle.fill", "Save 1 parking location", true),
        ("checkmark.circle.fill", "Walking directions", true),
        ("checkmark.circle.fill", "Parking meter timer", true),
        ("xmark.circle.fill", "Parking history", false),
        ("xmark.circle.fill", "Home screen widget", false),
        ("xmark.circle.fill", "Parking sign photos", false),
    ]

    var body: some View {
        ZStack {
            DesignTokens.parkNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 56))
                        .foregroundStyle(DesignTokens.parkCyan)
                        .padding(.top, 40)

                    Text("ParkArmor Pro")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Never worry about parking again")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                }
                .padding(.bottom, 32)

                // Feature list
                VStack(spacing: 0) {
                    ForEach(freeFeatures, id: \.1) { icon, label, included in
                        HStack(spacing: 14) {
                            Image(systemName: icon)
                                .foregroundStyle(included ? DesignTokens.parkCyan : DesignTokens.parkTextSecondary.opacity(0.5))
                                .font(.system(size: 18))
                                .frame(width: 24)

                            Text(label)
                                .foregroundStyle(included ? .white : DesignTokens.parkTextSecondary.opacity(0.6))
                                .font(.body)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                }
                .background(DesignTokens.parkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                Spacer()

                // Purchase CTA
                VStack(spacing: 12) {
                    Button {
                        Task { try? await storeKit.purchase() }
                    } label: {
                        HStack {
                            if storeKit.isLoading {
                                ProgressView()
                                    .tint(DesignTokens.parkNavy)
                            } else {
                                Text("Get ParkArmor Pro")
                                    .font(.headline)
                                Spacer()
                                Text(storeKit.proProduct?.displayPrice ?? "$2.99")
                                    .font(.headline)
                            }
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 54)
                        .background(DesignTokens.parkCyan)
                        .foregroundStyle(DesignTokens.parkNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(storeKit.isLoading)
                    .padding(.horizontal, 20)

                    if let errorMsg = storeKit.purchaseError {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.parkDestructive)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    HStack(spacing: 24) {
                        Button("Restore Purchase") {
                            Task { await storeKit.restorePurchases() }
                        }
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                        .disabled(storeKit.isLoading)

                        Button("Not Now") { onDismiss() }
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }

                    Text("One-time purchase • No subscription")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.parkTextSecondary.opacity(0.5))
                }
                .padding(.bottom, 40)
            }
        }
    }
}
