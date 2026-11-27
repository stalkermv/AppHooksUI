#if os(iOS)
import Testing
import UIKit
@testable import AppHooksUI

@MainActor
struct RemoteNotificationTests {
    @Test
    func noMountedHandlerCompletesWithNoData() {
        let delegate = ApplicationDelegate()
        var results: [RemoteNotificationResult] = []

        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "unhandled"],
            fetchCompletionHandler: { results.append($0) }
        )

        #expect(results == [.noData])
    }

    @Test
    func newestMountedHandlerReceivesPayloadAndCompletesOnce() {
        let delegate = ApplicationDelegate()
        var receivedEvents: [String] = []
        var results: [RemoteNotificationResult] = []
        let firstID = delegate.registerRemoteNotificationHandler { notification in
            receivedEvents.append(notification.userInfo["event"] as? String ?? "missing")
            return .failed
        }
        let secondID = delegate.registerRemoteNotificationHandler { notification in
            receivedEvents.append(notification.userInfo["event"] as? String ?? "missing")
            return .newData
        }
        defer {
            delegate.unregisterRemoteNotificationHandler(firstID)
            delegate.unregisterRemoteNotificationHandler(secondID)
        }

        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "second"],
            fetchCompletionHandler: { results.append($0) }
        )

        #expect(receivedEvents == ["second"])
        #expect(results == [.newData])
        #expect(results.count == 1)
    }

    @Test
    func updatingAHandlerPreservesItsRegistrationPriority() {
        let delegate = ApplicationDelegate()
        var results: [RemoteNotificationResult] = []
        let firstID = delegate.registerRemoteNotificationHandler { _ in .failed }
        let secondID = delegate.registerRemoteNotificationHandler { _ in .newData }
        defer {
            delegate.unregisterRemoteNotificationHandler(firstID)
            delegate.unregisterRemoteNotificationHandler(secondID)
        }

        delegate.updateRemoteNotificationHandler(firstID) { _ in .noData }
        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "priority"],
            fetchCompletionHandler: { results.append($0) }
        )

        #expect(results == [.newData])
    }

    @Test
    func removingSelectedHandlerRestoresTheStillMountedPredecessor() {
        let delegate = ApplicationDelegate()
        var results: [RemoteNotificationResult] = []
        let firstID = delegate.registerRemoteNotificationHandler { _ in .failed }
        let secondID = delegate.registerRemoteNotificationHandler { _ in .noData }
        let thirdID = delegate.registerRemoteNotificationHandler { _ in .newData }
        defer {
            delegate.unregisterRemoteNotificationHandler(firstID)
            delegate.unregisterRemoteNotificationHandler(secondID)
            delegate.unregisterRemoteNotificationHandler(thirdID)
        }

        delegate.unregisterRemoteNotificationHandler(secondID)
        delegate.unregisterRemoteNotificationHandler(thirdID)
        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "predecessor"],
            fetchCompletionHandler: { results.append($0) }
        )

        #expect(results == [.failed])
    }

    @Test
    func removingAnUnselectedHandlerDoesNotChangeTheCurrentHandler() {
        let delegate = ApplicationDelegate()
        var results: [RemoteNotificationResult] = []
        let firstID = delegate.registerRemoteNotificationHandler { _ in .failed }
        let secondID = delegate.registerRemoteNotificationHandler { _ in .newData }
        defer {
            delegate.unregisterRemoteNotificationHandler(firstID)
            delegate.unregisterRemoteNotificationHandler(secondID)
        }

        delegate.unregisterRemoteNotificationHandler(firstID)
        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "current"],
            fetchCompletionHandler: { results.append($0) }
        )

        #expect(results == [.newData])
    }

    @Test
    func staleRegistrationUpdatesAndRemovalAreIgnored() {
        let delegate = ApplicationDelegate()
        var results: [RemoteNotificationResult] = []
        let id = delegate.registerRemoteNotificationHandler { _ in .newData }
        defer { delegate.unregisterRemoteNotificationHandler(id) }

        delegate.updateRemoteNotificationHandler(UUID()) { _ in .failed }
        delegate.unregisterRemoteNotificationHandler(UUID())
        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "stale"],
            fetchCompletionHandler: { results.append($0) }
        )

        #expect(results == [.newData])
    }

    @Test
    func remountReceivesOnlyFutureNotifications() {
        let delegate = ApplicationDelegate()
        var results: [RemoteNotificationResult] = []
        let initialID = delegate.registerRemoteNotificationHandler { _ in .newData }
        delegate.unregisterRemoteNotificationHandler(initialID)

        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "gap"],
            fetchCompletionHandler: { results.append($0) }
        )

        let remountedID = delegate.registerRemoteNotificationHandler { _ in .failed }
        defer { delegate.unregisterRemoteNotificationHandler(remountedID) }
        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["event": "remounted"],
            fetchCompletionHandler: { results.append($0) }
        )

        #expect(results == [.noData, .failed])
    }
}
#endif
