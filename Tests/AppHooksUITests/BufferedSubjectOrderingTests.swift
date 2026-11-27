@preconcurrency import Dispatch
import Combine
import Foundation
import Testing
@testable import AppHooksUI

struct BufferedSubjectOrderingTests {
    @Test
    func completionWaitsForSubscriptionHandshake() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let subscriber = HandshakeSubscriber()
        defer { subscriber.release.signal() }
        let finished = DispatchGroup()
        finished.enter()
        Thread.detachNewThread {
            subject.receive(subscriber: subscriber)
            finished.leave()
        }
        try #require(subscriber.started.wait(timeout: .now() + 5) == .success)
        subject.send(completion: .finished)
        #expect(subscriber.events == [.subscriptionBegan])
        subscriber.release.signal()
        #expect(finished.wait(timeout: .now() + 5) == .success)
        #expect(subscriber.releaseWaitResult == .success)
        #expect(subscriber.events == [.subscriptionBegan, .subscriptionEnded, .completion])
    }

    @Test
    func cancellingBufferedRecipientHandsOffToNextSubscriber() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        subject.send(42)
        let first = ControlledSubscriber<Int>(initialDemand: .none)
        let next = ControlledSubscriber<Int>(initialDemand: .unlimited)
        subject.receive(subscriber: first)
        subject.receive(subscriber: next)
        #expect(next.values.isEmpty)
        let firstSubscription = try #require(first.subscription)
        firstSubscription.cancel()
        #expect(next.values == [42])
        let nextSubscription = try #require(next.subscription)
        nextSubscription.cancel()
    }

    @Test
    func zeroDemandDropsLiveValues() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let subscriber = ControlledSubscriber<Int>(initialDemand: .max(1))
        subject.receive(subscriber: subscriber)
        subject.send(1)
        subject.send(2)
        let subscription = try #require(subscriber.subscription)
        subscription.request(.max(1))
        subject.send(3)
        #expect(subscriber.values == [1, 3])
    }

    @Test
    func reentrantValuesFollowCurrentCallbackAndCancellationDropsQueuedWork() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        var token: (any Subscription)?
        var events: [ReentrantEvent] = []
        let subscriber = AnySubscriber<Int, Never>(
            receiveSubscription: { token = $0; $0.request(.unlimited) },
            receiveValue: { value in
                events.append(.begin(value))
                if value == 1 { subject.send(2) }
                if value == 2 {
                    subject.send(3)
                    guard let token else { return .none }
                    token.cancel()
                }
                events.append(.end(value))
                return .none
            },
            receiveCompletion: { _ in events.append(.completion) }
        )
        subject.receive(subscriber: subscriber)
        subject.send(1)
        #expect(events == [.begin(1), .end(1), .begin(2), .end(2)])
    }

    @Test
    func reentrantCompletionFollowsValueCallback() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        var events: [ReentrantEvent] = []
        let subscriber = AnySubscriber<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in
                events.append(.valueBegin)
                subject.send(completion: .finished)
                events.append(.valueEnd)
                return .unlimited
            },
            receiveCompletion: { _ in events.append(.completion) }
        )
        subject.receive(subscriber: subscriber)
        subject.send(1)
        subject.send(2)
        #expect(events == [.valueBegin, .valueEnd, .completion])
    }

    @Test
    func liveValueRequestedDuringHandshakeIsDeliveredAfterTheHandshake() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let subscriber = HandshakeSubscriber(initialDemand: .max(1))
        defer { subscriber.release.signal() }
        let finished = DispatchSemaphore(value: 0)

        Thread.detachNewThread {
            subject.receive(subscriber: subscriber)
            finished.signal()
        }

        try #require(subscriber.started.wait(timeout: .now() + 5) == .success)
        subject.send(7)
        #expect(subscriber.values.isEmpty)
        subscriber.release.signal()
        try #require(finished.wait(timeout: .now() + 5) == .success)
        try #require(subscriber.releaseWaitResult == .success)

        #expect(subscriber.values == [7])
    }

    @Test
    func retainedValueHasPriorityAndConsumesOneDemandDuringHandshake() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        subject.send(1)
        let subscriber = HandshakeSubscriber(initialDemand: .max(1))
        defer { subscriber.release.signal() }
        let finished = DispatchSemaphore(value: 0)

        Thread.detachNewThread {
            subject.receive(subscriber: subscriber)
            finished.signal()
        }

        try #require(subscriber.started.wait(timeout: .now() + 5) == .success)
        subject.send(2)
        subscriber.release.signal()
        try #require(finished.wait(timeout: .now() + 5) == .success)
        try #require(subscriber.releaseWaitResult == .success)

        #expect(subscriber.values == [1])
    }

    @Test
    func retainedValueAndLiveValueKeepOrderWithTwoDemand() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        subject.send(1)
        let subscriber = HandshakeSubscriber(initialDemand: .max(2))
        defer { subscriber.release.signal() }
        let finished = DispatchSemaphore(value: 0)

        Thread.detachNewThread {
            subject.receive(subscriber: subscriber)
            finished.signal()
        }

        try #require(subscriber.started.wait(timeout: .now() + 5) == .success)
        subject.send(2)
        subscriber.release.signal()
        try #require(finished.wait(timeout: .now() + 5) == .success)
        try #require(subscriber.releaseWaitResult == .success)

        #expect(subscriber.values == [1, 2])
    }

    @Test
    func sendAndCompletionQueuedDuringHandshakeKeepOrder() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let subscriber = HandshakeSubscriber(initialDemand: .unlimited)
        defer { subscriber.release.signal() }
        let operationsFinished = DispatchSemaphore(value: 0)
        let receiveFinished = DispatchSemaphore(value: 0)

        Thread.detachNewThread {
            subject.receive(subscriber: subscriber)
            receiveFinished.signal()
        }
        try #require(subscriber.started.wait(timeout: .now() + 5) == .success)

        Thread.detachNewThread {
            subject.send(3)
            subject.send(completion: .finished)
            operationsFinished.signal()
        }
        try #require(operationsFinished.wait(timeout: .now() + 5) == .success)
        subscriber.release.signal()
        try #require(receiveFinished.wait(timeout: .now() + 5) == .success)
        try #require(subscriber.releaseWaitResult == .success)

        #expect(subscriber.values == [3])
        #expect(subscriber.events == [.subscriptionBegan, .subscriptionEnded, .completion])
    }
}
