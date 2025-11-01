//
//  OneSignalManager.swift
//  VRM
//
//  OneSignal Push Notification Manager
//

import Foundation
import Combine
import UserNotifications
import OneSignalFramework

// Notification for when a notification with character data is clicked
extension Notification.Name {
    static let openCharacterChat = Notification.Name("openCharacterChat")
}

struct CharacterNotificationData {
    let characterId: String
    let openChat: Bool
}

class OneSignalManager: NSObject, OSNotificationLifecycleListener, OSNotificationClickListener, OSPushSubscriptionObserver {
    static let shared = OneSignalManager()
    private let appId = "4e5ce2e7-754e-4a63-857b-4175c92fcbd6"
    
    private override init() {
        super.init()
    }
    
    /// Initialize OneSignal (should be called from App init)
    func initialize() {
        // Set log level for debugging (remove in production)
        #if DEBUG
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        #else
        OneSignal.Debug.setLogLevel(.LL_ERROR)
        #endif
        
        // Register Communication Notification Category
        registerCommunicationNotificationCategory()
        
        // Initialize OneSignal
        OneSignal.initialize(appId, withLaunchOptions: nil)
        
        // Request notification permissions
        OneSignal.Notifications.requestPermission({ [weak self] accepted in
            if accepted {
                print("OneSignal: Notification permission granted")
                self?.logPushSubscriptionId()
            } else {
                print("OneSignal: Notification permission denied")
            }
        }, fallbackToSettings: true)
        
        // Set up notification handlers
        setupNotificationHandlers()
    }
    
    /// Register Communication Notification Category for avatar display
    private func registerCommunicationNotificationCategory() {
        let center = UNUserNotificationCenter.current()
        
        // Create communication category with proper options for avatar display
        // Use UNNotificationCategoryOptions.hiddenPreviewsShowSubtitle for better display
        let communicationCategory = UNNotificationCategory(
            identifier: "CHARACTER_MESSAGE",
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "%@",
            options: [
                .customDismissAction,
                .allowAnnouncement,
                .allowInCarPlay
            ]
        )
        
        // Register the category
        center.setNotificationCategories([communicationCategory])
        
        print("OneSignal: Registered Communication Notification Category")
    }
    
    /// Set up notification event handlers
    private func setupNotificationHandlers() {
        // Handle notification received while app is in foreground
        OneSignal.Notifications.addForegroundLifecycleListener(self)
        
        // Handle notification clicked
        OneSignal.Notifications.addClickListener(self)
        
        // Handle push subscription changes
        OneSignal.User.pushSubscription.addObserver(self)
    }
    
    /// Get the current push subscription ID
    func logPushSubscriptionId() {
        if let subscriptionId = OneSignal.User.pushSubscription.id {
            print("OneSignal: Push Subscription ID: \(subscriptionId)")
        }
    }
    
    /// Send a tag to OneSignal (for user segmentation)
    func setTag(key: String, value: String) {
        OneSignal.User.addTags([key: value])
    }
    
    /// Remove a tag
    func removeTag(key: String) {
        OneSignal.User.removeTags([key])
    }
    
    /// Set user email for notifications
    func setEmail(_ email: String) {
        OneSignal.User.addEmail(email)
    }
    
    /// Set user external ID (useful for linking to your user database)
    func setExternalUserId(_ userId: String) {
        OneSignal.login(userId)
    }
    
    /// Clear external user ID (for logout)
    func clearExternalUserId() {
        OneSignal.logout()
    }
    
    // MARK: - OSNotificationLifecycleListener
    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        print("OneSignal: Notification will display: \(event.notification.notificationId ?? "unknown")")
        // You can customize the behavior here, e.g., show an in-app banner
        // To prevent the system notification from showing: event.notification.display()
    }
    
    // MARK: - OSNotificationClickListener
    func onClick(event: OSNotificationClickEvent) {
        print("OneSignal: Notification clicked: \(event.notification.notificationId ?? "unknown")")
        
        // Handle deep links or custom actions from notification payload
        if let additionalData = event.notification.additionalData {
            print("OneSignal: Additional data: \(additionalData)")
            
            // Extract character_id from notification data
            if let characterId = additionalData["character_id"] as? String,
               let openChat = additionalData["open_chat"] as? String,
               openChat == "true" {
                // Post notification to open character chat
                let data = CharacterNotificationData(characterId: characterId, openChat: true)
                NotificationCenter.default.post(
                    name: .openCharacterChat,
                    object: nil,
                    userInfo: ["data": data]
                )
            }
        }
    }
    
    // MARK: - OSPushSubscriptionObserver
    func onPushSubscriptionDidChange(state stateChanges: OSPushSubscriptionChangedState) {
        if stateChanges.current.id != nil && stateChanges.previous.id == nil {
            print("OneSignal: User opted in to push notifications")
        } else if stateChanges.current.id == nil && stateChanges.previous.id != nil {
            print("OneSignal: User opted out of push notifications")
        }
    }
}
