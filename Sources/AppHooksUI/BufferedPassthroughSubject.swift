import Combine
import Foundation

/// Internal one-slot publisher for notification callbacks received before a
/// view subscribes. It is not a public lifecycle/event abstraction.
///
/// State and event queues use one lock. Each subscriber has one drain owner;
/// callbacks run outside the lock and reentrant sends enqueue behind the active
/// callback. Completion waits for the subscription handshake to return.
final class BufferedPassthroughSubject<Output, Failure: Error>: Subject, @unchecked Sendable {
    private enum Event {
        case value(Output)
        case completion(Subscribers.Completion<Failure>)
    }

    private final class SubscriberState {
        let id = UUID()
        let subscriber: AnySubscriber<Output, Failure>
        var demand: Subscribers.Demand = .none
        var isReady = false
        var isDraining = false
        var isCancelled = false
        var pending: [Event] = []
        var nextEvent = 0

        init(_ subscriber: AnySubscriber<Output, Failure>) {
            self.subscriber = subscriber
        }
    }

    private final class Token: Subscription, @unchecked Sendable {
        private let lock = NSLock()
        private weak var subject: BufferedPassthroughSubject?
        private let id: UUID

        init(subject: BufferedPassthroughSubject, id: UUID) {
            self.subject = subject
            self.id = id
        }

        func request(_ demand: Subscribers.Demand) {
            guard demand > .none else { return }
            let owner = lock.withLock { subject }
            owner?.request(demand, for: id)
        }

        func cancel() {
            let owner = lock.withLock {
                let owner = subject
                subject = nil
                return owner
            }
            owner?.cancel(id: id)
        }
    }

    private let lock = NSLock()
    private var buffered: Output?
    private var bufferedRecipientID: UUID?
    private var subscribers: [SubscriberState] = []
    private var completion: Subscribers.Completion<Failure>?

    func send(_ value: Output) {
        let recipients = lock.withLock {
            guard completion == nil else { return [SubscriberState]() }
            if subscribers.isEmpty {
                buffered = value
                bufferedRecipientID = nil
            }
            let recipients = subscribers.filter { !$0.isCancelled && $0.demand > .none }
            for state in recipients {
                state.demand -= .max(1)
                state.pending.append(.value(value))
            }
            return recipients
        }
        recipients.forEach(drain)
    }

    func send(completion: Subscribers.Completion<Failure>) {
        let recipients = lock.withLock {
            guard self.completion == nil else { return [SubscriberState]() }
            self.completion = completion
            buffered = nil
            bufferedRecipientID = nil
            for state in subscribers {
                state.pending.append(.completion(completion))
            }
            return subscribers
        }
        recipients.forEach(drain)
    }

    func send(subscription: any Subscription) {
        subscription.request(.unlimited)
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let state = SubscriberState(AnySubscriber(subscriber))
        let token = Token(subject: self, id: state.id)
        lock.withLock {
            if let completion {
                state.pending.append(.completion(completion))
            } else if subscribers.isEmpty, buffered != nil {
                bufferedRecipientID = state.id
            }
            subscribers.append(state)
        }

        subscriber.receive(subscription: token)

        lock.withLock {
            guard !state.isCancelled else { return }
            state.isReady = true
            takeBuffered(for: state)
        }
        drain(state)
    }

    private func request(_ demand: Subscribers.Demand, for id: UUID) {
        let state = lock.withLock {
            guard completion == nil, let state = subscribers.first(where: { $0.id == id }) else {
                return Optional<SubscriberState>.none
            }
            state.demand += demand
            takeBuffered(for: state)
            return state
        }
        if let state { drain(state) }
    }

    private func cancel(id: UUID) {
        let successor = lock.withLock {
            guard let index = subscribers.firstIndex(where: { $0.id == id }) else {
                return Optional<SubscriberState>.none
            }
            let removed = subscribers.remove(at: index)
            removed.isCancelled = true
            removed.pending.removeAll()
            if bufferedRecipientID == id {
                bufferedRecipientID = subscribers.first?.id
                if let next = subscribers.first {
                    takeBuffered(for: next)
                    return next
                }
            }
            return nil
        }
        if let successor { drain(successor) }
    }

    /// Requires the subject lock.
    private func takeBuffered(for state: SubscriberState) {
        guard completion == nil, !state.isCancelled, state.demand > .none,
              bufferedRecipientID == state.id, let buffered else { return }
        self.buffered = nil
        bufferedRecipientID = nil
        state.demand -= .max(1)
        state.pending.append(.value(buffered))
    }

    private func drain(_ state: SubscriberState) {
        let ownsDrain = lock.withLock {
            guard state.isReady, !state.isCancelled, !state.isDraining else { return false }
            state.isDraining = true
            return true
        }
        guard ownsDrain else { return }

        while let event = lock.withLock({ () -> Event? in
            guard !state.isCancelled, state.nextEvent < state.pending.count else {
                state.pending.removeAll(keepingCapacity: true)
                state.nextEvent = 0
                state.isDraining = false
                return nil
            }
            let event = state.pending[state.nextEvent]
            state.nextEvent += 1
            if case .completion = event {
                subscribers.removeAll { $0 === state }
                state.isCancelled = true
            }
            return event
        }) {
            switch event {
            case let .value(value):
                let additionalDemand = state.subscriber.receive(value)
                lock.withLock {
                    if !state.isCancelled, completion == nil {
                        state.demand += additionalDemand
                    }
                }
            case let .completion(completion):
                state.subscriber.receive(completion: completion)
            }
        }
    }
}
