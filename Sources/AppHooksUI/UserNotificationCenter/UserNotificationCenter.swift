//
//  UserNotificationCenter.swift
//
//  Created by Valeriy Malishevskyi on 10.10.2024.
//

import Foundation
import UserNotifications
import Combine

/// A notification center wrapper that delegates `UNUserNotificationCenter` events.
public final class UserNotificationCenter: NSObject, ObservableObject, @unchecked Sendable {
    
    /// Allows dynamic control of how foreground notifications are presented.
    public var presentationOptions: (UNNotification) async -> UNNotificationPresentationOptions = { _ in [] }

    /// Publisher for notification response events (e.g. when the user taps a notification).
    public var receiveResponseNotificationSubject = PassthroughSubject<UNNotificationResponse, Never>()

    override public init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
}

extension UserNotificationCenter: UNUserNotificationCenterDelegate {
    
    /// Called when a notification is delivered while the app is in the foreground.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return await presentationOptions(notification)
    }

    /// Called when the user interacts with a delivered notification.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            receiveResponseNotificationSubject.send(response)
        }
    }
}

// Retain sendability conformance for UNNotificationResponse
extension UNNotificationResponse: @unchecked @retroactive Sendable { }
