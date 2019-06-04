//
//  IAPManager.swift
//  InAppPurchase
//
//  Created by jps on 2019/6/3.
//  Copyright © 2019 jps. All rights reserved.
//

import Foundation
import StoreKit

enum IAPError: Error {
    /// 没有内购许可
    case noPermission
    /// 不存在该商品: 商品未在appstore中\商品已经下架
    case noExist
    /// 交易结果未成功
    case failTransactions
    /// 交易成功但未找到成功的凭证
    case noReceipt
}

typealias Order = (productIdentifiers: String, applicationUsername: String)


class IAPManager: NSObject {
    static let `default` = IAPManager()
    
    /// 掉单/未完成的订单回调 (凭证, 交易, 交易队列)
    var unFinishedTransaction: ((String, SKPaymentTransaction, SKPaymentQueue) -> ())?
    
    private var sandBoxURLString = "https://sandbox.itunes.apple.com/verifyReceipt"
    private var buyURLString = "https://buy.itunes.apple.com/verifyReceipt"
    
    /// 保证每次只能有一次交易
    private var isComplete: Bool = true
    private var products: [SKProduct] = []
    private var failBlock: ((IAPError) -> ())?
    
    /// 交易完成的回调 (凭证, 交易, 交易队列)
    private var receiptBlock: ((String, SKPaymentTransaction, SKPaymentQueue) -> ())?
    private var successBlock: (() -> Order)?
    
    
    private override init() {
        super.init()
        //添加观察者，监听用户是否付钱成功
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    /// 开始向Apple Store请求产品列表数据，并购买指定的产品，得到Apple Store的Receipt，失败回调
    ///
    /// - Parameters:
    ///   - productIdentifiers: 请求指定产品
    ///   - successBlock: 请求产品成功回调，这个时候可以返回需要购买的产品ID和用户的唯一标识，默认为不购买
    ///   - receiptBlock: 得到Apple Store的Receipt和transactionIdentifier，这个时候可以将数据传回后台或者自己去post到Apple Store
    ///   - failBlock: 失败回调
    func start(productIdentifiers: Set<String>,
               successBlock: (() -> Order)? = nil,
               receiptBlock: ((String, SKPaymentTransaction, SKPaymentQueue) -> ())? = nil,
               failBlock: ((IAPError) -> ())? = nil) {
        
        guard isComplete else { return }
        defer { isComplete = false }
        
        
        // 1.拿到所有可卖商品的ID数组 (这一步放到控制器去了)
        //let productIdentifiers: Set<String> = ["a", "b", "c"]
        
        // 2.向苹果发送请求，请求所有可买的商品
        // 2.1.创建请求对象
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        // 2.2.设置代理(在代理方法里面获取所有的可卖的商品)
        request.delegate = self
        // 2.3.开始请求
        request.start()
        
        
        self.successBlock = successBlock
        self.receiptBlock = receiptBlock
        self.failBlock = failBlock
    }
    
    
    /// 购买给定的order的产品
    private func buy(_ order: Order) {
        
        //找出可购买数组里id和订单id相同的产品
        let p = products.first { $0.productIdentifier == order.productIdentifiers }
        
        guard let product = p else { failBlock?(.noExist); return }
        guard SKPaymentQueue.canMakePayments() else { failBlock?(.noPermission); return }
        
        // 1.创建票据
        let payment = SKMutablePayment(product: product)
        /// 发起支付时候指定用户的username, 在掉单时候验证防止切换账号导致充值错误
        payment.applicationUsername = order.applicationUsername
        // 2.将票据加入到交易队列，发起购买请求
        SKPaymentQueue.default().add(payment)
    }
    
    
}

//MARK: SKProductsRequestDelegate
extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        products = response.products
        guard let order = successBlock?() else { return }
        //发起购买
        buy(order)
        
        print("******************* 收到产品信息 *******************")
        let productArr = response.products
        print("产品id: \(response.invalidProductIdentifiers)")
        print("产品付费数量: \(productArr.count)")
        
        if productArr.count == 0 {
            print("没有商品")
            return
        }
        print("可卖商品数量\(productArr.count)")
        for product in productArr {
            print("SKProduct描述信息\(product.description)")
            print("产品标题\(product.localizedTitle)")
            print("产品描述信息\(product.localizedDescription)")
            print("价格\(product.price)")
            print("product id: \(product.productIdentifier)")
        }
    }
}


//MARK: SKPaymentTransactionObserver 实现观察者监听付钱的代理方法,只要交易发生变化就会走下面的方法
extension IAPManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            let transState = transaction.transactionState
            
            switch transState {
            case .purchased:
                // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
                guard let receiptUrl = Bundle.main.appStoreReceiptURL,
                    let receiptData = NSData(contentsOf: receiptUrl) else {
                        failBlock?(.noReceipt)
                        return
                }
                let receiptString = receiptData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
                if let receiptBlock = receiptBlock {
                    receiptBlock(receiptString, transaction, queue)
                }else { // app启动时恢复购买记录
                    unFinishedTransaction?(receiptString, transaction, queue)
                }
                isComplete = true
                
                // 购买后告诉交易队列，把这个成功的交易移除掉
                //[queue finishTransaction:transaction];
            
            case .failed:
                failBlock?(.failTransactions)
                //// 购买失败也要把这个交易移除掉
                queue.finishTransaction(transaction)
                isComplete = true
                
            case .restored: // 购买过 对于购买过的商品, 回复购买的逻辑
                print("回复购买中,也叫做已经购买")
                // 回复购买中也要把这个交易移除掉
                queue.finishTransaction(transaction)
                isComplete = true
                break
                
            case .purchasing: //正在购买
                print("商品已经添加进列表")
                break
            
            case .deferred:
                print("交易还在队列里面，但最终状态还没有决定")
                break
                
            @unknown default:
                break
            }
        }
    }
}

