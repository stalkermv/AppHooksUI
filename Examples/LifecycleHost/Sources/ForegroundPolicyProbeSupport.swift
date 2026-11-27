import Foundation

actor ForegroundPolicyProbeGate {
    private var armed = false
    private var released = false
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func arm() {
        armed = true
        released = false
    }

    func markStarted() -> Bool {
        guard armed else { return false }
        armed = false
        return true
    }

    func waitForRelease() async {
        guard !released else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll(keepingCapacity: true)
        waiters.forEach { $0.resume() }
    }
}
