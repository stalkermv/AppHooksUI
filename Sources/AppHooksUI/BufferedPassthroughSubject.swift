//
//  BufferedPassthroughSubject.swift
//  AppHooksUI
//
//  Created by Valeriy Malishevskyi on 18.09.2025.
//

import Combine
import Foundation

/// A "deliver-later once" subject.
///
/// Behaviour:
/// - While there are NO subscribers, the latest value sent is buffered (only one kept).
/// - When the FIRST subscriber (after a period of zero subscribers) attaches, the buffered
///   value (if any) is delivered exactly once to THAT subscriber only, then the buffer is cleared.
/// - Additional subscribers attaching at the same moment or afterwards DO NOT receive that past value.
/// - After the buffer is cleared, the subject acts exactly like a `PassthroughSubject` for all active subscribers.
/// - Upon completion, the buffer is cleared and further sends are ignored.
public final class BufferedPassthroughSubject<Output, Failure: Error>: Subject {
    
    // MARK: - Internal State
    private var buffered: Output?
    private var subscribers: [UUID: AnySubscriber<Output, Failure>] = [:]
    private var isFinished = false
    private var completion: Subscribers.Completion<Failure>? = nil
    private var hasDeliveredBufferedForCurrentCycle = false
    
    public init() {}
    
    // MARK: - Sending
    public func send(_ value: Output) {
        guard !isFinished else { return }
        
        if subscribers.isEmpty {
            buffered = value
        } else {
            for sub in subscribers.values { _ = sub.receive(value) }
        }
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        guard !isFinished else { return }
        
        isFinished = true
        buffered = nil
        self.completion = completion
        
        for sub in subscribers.values {
            sub.receive(completion: completion)
        }
        subscribers.removeAll()
    }
    
    public func send(subscription: any Subscription) {
        // No upstream; ignore or immediately request unlimited.
        subscription.request(.unlimited)
    }
    
    // MARK: - Subscription
    private final class Token: Subscription {
        private let cancelHandler: () -> Void
        
        private var isCancelled = false
        
        init(_ cancel: @escaping () -> Void) {
            self.cancelHandler = cancel
        }
        
        func request(_ demand: Subscribers.Demand) {
            /* we push, ignore demand */
        }
        
        func cancel() {
            guard !isCancelled else { return }
            
            isCancelled = true
            cancelHandler()
        }
    }
    
    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let id = UUID()
        
        // If already finished, immediately send completion and return.
        if let completion {
            subscriber.receive(subscription: Token { /* nothing */ })
            subscriber.receive(completion: completion)
            return
        }
        
        let any = AnySubscriber(subscriber)
        subscribers[id] = any
        
        subscriber.receive(subscription: Token { [weak self] in
            guard let self else { return }
            self.subscribers.removeValue(forKey: id)
            if self.subscribers.isEmpty { self.hasDeliveredBufferedForCurrentCycle = false }
        })
        
        // First subscriber after idle period? Deliver buffered once.
        if !hasDeliveredBufferedForCurrentCycle, subscribers.count == 1, let v = buffered {
            buffered = nil
            hasDeliveredBufferedForCurrentCycle = true
            _ = any.receive(v)
        }
    }
}
