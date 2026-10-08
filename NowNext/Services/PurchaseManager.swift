import Foundation
import Observation
import StoreKit

/// StoreKit 2 one-time unlock ("NowNext Pro", non-consumable).
@MainActor
@Observable
final class PurchaseManager {
    static let proProductID = "ai.palmettogroup.nownext.pro"

    private(set) var product: Product?
    private(set) var isPro: Bool
    private(set) var isWorking = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: SettingsKey.isProCached)
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlements()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.proProductID]).first
        } catch {
            // Leave `product` nil; the paywall shows a retry state.
        }
    }

    func purchase() async {
        guard let product else {
            await loadProduct()
            if self.product == nil {
                errorMessage = String(localized: "The App Store isn't reachable right now. Please try again in a moment.")
            }
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
        if !isPro && errorMessage == nil {
            errorMessage = String(localized: "No previous purchase was found for this Apple Account.")
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
        UserDefaults.standard.set(owned, forKey: SettingsKey.isProCached)
    }
}
