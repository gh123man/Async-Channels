import Foundation

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
    private var mutex = FastLock()
    private let capacity: Int
    private var closed = false
    private var buffer: LinkedList<T>
    private var sendQueue = LinkedList<(T, UnsafeContinuation<Void, Never>)>()
    private var recvQueue = LinkedList<UnsafeContinuation<T?, Never>>()

    public init(capacity: Int = 0) {
        self.capacity = capacity
        self.buffer = LinkedList<T>()
    }

    var count: Int {
        mutex.lock()
        defer { mutex.unlock() }
        return buffer.count
    }
    
    var selectWaiter: SelectSignal?
    
    @usableFromInline
    var isClosed: Bool {
        mutex.lock()
        defer { mutex.unlock() }
        return closed
    }
    
    func receiveOrListen(_ sema: SelectSignal) -> T? {
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
    
    func sendOrListen(_ sema: SelectSignal, value: T) -> Bool {
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
        
        if !recvQueue.isEmpty {
            let r = recvQueue.pop()!
            mutex.unlock()
            r.resume(returning: value)
            return true
        }

        if buffer.count < capacity {
            buffer.push(value)
            mutex.unlock()
            return true
        }
        
        return false
    }
    
    @inline(__always)
    public func send(_ value: T) async {
        mutex.lock()
        
        if nonBlockingSend(value) {
            return
        }
        
        await withUnsafeContinuation { continuation in
            sendQueue.push((value, continuation))
            let waiter = selectWaiter
            mutex.unlock()
            waiter?.signal()
        }
    }
    
    @inline(__always)
    private func nonBlockingReceive() -> T? {
        if buffer.isEmpty {
            if !sendQueue.isEmpty {
                let (value, continuation) = sendQueue.pop()!
                mutex.unlock()
                continuation.resume()
                return value
            } else {
                return nil
            }
        }
        
        let val = buffer.pop()
        
        if !sendQueue.isEmpty {
            let (value, continuation) = sendQueue.pop()!
            buffer.push(value)
            mutex.unlock()
            continuation.resume()
        } else {
            mutex.unlock()
        }
        return val
    }

    @inline(__always)
    public func receive() async -> T? {
        mutex.lock()

        if let val = nonBlockingReceive() {
            return val
        }
        
        if closed {
            mutex.unlock()
            return nil
        }
        
        return await withUnsafeContinuation { continuation in
            recvQueue.push(continuation)
            let waiter = selectWaiter
            mutex.unlock()
            waiter?.signal()
        }
    }
    
    public func close() {
        mutex.lock()
        defer { mutex.unlock() }
        closed = true
        selectWaiter?.signal()
        
        
        while let recvW = recvQueue.pop() {
            recvW.resume(returning: nil)
        }
    }
}
