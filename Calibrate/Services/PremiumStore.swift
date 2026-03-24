import StoreKit
import OSLog

private let logger = Logger(subsystem: "com.calibrate.app", category: "PremiumStore")

@MainActor
final class PremiumStore: ObservableObject {
    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var purchaseError: String? = nil
    @Published var isPurchasing: Bool = false

    private var transactionListenerTask: Task<Void, Never>?

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Public API

    func load() async {
        await checkEntitlements()
        if transactionListenerTask == nil {
            transactionListenerTask = startTransactionListener()
        }
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [
                Constants.StoreKit.monthlyProductID,
                Constants.StoreKit.annualProductID
            ])
            // Monthly first, annual second
            products = fetched.sorted { lhs, rhs in
                lhs.id == Constants.StoreKit.monthlyProductID
            }
        } catch {
            logger.error("Failed to load StoreKit products: \(error.localizedDescription)")
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    isPremium = true
                    logger.info("Purchase verified for product: \(transaction.productID)")
                case .unverified(let transaction, let error):
                    logger.warning("Unverified transaction for \(transaction.productID): \(error.localizedDescription)")
                }
            case .pending:
                logger.info("Purchase pending approval (e.g. Ask to Buy)")
            case .userCancelled:
                break
            @unknown default:
                logger.warning("Unknown purchase result")
            }
        } catch {
            purchaseError = error.localizedDescription
            logger.error("Purchase failed: \(error.localizedDescription)")
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await load()
        } catch {
            purchaseError = error.localizedDescription
            logger.error("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func checkEntitlements() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Constants.StoreKit.monthlyProductID ||
               transaction.productID == Constants.StoreKit.annualProductID {
                hasPremium = true
                break
            }
        }
        isPremium = hasPremium
    }

    private func startTransactionListener() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await _ in Transaction.updates {
                await self?.load()
            }
        }
    }
}
