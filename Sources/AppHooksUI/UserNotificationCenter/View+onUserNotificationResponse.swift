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
    public func onUserNotificationResponse(perform action: @escaping @Sendable @MainActor (UNNotificationResponse) -> Void) -> some View {
        modifier(ReceiveUserNotificationViewModifier(action: action))
    }
}

struct ReceiveUserNotificationViewModifier: ViewModifier {
    @EnvironmentObject private var delegate: ApplicationDelegate
    let action: (UNNotificationResponse) -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(delegate.userNotificationCenter.receiveResponseNotificationSubject.receive(on: RunLoop.main)) { response in
                if let response {
                    action(response)
                }
            }
    }
}
