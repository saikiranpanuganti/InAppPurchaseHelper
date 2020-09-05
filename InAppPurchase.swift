//
//  InAppPurchase.swift
//  Weyyak
//
//  Created by Saikiran.Panuganti on 21/07/20.
//  Copyright © 2020 Saikiran Panuganti. All rights reserved.
//

import Foundation
import StoreKit

protocol InAppPurchaseDelegate : class {
    func cannotMakePayments()
    func failedToLoadRequest()
    func purchaseCancelled()
    func purchaseFailed()
    func validateReceipt(orderId : String, receipt : String)
    func hideLoadingIndicator()
}

protocol InAppPurchaseRestoreDelegate : class {
    func validateRestoreReceipt(receipt : String)
    func hideLoadingIndicator()
}

class InAppPurchase : NSObject {
    
    static let shared : InAppPurchase = InAppPurchase()
    weak var delegate : InAppPurchaseDelegate?
    weak var restoreDelegate : InAppPurchaseRestoreDelegate?
    var orderId : String?
    var productReference : String?
    
    
    override init() {
        super.init()
        
        SKPaymentQueue.default().add(self)
    }
    
    func unlockProduct(orderIdString : String, productReferenceString : String) {
        if SKPaymentQueue.canMakePayments() {
            orderId = orderIdString
            productReference = productReferenceString
            
            let producId : NSSet = NSSet(object: productReferenceString)
            let productRequest : SKProductsRequest = SKProductsRequest(productIdentifiers: producId as! Set<String>)
            productRequest.delegate = self
            productRequest.start()
        }else {
            delegate?.cannotMakePayments()
        }
    }
    
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    func validateReceipt() {
        let receiptFileURL = Bundle.main.appStoreReceiptURL
        let receiptData = try? Data(contentsOf: receiptFileURL!)
        let receiptString = receiptData?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)) ?? ""
        
        delegate?.validateReceipt(orderId: orderId ?? "", receipt: receiptString)
    }
    
    func validateRestoreReceipt() {
        let receiptFileURL = Bundle.main.appStoreReceiptURL
        let receiptData = try? Data(contentsOf: receiptFileURL!)
        let receiptString = receiptData?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)) ?? ""
        
        restoreDelegate?.validateRestoreReceipt(receipt: receiptString)
    }
}


extension InAppPurchase : SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let count: Int = response.products.count
        if count > 0 {
            let validProduct: SKProduct = response.products[0]
            
            let payment = SKPayment(product: validProduct)
            SKPaymentQueue.default().add(payment)
        }
        else {
            delegate?.failedToLoadRequest()
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print(error.localizedDescription)
        delegate?.failedToLoadRequest()
    }
}

extension InAppPurchase : SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                print(transaction.transactionIdentifier! as String)
                SKPaymentQueue.default().finishTransaction(transaction)
                validateReceipt()
                return
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
                validateReceipt()
                break
            case .restored:
                print(transaction.transactionIdentifier! as String, transaction.original! as Any)
                SKPaymentQueue.default().finishTransaction(transaction)
                validateRestoreReceipt()
                return
            case .deferred:
                delegate?.hideLoadingIndicator()
                restoreDelegate?.hideLoadingIndicator()
                break
            default:
                delegate?.hideLoadingIndicator()
                restoreDelegate?.hideLoadingIndicator()
                break
            }
        }
    }
}
