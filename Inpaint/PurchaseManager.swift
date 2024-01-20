//
//  PurchaseManager.swift
//  Inpaint
//
//  Created by wudijimao on 2024/1/17.
//

// PurchaseManager.swift
import Foundation
import StoreKit

// 定义一个购买管理器的类，使用单例模式
class PurchaseManager: NSObject {
    
    // 定义一个共享的实例
    static let shared = PurchaseManager()
    
    // 定义一个产品id的常量
    let productID = "3DPhoto"
    
    // 私有化构造函数，防止外部创建实例
    private override init() {
        super.init()
        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                self.handle(updatedTransaction: verificationResult)
            }
        }
        SKPaymentQueue.default().add(self)
    }
    
    private func handle(updatedTransaction verificationResult: VerificationResult<Transaction>) {
        guard case .verified(let transaction) = verificationResult else {
            // Ignore unverified transactions.
            return
        }
        if transaction.productID == productID {
            isPayed = true
        }
    }
    
    // 定义一个请求产品信息的方法
    func requestProductInfo() async throws -> Product? {
        // 使用StoreKit2的新接口，通过产品id获取产品对象
        let products = try await Product.products(for: [productID])
        // 返回产品对象
        return products.first
    }
    
    // 定义一个购买产品的方法
    func purchaseProduct(product: Product) async -> Bool {
        // 使用StoreKit2的新接口，发起购买请求
        do {
            // 捕获可能抛出的错误
            let result = try await product.purchase()
            switch result {
            case .success(let result):
                return true
            default:
                return false
            }
        } catch {
            return false
        }
    }
    
    var isPayed: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "isPayed")
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: "isPayed")
        }
    }
    
    func purchases() async -> Bool {
        if isPayed {
            return true
        }
        MobClick.event("3dpay")
        guard let product = try? await self.requestProductInfo() else {
            return false
        }
        let isSuccess = await self.purchaseProduct(product: product)
        if isSuccess {
            MobClick.event("3dpayed")
        }
        return isSuccess
    }
    
    // 定义一个恢复购买的方法
    func restorePurchases() async -> Bool {
        if isPayed {
            return true
        }
        // 使用StoreKit2的新接口，恢复购买
        if let result = await Transaction.latest(for: productID) {
            return true
        } else {
            return false
        }
    }
}

extension PurchaseManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        print(transactions)
        for transaction in transactions {
            queue.finishTransaction(transaction)
        }
        
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return true
    }
}
