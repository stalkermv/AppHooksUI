import Combine
import Foundation
@testable import AppHooksUI

enum HandshakeEvent: Equatable {
    case subscriptionBegan
    case subscriptionEnded
    case completion
}

enum ReentrantEvent: Equatable {
    case begin(Int)
    case end(Int)
    case valueBegin
    case valueEnd
    case completion
}

final class ControlledSubscriber<Input>: Subscriber {
    typealias Failure = Never

    var subscription: (any Subscription)?
    var values: [Input] = []
    let initialDemand: Subscribers.Demand
    let returnedDemand: Subscribers.Demand

    init(
        initialDemand: Subscribers.Demand,
        returnedDemand: Subscribers.Demand = .none
    ) {
        self.initialDemand = initialDemand
        self.returnedDemand = returnedDemand
    }

    func receive(subscription: any Subscription) {
        self.subscription = subscription
        subscription.request(initialDemand)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        values.append(input)
        return returnedDemand
    }

    func receive(completion: Subscribers.Completion<Never>) {}
}

final class ReentrantSubscriber: Subscriber {
    typealias Input = Int
    typealias Failure = Never

    private let subject: BufferedPassthroughSubject<Int, Never>
    private var subscription: (any Subscription)?
    var values: [Int] = []
    var reentrantValues: [Int] = []

    init(subject: BufferedPassthroughSubject<Int, Never>) {
        self.subject = subject
    }

    func receive(subscription: any Subscription) {
        self.subscription = subscription
        subscription.request(.unlimited)
    }

    func receive(_ input: Int) -> Subscribers.Demand {
        values.append(input)
        if input == 1 {
            subject.send(2)
        } else {
            reentrantValues.append(input)
        }
        return .none
    }

    func receive(completion: Subscribers.Completion<Never>) {}
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.withLock { storage }
    }

    func increment() {
        lock.withLock { storage += 1 }
    }
}

final class SerializationProbe: Subscriber, @unchecked Sendable {
    typealias Input = Int
    typealias Failure = Never

    private let subject: BufferedPassthroughSubject<Int, Never>
    private let lock = NSLock()
    private var activeCallbacks = 0
    private var overlapDetectedStorage = false
    private var firstCallbackObserved = false
    private var releaseWaitResultStorage: DispatchTimeoutResult?
    private var countStorage = 0

    let firstCallbackStarted = DispatchSemaphore(value: 0)
    let concurrentSendStarted = DispatchSemaphore(value: 0)
    let releaseFirstCallback = DispatchSemaphore(value: 0)
    let concurrentSendFinished = DispatchSemaphore(value: 0)

    init(subject: BufferedPassthroughSubject<Int, Never>) {
        self.subject = subject
    }

    var overlapDetected: Bool {
        lock.withLock { overlapDetectedStorage }
    }

    var count: Int {
        lock.withLock { countStorage }
    }

    var releaseWaitResult: DispatchTimeoutResult? {
        lock.withLock { releaseWaitResultStorage }
    }

    func receive(subscription: any Subscription) {
        subscription.request(.unlimited)
    }

    func receive(_ input: Int) -> Subscribers.Demand {
        let isFirstCallback = lock.withLock {
            let isFirstCallback = !firstCallbackObserved
            firstCallbackObserved = true
            activeCallbacks += 1
            if activeCallbacks > 1 {
                overlapDetectedStorage = true
            }
            return isFirstCallback
        }

        if isFirstCallback {
            firstCallbackStarted.signal()
            Thread.detachNewThread {
                self.concurrentSendStarted.signal()
                self.subject.send(input + 1)
                self.concurrentSendFinished.signal()
            }
            let waitResult = releaseFirstCallback.wait(timeout: .now() + 5)
            lock.withLock { releaseWaitResultStorage = waitResult }
        }

        lock.withLock {
            countStorage += 1
            activeCallbacks -= 1
        }
        return .none
    }

    func receive(completion: Subscribers.Completion<Never>) {}
}

final class HandshakeSubscriber: Subscriber, @unchecked Sendable {
    typealias Input = Int
    typealias Failure = Never

    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let initialDemand: Subscribers.Demand
    private let lock = NSLock()
    private var recorded: [HandshakeEvent] = []
    private var recordedValues: [Int] = []
    private var releaseWaitResultStorage: DispatchTimeoutResult?

    init(initialDemand: Subscribers.Demand = .unlimited) {
        self.initialDemand = initialDemand
    }

    var events: [HandshakeEvent] { lock.withLock { recorded } }
    var values: [Int] { lock.withLock { recordedValues } }
    var releaseWaitResult: DispatchTimeoutResult? {
        lock.withLock { releaseWaitResultStorage }
    }

    func receive(subscription: any Subscription) {
        lock.withLock { recorded.append(.subscriptionBegan) }
        subscription.request(initialDemand)
        started.signal()
        let waitResult = release.wait(timeout: .now() + 5)
        lock.withLock {
            releaseWaitResultStorage = waitResult
            recorded.append(.subscriptionEnded)
        }
    }

    func receive(_ input: Int) -> Subscribers.Demand {
        lock.withLock { recordedValues.append(input) }
        return .none
    }

    func receive(completion: Subscribers.Completion<Never>) {
        lock.withLock { recorded.append(.completion) }
    }
}
