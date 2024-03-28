import Foundation
import Collections

infix operator <- :AssignmentPrecedence

@inline(__always)
@inlinable
public func <- <T>(c: Channel<T>, value: T) async {
    await c.send(value)
}

@inline(__always)
@inlinable
public func <- <T>(value: inout T?, chan: Channel<T>) async {
    await value = chan.receive()
}

prefix operator <-

@inline(__always)
@inlinable
@discardableResult public prefix func <- <T>(chan: Channel<T>) async -> T? {
    return await chan.receive()
}

public final class Channel<T: Sendable>: @unchecked Sendable {
    class Sender<U> {
        private var value: U
        private var sema = AsyncSemaphore(value: 0)
        
        init(value: U) {
            self.value = value
        }
        
        func get() -> U {
            sema.signal()
            return value
        }
        
        func wait() async {
            await sema.wait()
        }
    }
    
    class Receiver<U> {
        private var value: U?
        private var sema = AsyncSemaphore(value: 0)
        
        func set(_ val: U?) {
            value = val
            sema.signal()
        }
        
        func get() async -> U? {
            await sema.wait()
            return value
        }
    }
    
    private var mutex = FastLock()
    private let capacity: Int
    private var closed = false
    private var buffer: Deque<T>
    private var sendQueue = Deque<(T, UnsafeContinuation<Void, Never>)>()
    private var recvQueue = Deque<UnsafeContinuation<T?, Never>>()

    public init(capacity: Int = 0) {
        self.capacity = capacity
        self.buffer = Deque<T>(minimumCapacity: capacity)
    }

    var count: Int {
        mutex.lock()
        defer { mutex.unlock() }
        return buffer.count
    }
    
    var selectWaiter: AsyncSemaphore?
    
    @usableFromInline
    var isClosed: Bool {
        mutex.lock()
        defer { mutex.unlock() }
        return closed
    }
    
    @usableFromInline
    func receiveOrListen(_ sema: AsyncSemaphore) async -> T? {
        mutex.lock()
        
        if let val = nonBlockingReceive() {
            return val
        }
        
        if closed {
            mutex.unlock()
            return nil
        }
        
        selectWaiter = sema
        mutex.unlock()
        return nil
    }
    
    func sendOrListen(_ sema: AsyncSemaphore, value: T) async -> Bool {
        mutex.lock()
        
        if nonBlockingSend(value) {
            return true
        }
        
        selectWaiter = sema
        mutex.unlock()
        return false
    }
    
    @inline(__always)
    private func nonBlockingSend(_ value: T) -> Bool {
        if closed {
            fatalError("Cannot send on a closed channel")
        }
        
        if let recvW = recvQueue.popFirst() {
            mutex.unlock()
            recvW.resume(returning: value)
            return true
        }

        if buffer.count < capacity {
            buffer.append(value)
            mutex.unlock()
            return true
        }
        
        return false
    }
    
    @usableFromInline
    func send(_ value: T) async {
        mutex.lock()
        
        if nonBlockingSend(value) {
            return
        }
        
        await withUnsafeContinuation { continuation in
            sendQueue.append((value, continuation))
            let waiter = selectWaiter
            mutex.unlock()
            waiter?.signal()
        }
    }
    
    @inline(__always)
    private func nonBlockingReceive() -> T? {
        if buffer.isEmpty {
            if let (value, continuation) = sendQueue.popFirst() {
                mutex.unlock()
                continuation.resume()
                return value
            } else {
                return nil
            }
        }
        
        let val = buffer.popFirst()
        
        if let (value, continuation) = sendQueue.popFirst() {
            buffer.append(value)
            mutex.unlock()
            continuation.resume()
        } else {
            mutex.unlock()
        }
        return val
    }

    @usableFromInline
    func receive() async -> T? {
        mutex.lock()

        if let val = nonBlockingReceive() {
            return val
        }
        
        if closed {
            mutex.unlock()
            return nil
        }
        
        return await withUnsafeContinuation { continuation in
            recvQueue.append(continuation)
            let waiter = selectWaiter
            mutex.unlock()
            waiter?.signal()
        }
    }
    
    func close() async {
        mutex.lock()
        defer { mutex.unlock() }
        closed = true
        
        while let recvW = recvQueue.popFirst() {
            recvW.resume(returning: nil)
        }
    }
}



