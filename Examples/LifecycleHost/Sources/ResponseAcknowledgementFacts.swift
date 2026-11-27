import Foundation

final class ResponseAcknowledgementFacts: @unchecked Sendable {
    struct Snapshot: Sendable {
        let count: Int
        let requestID: String
        let actionIdentifier: String
        let isMainThread: Bool
    }

    private let lock = NSLock()
    private var count = 0
    private var requestID = "none"
    private var actionIdentifier = "none"
    private var isMainThread = false

    func record(
        requestID: String,
        actionIdentifier: String,
        isMainThread: Bool
    ) -> Snapshot {
        lock.withLock {
            count += 1
            self.requestID = requestID
            self.actionIdentifier = actionIdentifier
            self.isMainThread = isMainThread
            return Snapshot(
                count: count,
                requestID: self.requestID,
                actionIdentifier: self.actionIdentifier,
                isMainThread: self.isMainThread
            )
        }
    }

    func snapshot() -> Snapshot {
        lock.withLock {
            Snapshot(
                count: count,
                requestID: requestID,
                actionIdentifier: actionIdentifier,
                isMainThread: isMainThread
            )
        }
    }
}
