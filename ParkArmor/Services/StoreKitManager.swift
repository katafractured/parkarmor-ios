import Observation
import OSLog
import StoreKit

@Observable final class StoreKitManager {
    static let proProductID = "com.katafract.ParkArmor.pro"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.katafract.ParkArmor",
        category: "StoreKit"
    )

    var isPro = false
    var products: [Product] = []
    var isLoading = false
    var purchaseError: String?

    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task {
            await listenForTransactions()
        }
        Task { await verifyEntitlement(reason: "initial launch") }
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.proProductID])
            let returnedIDs = products.map(\.id).joined(separator: ", ")
            Self.logger.notice("[StoreKit-Debug] Product lookup for \(Self.proProductID, privacy: .public) returned \(self.products.count) products: \(returnedIDs, privacy: .public)")
            if products.isEmpty {
                purchaseError = "Product not found in App Store. Check that the product ID is configured in your scheme."
                Self.logger.error("[StoreKit-Debug] No products returned for configured product ID \(Self.proProductID, privacy: .public)")
            }
        } catch {
            purchaseError = "Could not load products: \(error.localizedDescription)"
            Self.logger.error("[StoreKit-Debug] Product lookup failed for \(Self.proProductID, privacy: .public): \(String(describing: error), privacy: .public)")
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

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    logTransaction("purchase verified", transaction: transaction)
                    await transaction.finish()
                    Self.logger.notice("[StoreKit-Debug] Finished verified purchase transaction for \(transaction.productID, privacy: .public)")
                    await verifyEntitlement(reason: "purchase success")
                case .unverified(let transaction, let error):
                    purchaseError = StoreError.failedVerification.errorDescription
                    logTransaction("purchase unverified", transaction: transaction)
                    Self.logger.error("[StoreKit-Debug] Unverified transaction for \(transaction.productID, privacy: .public): \(String(describing: error), privacy: .public)")
                    throw StoreError.failedVerification
                }
            case .pending:
                Self.logger.notice("[StoreKit-Debug] Purchase is pending for \(product.id, privacy: .public)")
            case .userCancelled:
                Self.logger.notice("[StoreKit-Debug] User cancelled purchase for \(product.id, privacy: .public)")
            @unknown default:
                Self.logger.error("[StoreKit-Debug] Received unknown purchase result for \(product.id, privacy: .public)")
            }
        } catch {
            purchaseError = error.localizedDescription
            Self.logger.error("[StoreKit-Debug] Purchase failed for \(product.id, privacy: .public): \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            Self.logger.notice("[StoreKit-Debug] Starting AppStore.sync() restore flow")
            try await AppStore.sync()
            Self.logger.notice("[StoreKit-Debug] AppStore.sync() completed successfully")
            await verifyEntitlement(reason: "restore purchases")
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
            Self.logger.error("[StoreKit-Debug] AppStore.sync() failed: \(String(describing: error), privacy: .public)")
        }
    }

    func verifyEntitlement(reason: String = "manual check") async {
        // Check platform unlock first (Enclave/Sovereign token via App Group)
        if PlatformEntitlement.isPlatformUnlocked {
            isPro = true
            Self.logger.notice("[StoreKit-Debug] Entitlement rebuild (\(reason, privacy: .public)) resolved isPro=true via platform token")
            return
        }

        var hasPro = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                logTransaction("current entitlement", transaction: transaction)
                if transaction.productID == Self.proProductID,
                   transaction.revocationDate == nil {
                    hasPro = true
                    break
                }
            case .unverified(let transaction, let error):
                logTransaction("current entitlement unverified", transaction: transaction)
                Self.logger.error("[StoreKit-Debug] Ignoring unverified entitlement for \(transaction.productID, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        isPro = hasPro
        clearLegacyCachedEntitlement()
        Self.logger.notice("[StoreKit-Debug] Entitlement rebuild (\(reason, privacy: .public)) resolved isPro=\(hasPro)")
    }

    private func listenForTransactions() async {
        Self.logger.notice("[StoreKit-Debug] Transaction listener started")
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                logTransaction("transaction update", transaction: transaction)
                await transaction.finish()
                Self.logger.notice("[StoreKit-Debug] Finished transaction update for \(transaction.productID, privacy: .public)")
                await verifyEntitlement(reason: "transaction update")
            case .unverified(let transaction, let error):
                logTransaction("transaction update unverified", transaction: transaction)
                Self.logger.error("[StoreKit-Debug] Ignoring unverified transaction update for \(transaction.productID, privacy: .public): \(String(describing: error), privacy: .public)")
            }
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

    private func clearLegacyCachedEntitlement() {
        UserDefaults(suiteName: "group.com.katafract.ParkArmor")?.removeObject(forKey: "isPro")
    }

    private func logTransaction(_ event: String, transaction: Transaction) {
        let expiration = transaction.expirationDate?.formatted(date: .numeric, time: .standard) ?? "nil"
        let revocation = transaction.revocationDate?.formatted(date: .numeric, time: .standard) ?? "nil"
        let purchaseDate = transaction.purchaseDate.formatted(date: .numeric, time: .standard)
        Self.logger.notice(
            "[StoreKit-Debug] \(event, privacy: .public): productID=\(transaction.productID, privacy: .public), environment=\(String(describing: transaction.environment), privacy: .public), purchaseDate=\(purchaseDate, privacy: .public), expirationDate=\(expiration, privacy: .public), revocationDate=\(revocation, privacy: .public)"
        )
    }
}
