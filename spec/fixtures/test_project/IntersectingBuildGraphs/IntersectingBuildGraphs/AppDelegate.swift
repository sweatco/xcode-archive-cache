//
//  AppDelegate.swift
//  IntersectingBuildGraphs
//
//  Created by Ilya Dyakonov on 7/29/20.
//  Copyright © 2020 xcode-archive-test. All rights reserved.
//

import UIKit
import KeychainAccess
import Dependency

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let _ = Dependency()
        let _ = Keychain()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
