import Foundation
import UserNotifications

struct ForegroundPolicyReplayResult: Sendable {
    let requestID: String
    let optionsRawValue: UInt
}

enum ForegroundPolicyProbeError: LocalizedError, Sendable {
    case noObservedRequest
    case noDelegate
    case noWillPresentCallback
    case notificationNotDelivered(String)

    var errorDescription: String? {
        switch self {
        case .noObservedRequest:
            return "no observed request"
        case .noDelegate:
            return "no notification delegate"
        case .noWillPresentCallback:
            return "no willPresent callback"
        case let .notificationNotDelivered(identifier):
            return "notification not delivered: \(identifier)"
        }
    }
}

extension UNUserNotificationCenter {
    func replayForegroundNotification(withID identifier: String) async throws
        -> ForegroundPolicyReplayResult {
        for _ in 0..<20 {
            switch await fetchForegroundReplay(identifier: identifier) {
            case .missing:
                try? await Task.sleep(nanoseconds: 250_000_000)
            case let .found(result):
                return result
            case let .failure(error):
                throw error
            }
        }
        throw ForegroundPolicyProbeError.notificationNotDelivered(identifier)
    }

    private func fetchForegroundReplay(identifier: String) async -> ForegroundReplay {
        await withCheckedContinuation { continuation in
            getDeliveredNotifications { notifications in
                guard let notification = notifications.first(where: {
                    $0.request.identifier == identifier
                }) else {
                    continuation.resume(returning: .missing)
                    return
                }

                let center = UNUserNotificationCenter.current()
                guard let delegate = center.delegate else {
                    continuation.resume(returning: .failure(.noDelegate))
                    return
                }

                let callback: ((
                    UNUserNotificationCenter,
                    UNNotification,
                    @escaping @Sendable (UNNotificationPresentationOptions) -> Void
                ) -> Void)? = delegate.userNotificationCenter(_:willPresent:withCompletionHandler:)
                guard let callback else {
                    continuation.resume(returning: .failure(.noWillPresentCallback))
                    return
                }
                callback(center, notification) { options in
                    continuation.resume(
                        returning: .found(
                            ForegroundPolicyReplayResult(
                                requestID: identifier, optionsRawValue: options.rawValue
                            )
                        )
                    )
                }
            }
        }
    }

    private enum ForegroundReplay: Sendable {
        case missing
        case found(ForegroundPolicyReplayResult)
        case failure(ForegroundPolicyProbeError)
    }
}
