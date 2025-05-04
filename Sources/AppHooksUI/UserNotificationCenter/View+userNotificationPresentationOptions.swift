//
//  View+OnPresentUserNotification.swift
//
//  Created by Valeriy Malishevskyi on 10.10.2024.
//

import SwiftUI
import UserNotifications

extension View {
    /// Modifies the view to handle dynamic presentation options for incoming user notifications.
    ///
    /// This method applies a custom view modifier that allows the view to control the
    /// `UNNotificationPresentationOptions` for each incoming notification by providing
    /// an asynchronous closure that returns the presentation options.
    ///
    /// - Parameter presentationOptions: An asynchronous closure that returns the desired
    ///   `UNNotificationPresentationOptions` for a received `UNNotification`.
    /// - Returns: A view that dynamically controls the presentation behavior of user notifications.
    ///
    /// Usage:
    /// ```swift
    /// .userNotificationPresentationOptions { notification in
    ///     // Determine the presentation options for each notification
    ///     return [.alert, .badge]
    /// }
    /// ```
    public func userNotificationPresentationOptions(_ presentationOptions: @escaping (UNNotification) async -> UNNotificationPresentationOptions) -> some View {
        modifier(PresentUserNotificationViewModifier(presentationOptions))
    }
    
    /// Modifies the view to handle fixed presentation options for all incoming user notifications.
    ///
    /// This method applies a custom view modifier that sets a fixed value for
    /// `UNNotificationPresentationOptions` for all notifications received by the view.
    ///
    /// - Parameter options: The `UNNotificationPresentationOptions` to apply to all received notifications.
    /// - Returns: A view that uses the specified presentation options for all notifications.
    ///
    /// Usage:
    /// ```swift
    /// .userNotificationPresentationOptions([.alert, .sound])
    /// ```
    public func userNotificationPresentationOptions(_ options: UNNotificationPresentationOptions) -> some View {
        modifier(PresentUserNotificationViewModifier({ _ in options }))
    }
}

struct PresentUserNotificationViewModifier: ViewModifier {
    let presentationOptions: (UNNotification) async ->  UNNotificationPresentationOptions
    
    init(_ presentationOptions: @escaping (UNNotification) async -> UNNotificationPresentationOptions) {
        self.presentationOptions = presentationOptions
    }
    
    func body(content: Content) -> some View {
        content
            .transformEnvironment(\.userNotificationCenter) {
                $0.presentationOptions = presentationOptions
            }
    }
}

