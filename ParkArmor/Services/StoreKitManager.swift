import StoreKit
import Observation

@Observable final class StoreKitManager {
    static let proProductID = "com.katafract.ParkArmor.pro"

    var isPro = false
    var products: [Product] = []
    var isLoading = false
    var purchaseError: String?

    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task {
            await listenForTransactions()
        }
        Task { await verifyEntitlement() }
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.proProductID])
        } catch {
            purchaseError = "Could not load products."
        }
    }

    func purchase() async throws {
        guard let product = products.first else {
            await loadProducts()
            guard let product = products.first else {
                throw StoreError.productNotFound
            }
            return try await purchaseProduct(product)
        }
        try await purchaseProduct(product)
    }

    private func purchaseProduct(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await verifyEntitlement()
        case .pending:
            break
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await verifyEntitlement()
        } catch {
            purchaseError = "Restore failed. Please try again."
        }
    }

    func verifyEntitlement() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                hasPro = true
                break
            }
        }
        isPro = hasPro
        // Persist to shared UserDefaults so widget can read it
        UserDefaults(suiteName: "group.com.katafract.ParkArmor")?.set(hasPro, forKey: "isPro")
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await verifyEntitlement()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    var proProduct: Product? { products.first }

    enum StoreError: LocalizedError {
        case failedVerification
        case productNotFound
        var errorDescription: String? {
            switch self {
            case .failedVerification: return "Purchase verification failed."
            case .productNotFound: return "Product not found."
            }
        }
    }
}
