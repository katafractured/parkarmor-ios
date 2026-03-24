import SwiftUI

struct OnboardingPaywallView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        PaywallView(storeKit: appViewModel.storeKitManager) {
            appViewModel.completeOnboarding()
        }
        .onChange(of: appViewModel.storeKitManager.isPro) { _, isPro in
            if isPro {
                appViewModel.completeOnboarding()
            }
        }
        .navigationBarBackButtonHidden()
    }
}
