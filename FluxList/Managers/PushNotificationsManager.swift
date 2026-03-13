//
//  PushNotificationsManager.swift
//  FluxList
//
//  Created by Bernie Cartin on 3/12/26.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseMessaging

@MainActor @Observable
class PushNotificationsManager: NSObject, UIApplicationDelegate {
    
    private let userManager: UserManager
    
    let unCenter = UNUserNotificationCenter.current()
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var userInfo: [AnyHashable: Any]?
        
    init(
        userManager: UserManager
    ) {
        self.userManager = userManager
        super.init()
    }
    
    func requestPermission() async throws {
        await refreshAuthorizationStatus()

        if authorizationStatus == .notDetermined {
            if try await unCenter.requestAuthorization(options: [.alert, .badge, .sound]) {
                configure()
                saveToken()
                await refreshAuthorizationStatus()
            }
        }
        else if authorizationStatus == .authorized {
            configure()
            saveToken()
        }
    }
    
    /// Fetches the current notification authorization status from the system.
    func refreshAuthorizationStatus() async {
        let settings = await unCenter.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }
    
    func configure() {
        unCenter.delegate = self
        Messaging.messaging().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func didRegisterForNotifications(_ deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        #if DEBUG
        print("APNs token: \(apnsToken)")
        #endif
        Messaging.messaging().apnsToken = deviceToken
        // Fetch the FCM token now that Firebase has the APNs token.
        // This covers the case where didReceiveRegistrationToken was missed.
        saveToken()
        subscribeToNotifications(target: .everyone)
    }
    
}

extension PushNotificationsManager: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        
        userInfo = response.notification.request.content.userInfo
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}

extension PushNotificationsManager: MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        #if DEBUG
        print("Token Received: ", fcmToken ?? "")
        if let apnsToken = messaging.apnsToken {
            print("APNs Token: ", apnsToken)
        }
        #endif
        saveToken(token: fcmToken)
    }
    
    func saveToken(token: String? = nil) {
        if let token = token {
            userManager.saveToken(token)
        }
        else if let token = Messaging.messaging().fcmToken {
            userManager.saveToken(token)
        }
    }
    
    func subscribeToNotifications(target: PushNotificationTarget) {
        Messaging.messaging().subscribe(toTopic: target.rawValue)
    }
    
    func unsubscribeFromNotifications(target: PushNotificationTarget) {
        Messaging.messaging().unsubscribe(fromTopic: target.rawValue)
    }
}

enum PushNotificationTarget: String, CaseIterable {
    
    static var allValues: [String] {
        return allCases.map { $0.rawValue.capitalized }
    }
    
    case everyone
    
}

extension AppDelegate {
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        pushNotificationManager?.didRegisterForNotifications(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        print("Failed to register for notifications")
    }
}
