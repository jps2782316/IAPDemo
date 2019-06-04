//
//  ViewController.swift
//  InAppPurchase
//
//  Created by jps on 2019/6/3.
//  Copyright © 2019 jps. All rights reserved.
//

import UIKit

import StoreKit


//处理ipv6和内购(IAP)及掉单问题的正确姿势  https://www.jianshu.com/p/b7195675ffdd

//iOS 内购最新讲解 https://juejin.im/entry/5b2a1eae6fb9a00e562c46ef

//iOS Swift 开发内购实现 SwiftyStoreKit https://www.jianshu.com/p/172d557965b7

//iOS开发swift -- APP内购的实现 https://www.jianshu.com/p/9b2ec7fed484


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
//        
//        //1.当用户点击了一个IAP项目，我们先查询用户是否允许应用内付费，如果不允许则不用进行以下步骤了
//        let canPayments = SKPaymentQueue.canMakePayments()
//        if canPayments {
//            
//        }else {
//            print("用户禁止应用内付费购买")
//        }
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        //点击购买
//        // 1.拿到所有可卖商品的ID数组
//        let productIdentifiers: Set<String> = ["a", "b", "c"]
//        IAPManager.default.start(productIdentifiers: productIdentifiers, successBlock: { () -> Order in
//            return (productIdentifiers: "a", applicationUsername: "该用户的id或改用户的唯一标识符")
//        }, receiptBlock: { (receipt, transaction, queue) in
//            //交易成功返回了凭证
//            //let data = IAPManager.
//        }) { (error) in
//            print(error)
//        }
        
        
        IAPManager2.default.requestProductID()
        
    }
    
}




