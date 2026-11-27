@preconcurrency import Dispatch
import Combine
import Foundation
import Testing
@testable import AppHooksUI

#if os(macOS)
import AppKit
#endif

struct BufferedPassthroughSubjectTests {
    @Test
    func passesValuesToActiveSubscribers() {
        let subject = BufferedPassthroughSubject<String, Never>()
        var received: [String] = []
        let cancellable = subject.sink { received.append($0) }
        defer { cancellable.cancel() }

        subject.send("A")
        subject.send("B")

        #expect(received == ["A", "B"])
    }

    @Test
    func buffersLatestValueAndDeliversItOnlyOnce() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        subject.send(1)
        subject.send(2)

        var first: [Int] = []
        let firstCancellable = subject.sink { first.append($0) }
        #expect(first == [2])

        var second: [Int] = []
        let secondCancellable = subject.sink { second.append($0) }
        subject.send(3)

        #expect(first == [2, 3])
        #expect(second == [3])
        firstCancellable.cancel()
        secondCancellable.cancel()
    }

    @Test
    func positiveDemandIsRequiredForBufferedDelivery() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        subject.send(42)

        let subscriber = ControlledSubscriber<Int>(initialDemand: .none)
        subject.receive(subscriber: subscriber)
        #expect(subscriber.values.isEmpty)

        let subscription = try #require(subscriber.subscription)
        subscription.request(.max(1))
        #expect(subscriber.values == [42])
    }

    @Test
    func finiteDemandAndReturnedDemandAreRespected() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let subscriber = ControlledSubscriber<Int>(
            initialDemand: .max(1),
            returnedDemand: .max(1)
        )
        subject.receive(subscriber: subscriber)

        subject.send(1)
        subject.send(2)
        subject.send(3)

        #expect(subscriber.values == [1, 2, 3])
    }

    @Test
    func completionClearsBufferAndPreventsFurtherDelivery() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        subject.send(42)
        subject.send(completion: .finished)

        var received: [Int] = []
        var completed = false
        let cancellable = subject.sink(
            receiveCompletion: { _ in completed = true },
            receiveValue: { received.append($0) }
        )
        defer { cancellable.cancel() }

        subject.send(100)
        #expect(received.isEmpty)
        #expect(completed)
    }

    @Test
    func callbackMaySendReentrantly() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let subscriber = ReentrantSubscriber(subject: subject)
        subject.receive(subscriber: subscriber)

        subject.send(1)

        #expect(subscriber.values == [1, 2])
        #expect(subscriber.reentrantValues == [2])
    }

    @Test
    func concurrentSendAndCompletionAreSafe() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let counter = LockedCounter()
        let cancellable = subject.sink { _ in counter.increment() }

        DispatchQueue.concurrentPerform(iterations: 8) { worker in
            for value in 0..<100 {
                subject.send(worker * 100 + value)
            }
        }
        subject.send(completion: .finished)
        cancellable.cancel()

        #expect(counter.value == 800)
    }

    @Test
    func concurrentSendDoesNotOverlapCallbacks() throws {
        let subject = BufferedPassthroughSubject<Int, Never>()
        let probe = SerializationProbe(subject: subject)
        subject.receive(subscriber: probe)
        defer { probe.releaseFirstCallback.signal() }

        let sendFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            subject.send(1)
            sendFinished.signal()
        }

        try #require(probe.firstCallbackStarted.wait(timeout: .now() + 5) == .success)
        try #require(probe.concurrentSendStarted.wait(timeout: .now() + 5) == .success)
        try #require(probe.concurrentSendFinished.wait(timeout: .now() + 5) == .success)
        probe.releaseFirstCallback.signal()
        try #require(sendFinished.wait(timeout: .now() + 5) == .success)
        try #require(probe.releaseWaitResult == .success)

        #expect(probe.overlapDetected == false)
        #expect(probe.count == 2)
    }

}
