//
//  View+onReceiveRemoteNotification.swift
//
//  Created by Valeriy Malishevskyi on 12.11.2024.
//

import SwiftUI
import Combine

/// A wrapper for the payload of a received push notification.
public struct PushNotification {
    public let userInfo: [AnyHashable: Any]
}

#if os(iOS)
import UIKit
public typealias RemoteNotificationResult = UIBackgroundFetchResult
#else
public enum RemoteNotificationResult {
    case noData
    case newData
    case failed
}
#endif

extension View {

    /// Registers a handler for incoming push notifications.
    /// On macOS, this is a no-op.
    public func onReceiveRemoteNotification(_ handler: @escaping (PushNotification) -> RemoteNotificationResult) -> some View {
        #if os(iOS)
        return modifier(ReceiveRemoteNotificationViewModifier(handler))
        #else
        return self // No-op on macOS
        #endif
    }
}

#if os(iOS)
struct ReceiveRemoteNotificationViewModifier: ViewModifier {

    @EnvironmentObject var appDelegate: ApplicationDelegate
    let handler: (PushNotification) -> RemoteNotificationResult
    
    init(_ handler: @escaping (PushNotification) -> RemoteNotificationResult) {
        self.handler = handler
    }
    
    func body(content: Content) -> some View {
        content
            .onReceive(appDelegate.didReceiveRemoteNotification) { notification in
                let result = handler(PushNotification(userInfo: notification.userInfo))
                notification.completionHandler(result)
            }
    }
}
#endif
