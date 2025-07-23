//
//  UserNotificationCenter.swift
//
//  Created by Valeriy Malishevskyi on 10.10.2024.
//

import Foundation
import UserNotifications
import Combine

/// A notification center wrapper that delegates `UNUserNotificationCenter` events.
@MainActor public final class UserNotificationCenter: NSObject, ObservableObject, @unchecked Sendable {
    
    /// Allows dynamic control of how foreground notifications are presented.
    public var presentationOptions: @Sendable (UNNotification) async -> UNNotificationPresentationOptions = { _ in [] }

    /// Publisher for notification response events (e.g. when the user taps a notification).
    public var receiveResponseNotificationSubject = CurrentValueSubject<UNNotificationResponse?, Never>(nil)

    override nonisolated public init() {
        super.init()
    }
}

extension UserNotificationCenter: UNUserNotificationCenterDelegate {
    
    /// Called when a notification is delivered while the app is in the foreground.
    public nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return await presentationOptions(notification)
    }

    /// Called when the user interacts with a delivered notification.
    
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [self] in
            receiveResponseNotificationSubject.send(response)
        }
        completionHandler()
    }
}

// Retain sendability conformance for UNNotificationResponse
extension UNNotificationResponse: @unchecked @retroactive Sendable { }
