//
//  UserNotificationCenter.swift
//  AppHooksUI
//

#if os(iOS) || os(macOS)
import Foundation
import UserNotifications

/// Package-owned `UNUserNotificationCenterDelegate` plumbing.
///
/// View modifiers register handlers with this object while they are mounted.
/// Registration is protected by a lock because UserNotifications may invoke
/// its delegate off the main actor.
final class UserNotificationCenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    typealias PresentationHandler = @Sendable (UNNotification) async -> UNNotificationPresentationOptions

    let responseSubject = BufferedPassthroughSubject<UNNotificationResponse, Never>()

    private let lock = NSLock()
    private var presentationHandlers: [UUID: PresentationHandler] = [:]
    private var presentationOrder: [UUID] = []

    func registerPresentationHandler(_ handler: @escaping PresentationHandler) -> UUID {
        let id = UUID()
        lock.withLock {
            presentationHandlers[id] = handler
            presentationOrder.append(id)
        }
        return id
    }

    func unregisterPresentationHandler(_ id: UUID) {
        lock.withLock {
            presentationHandlers.removeValue(forKey: id)
            presentationOrder.removeAll { $0 == id }
        }
    }

    /// Replaces a mounted policy without changing its precedence.
    func updatePresentationHandler(_ id: UUID, _ handler: @escaping PresentationHandler) {
        lock.withLock {
            guard presentationHandlers[id] != nil else { return }
            presentationHandlers[id] = handler
        }
    }

    var currentPresentationHandler: PresentationHandler? {
        lock.withLock {
            presentationOrder.last.flatMap { presentationHandlers[$0] }
        }
    }

    /// Called when a notification arrives while the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard let handler = currentPresentationHandler else { return [] }
        return await handler(notification)
    }

    /// Called when the user interacts with a delivered notification.
    ///
    /// The response is enqueued synchronously before the system callback is
    /// completed. This acknowledgement does not wait for SwiftUI actions.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        responseSubject.send(response)
        completionHandler()
    }
}
#endif
