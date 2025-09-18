//
//  BufferedPassthroughSubjectTests.swift
//  AppHooksUI
//
//  Created by Valeriy Malishevskyi on 18.09.2025.
//


import Combine
import Testing
@testable import AppHooksUI

@Suite(.serialized)
class BufferedPassthroughSubjectTests {
    
    // Keep subscriptions alive
    private var cancellables = Set<AnyCancellable>()
    
    @Test
    func passThroughWithActiveSubscriber() {
        let subject = BufferedPassthroughSubject<String, Never>()
        var received: [String] = []
        
        subject.sink { received.append($0) }.store(in: &cancellables)
        
        subject.send("A")
        subject.send("B")
        
        #expect(received == ["A", "B"])
    }
    
    @Test
    func buffersLatestWhenNoSubscribers_thenDeliversOnceOnSubscribe() {
        let subject = BufferedPassthroughSubject<Int, Never>()
        
        // No subscribers yet — these should buffer (only the latest kept)
        subject.send(1)
        subject.send(2)
        
        var received: [Int] = []
        subject.sink { received.append($0) }.store(in: &cancellables)
        
        // On first subscribe, the buffered "2" should be emitted once
        #expect(received == [2])
        
        // Now behaves like passthrough
        subject.send(3)
        #expect(received == [2, 3])
        
        // Unsubscribe (drop all)
        cancellables.removeAll()
        
        // Re-subscribing without sending should NOT replay anything (buffer was cleared)
        var received2: [Int] = []
        subject.sink { received2.append($0) }.store(in: &cancellables)
        
        #expect(received2.isEmpty)
    }
    
    @Test
    @MainActor
    func onlyLatestIsBufferedAcrossMultipleSendsWithoutSubscribers() {
        let subject = BufferedPassthroughSubject<String, Never>()
        
        subject.send("first")
        subject.send("second")
        subject.send("third") // only "third" should be kept
        
        var received: [String] = []
        subject.sink { received.append($0) }.store(in: &cancellables)
        
        #expect(received == ["third"])
    }
    
    @Test
    func completionPreventsFurtherDelivery_andClearsBuffer() {
        // Case A: complete *before* any subscriber
        do {
            let subject = BufferedPassthroughSubject<Int, Never>()
            subject.send(42)                 // buffered
            subject.send(completion: .finished)
            
            var received: [Int] = []
            subject.sink { received.append($0) }.store(in: &cancellables)
            
            // Buffer should have been cleared by completion; nothing delivered
            #expect(received.isEmpty)
            
            // Further sends are ignored
            subject.send(100)
            #expect(received.isEmpty)
        }
        
        // Case B: complete *with* subscribers
        do {
            let subject = BufferedPassthroughSubject<Int, Never>()
            var received: [Int] = []
            
            subject.sink { received.append($0) }.store(in: &cancellables)
            
            subject.send(1)
            subject.send(completion: .finished)
            subject.send(2) // ignored
            #expect(received == [1])
        }
    }
    
    @Test
    func onlyFirstSubscriberReceivesBuffered_thenPassthroughToAll() {
        let subject = BufferedPassthroughSubject<String, Never>()
        
        // No subscribers; buffer "hello" (latest only)
        subject.send("hello")
        
        var first: [String] = []
        var second: [String] = []
        
        // First subscriber attaches -> should receive buffered value exactly once
        subject.sink { first.append($0) }.store(in: &cancellables)
        #expect(first == ["hello"])
        #expect(second.isEmpty)
        
        // Second subscriber attaches AFTER buffer is cleared -> receives nothing immediately
        subject.sink { second.append($0) }.store(in: &cancellables)
        #expect(first == ["hello"]) // unchanged
        #expect(second.isEmpty)
        
        // Now behaves like passthrough for all active subscribers
        subject.send("world")
        #expect(first == ["hello", "world"])
        #expect(second == ["world"])
    }
    
    @Test
    func reSubscribeAfterReceivingBufferedDoesNotReplay() {
        let subject = BufferedPassthroughSubject<String, Never>()
        
        subject.send("missed") // buffer
        
        var first: [String] = []
        var second: [String] = []
        
        // First subscriber gets the buffered value once
        var c1: AnyCancellable?
        c1 = subject.sink { first.append($0) }
        if let c1 { c1.store(in: &cancellables) }
        
        #expect(first == ["missed"])
        
        // Cancel first subscriber
        cancellables.removeAll()
        
        // Re-subscribe: buffer was cleared, so nothing should arrive immediately
        subject.sink { second.append($0) }.store(in: &cancellables)
        #expect(second.isEmpty)
        
        // Sending now should pass through
        subject.send("now")
        #expect(second == ["now"])
    }
}
