import Foundation

#if os(iOS)
import UIKit
/// The result returned synchronously to UIKit by the remote-notification hook.
public typealias RemoteNotificationResult = UIBackgroundFetchResult

/// The payload delivered synchronously to a mounted background-push handler.
public struct PushNotification {
    public let userInfo: [AnyHashable: Any]

    public init(userInfo: [AnyHashable: Any]) {
        self.userInfo = userInfo
    }
}
#endif
