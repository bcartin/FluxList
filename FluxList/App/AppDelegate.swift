//
//  AppDelegate.swift
//  FluxList
//
//  Created by Bernie Cartin on 2/27/26.
//

import SwiftUI
import FirebaseCore

/// UIKit app delegate used solely to configure Firebase on launch.
///
/// SwiftUI doesn't have a direct equivalent of `didFinishLaunchingWithOptions`,
/// so this delegate is wired into the app via `@UIApplicationDelegateAdaptor`
/// in ``FluxListApp``.
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}
