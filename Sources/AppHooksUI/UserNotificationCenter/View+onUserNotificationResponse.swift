//
//  View+OnReceiveUserNotification.swift
//
//  Created by Valeriy Malishevskyi on 10.10.2024.
//

import SwiftUI
import UserNotifications

extension View {
    /// Attaches an action to be performed when a user notification response is received.
    ///
    /// This method applies a custom view modifier that listens for incoming
    /// `UNNotificationResponse` instances and triggers the provided action when a
    /// user responds to a notification, such as interacting with it or dismissing it.
    ///
    /// - Parameter action: A closure that handles the received `UNNotificationResponse`.
    ///   The closure is marked as `@Sendable` to ensure thread safety when invoked.
    /// - Returns: A view that listens for user notification responses and performs the action.
    ///
    /// Usage:
    /// ```swift
    /// .onUserNotificationResponse { response in
    ///     // Handle the notification response
    ///     print("User responded to notification: \(response.notification)")
    /// }
    /// ```
    public func onUserNotificationResponse(perform action: @escaping (UNNotificationResponse) -> Void) -> some View {
        modifier(ReceiveUserNotificationViewModifier(action: action))
    }
}

struct ReceiveUserNotificationViewModifier: ViewModifier {
    @Environment(\.userNotificationCenter) var userNotificationCenter
    let action: (UNNotificationResponse) -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(userNotificationCenter.receiveResponseNotificationSubject) { response in
                action(response)
            }
        
    }
}
