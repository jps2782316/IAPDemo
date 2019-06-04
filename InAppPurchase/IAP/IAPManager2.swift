//
//  IAPManager2.swift
//  InAppPurchase
//
//  Created by jps on 2019/6/3.
//  Copyright © 2019 jps. All rights reserved.
//

import Foundation
import StoreKit

class IAPManager2: NSObject {
    
    static let `default` = IAPManager2()
    
    private var sandBoxURLString = "https://sandbox.itunes.apple.com/verifyReceipt"
    private var buyURLString = "https://buy.itunes.apple.com/verifyReceipt"
    
    
    var selectedOrder: Order = (productIdentifiers: "a", applicationUsername: "该用户的id或改用户的唯一标识符")
    
    
    private override init() {
        super.init()
        //添加观察者，监听用户是否付钱成功
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    
    ///1.请求所有的商品ID
    func requestProductID() {
        
        // 1.拿到所有可卖商品的ID数组 (这一步放到控制器去了)
        let productIdentifiers: Set<String> = ["a", "b", "c"]
        
        // 2.向苹果发送请求，请求所有可买的商品
        // 2.1.创建请求对象
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        // 2.2.设置代理(在代理方法里面获取所有的可卖的商品)
        request.delegate = self
        // 2.3.开始请求
        request.start()
    }
    
    
//    /// 购买给定的order的产品
//    private func buy(order: Order) {
//
//        //找出可购买数组里id和订单id相同的产品
//        let p = products.first { $0.productIdentifier == order.productIdentifiers }
//
//        guard let product = p else { failBlock?(.noExist); return }
//        guard SKPaymentQueue.canMakePayments() else { failBlock?(.noPermission); return }
//
//        // 1.创建票据
//        let payment = SKMutablePayment(product: product)
//        /// 发起支付时候指定用户的username, 在掉单时候验证防止切换账号导致充值错误
//        payment.applicationUsername = order.applicationUsername
//        // 2.将票据加入到交易队列，发起购买请求
//        SKPaymentQueue.default().add(payment)
//    }
    
    
    ///内购的代码调用
    private func buy(product: SKProduct) {
        //1.当用户点击了一个IAP项目，我们先查询用户是否允许应用内付费，如果不允许则不用进行以下步骤了
        let canPayments = SKPaymentQueue.canMakePayments()
        if canPayments {
            // 1.创建票据
            let payment = SKMutablePayment(product: product)
            /// 发起支付时候指定用户的username, 在掉单时候验证防止切换账号导致充值错误
            payment.applicationUsername = selectedOrder.applicationUsername
            // 2.将票据加入到交易队列，发起购买请求
            SKPaymentQueue.default().add(payment)
        }else {
            print("用户禁止应用内付费购买")
        }
        
    }
    
}



//MARK: SKProductsRequestDelegate
extension IAPManager2: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        //打印商品信息
        printProductInfo(response: response)
        
        //可卖商品数组
        let productList = response.products
        
//        for product in productList {
//            if product.productIdentifier == selectedOrder.productIdentifiers {
//                buy(product: product)
//            }
//        }
        
        let order = selectedOrder
        //找出可购买数组里id和订单id相同的产品
        let p = productList.first { $0.productIdentifier == order.productIdentifiers }
        if p != nil {
            buy(product: p!)
        }
        
        
        
        //发起购买
        //buy(order)
        
        
        
        
    }
    
    
    private func printProductInfo(response: SKProductsResponse) {
        print("******************* 收到产品信息 *******************")
        let productList = response.products
        print("可卖商品数量\(productList.count)")
        print("产品id: \(response.invalidProductIdentifiers)")
        print("产品付费数量: \(productList.count)")
        
        if productList.count == 0 {
            print("没有商品")
            return
        }
        
        for product in productList {
            print("SKProduct描述信息\(product.description)")
            print("产品标题\(product.localizedTitle)")
            print("产品描述信息\(product.localizedDescription)")
            print("价格\(product.price)")
            print("product id: \(product.productIdentifier)")
        }
    }
}


//MARK: SKPaymentTransactionObserver 实现观察者监听付钱的代理方法,只要交易发生变化就会走下面的方法
extension IAPManager2: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            let transState = transaction.transactionState
            
            switch transState {
            case .purchased:
                //向服务器验证
                //buyAppleStoreProductSuccessd(transaction: transaction, queue: queue)
                
                //客户端直接向苹果服务器验证
                verifyPurchase(transaction: transaction, isTestServer: false)
                
                
                // 注意：记住一定要请求自己的服务器成功之后, 再移除此次交易
                // 购买后告诉交易队列，把这个成功的交易移除掉
                //queue.finishTransaction(transaction)
                
            case .failed:
                // 购买失败也要把这个交易移除掉
                queue.finishTransaction(transaction)
                
            case .restored: // 购买过 对于购买过的商品, 回复购买的逻辑
                print("回复购买中,也叫做已经购买")
                // 回复购买中也要把这个交易移除掉
                queue.finishTransaction(transaction)
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
    
    
    ///1. 向服务器验证
    private func buyAppleStoreProductSuccessd(transaction: SKPaymentTransaction, queue: SKPaymentQueue) {
        
        let productIdentifier = transaction.payment.productIdentifier
        
        // 验证凭据，获取到苹果返回的交易凭据
        // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
        guard let receiptUrl = Bundle.main.appStoreReceiptURL,
            // 从沙盒中获取到购买凭据
            let receiptData = NSData(contentsOf: receiptUrl) else {
                return
        }
        // 传输的是BASE64编码的字符串
        let receiptString = receiptData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        // 去验证是否真正的支付成功了
        checkAppStorePayResult(receipt: receiptString, transaction: transaction, queue: queue)
        
    }
    
    
    func checkAppStorePayResult(receipt: String, transaction: SKPaymentTransaction, queue: SKPaymentQueue) {
        /* 生成订单参数，注意沙盒测试账号与线上正式苹果账号的验证途径不一样，要给后台标明
         请求后台接口，服务器处验证是否支付成功，依据返回结果做相应逻辑处理
         */
        
        /*
        //交易成功返回了凭证
        let data = InpurchaseAPIData(accountID: transaction.payment.applicationUsername,
                                     transactionID: transaction.transactionIdentifier,
                                     receiptData: receipt)
        LPNetworkManager.request(Router.verifyReceipt(data)).showToast().loading(in: self.view).success {[weak self] in
            showToast("购买成功")
            // 记住一定要请求自己的服务器成功之后, 再移除此次交易
            queue.finishTransaction(transaction)
            
            }.fail {
                print("向服务器发送凭证失败")
        }
         */
    }
    
    
    
    ///2. 客户端验证购买凭据 (自己向苹果发送验证)
    func verifyPurchase(transaction: SKPaymentTransaction, isTestServer: Bool)  {
        // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
        guard let receiptUrl = Bundle.main.appStoreReceiptURL,
            // 从沙盒中获取到购买凭据
            let receiptData = NSData(contentsOf: receiptUrl) else {
                return
        }
        // 传输的是BASE64编码的字符串
        let receiptString = receiptData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        let requestContents = ["receipt-data": receiptString]
        do {
            let requestData = try JSONSerialization.data(withJSONObject: requestContents, options: [])
            
            guard let storeUrl = URL(string: sandBoxURLString) else { return }
            let storeRequest = NSMutableURLRequest(url: storeUrl)
            storeRequest.httpMethod = "POST"
            storeRequest.httpBody = requestData
            storeRequest.timeoutInterval = 20
            storeRequest.addValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
            let session = URLSession.shared
            let task = session.dataTask(with: storeRequest as URLRequest) { (data, response, error) in
                if (error != nil) {
                    // 无法连接服务器,购买校验失败
                }else {
                    do {
                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.init(rawValue: 0)) as? [String: Any]
                        // 先验证正式服务器,如果正式服务器返回21007再去苹果测试服务器验证,沙盒测试环境苹果用的是测试服务器
                        guard let status = jsonResponse?["status"] as? String else { return }
                        if status == "21007" {
                            
                        }else if status == "0" {
                            
                        }
                    }catch {
                        // 苹果服务器校验数据返回为空校验失败
                    }
                    
                    
                }
            }
            task.resume()
        }catch {
            // 交易凭证为空验证失败
            print(error)
        }
        
        
        
    }
    
    
    
}




/*
 
 内购验证凭据返回结果状态码说明
 
 21000 App Store无法读取你提供的JSON数据
 
 21002 收据数据不符合格式
 
 21003 收据无法被验证
 
 21004 你提供的共享密钥和账户的共享密钥不一致
 
 21005 收据服务器当前不可用
 
 21006 收据是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
 
 21007 收据信息是测试用（sandbox），但却被发送到产品环境中验证
 
 21008 收据信息是产品环境中使用，但却被发送到测试环境中验证
 
 */




/**
 
 BASE64 常用的编码方案，通常用于数据传输，以及加密算法的基础算法，传输过程中能够保证数据传输的稳定性
 
 BASE64是可以编码和解码的
 
 */
