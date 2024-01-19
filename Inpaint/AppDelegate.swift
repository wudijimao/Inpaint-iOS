//
//  AppDelegate.swift
//  Inpaint
//
//  Created by wudijimao on 2023/11/30.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        UMConfigure.initWithAppkey("65aa6034a7208a5af1a0825a", channel: "App Store")
        _ = PurchaseManager.shared
        return true
    }


}

