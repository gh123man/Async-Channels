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

extension UnsafeRawPointer: @unchecked Sendable {}

public final class Channel<T: Sendable>: @unchecked Sendable {
    private var mutex = FastLock()
    private let capacity: Int
    private var closed = false
    private var buffer: Deque<UnsafeRawPointer>
    private var sendQueue = Deque<(UnsafeRawPointer, UnsafeContinuation<Void, Never>)>()
    private var recvQueue = Deque<UnsafeContinuation<UnsafeRawPointer?, Never>>()

    public init(capacity: Int = 0) {
        self.capacity = capacity
        self.buffer = Deque(minimumCapacity: capacity)
    }

    var selectWaiter: SelectSignal?
    
    @inline(__always)
    public var isClosed: Bool {
        mutex.lock()
        defer { mutex.unlock() }
        return closed
    }
    
    @inlinable
    @inline(__always)
    func ptr(_ value: T) -> UnsafeRawPointer {
        if T.self is AnyObject.Type {
            if let value = value as? AnyObject {
                return UnsafeRawPointer(Unmanaged.passRetained(value).toOpaque())
            }
        }
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        ptr.initialize(to: value)
        return UnsafeRawPointer(ptr)
    }
    
    @inlinable
    @inline(__always)
    func value(_ p: UnsafeRawPointer?) -> T? {
        if T.self is AnyObject.Type {
            guard let p = p else {
                return nil
            }
            return Unmanaged<AnyObject>.fromOpaque(p).takeRetainedValue() as? T
        }
        defer { p?.deallocate() }
        return p?.assumingMemoryBound(to: T.self).pointee
    }
    
    func receiveOrListen(_ sema: SelectSignal) -> T? {
        mutex.lock()
        
        if let val = nonBlockingReceive() {
            return value(val)
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
        let p = ptr(value)
        mutex.lock()
        
        if nonBlockingSend(p) {
            return true
        }
        
        selectWaiter = sema
        mutex.unlock()
        return false
    }
    
    @inline(__always)
    private func nonBlockingSend(_ p: UnsafeRawPointer) -> Bool {
        if closed {
            fatalError("Cannot send on a closed channel")
        }
        
        if !recvQueue.isEmpty {
            let r = recvQueue.popFirst()!
            mutex.unlock()
            r.resume(returning: p)
            return true
        }

        if buffer.count < capacity {
            buffer.append(p)
            mutex.unlock()
            return true
        }
        
        return false
    }
    
    /// Sends data on the channel. This function will suspend until a receiver is ready or buffer space is avalible.
    /// - Parameter value: The data to send.
    @inline(__always)
    public func send(_ value: T) async {
        mutex.lock()
        let p = ptr(value)
        
        if nonBlockingSend(p) {
            return
        }
        
        await withUnsafeContinuation { continuation in
            sendQueue.append((p, continuation))
            let waiter = selectWaiter
            mutex.unlock()
            waiter?.signal()
        }
    }
    
    /// Sends data synchonosly. Returns true if the data was sent.
    /// A fatal error will be triggered if you attpend to send on a closed channel.
    /// - Parameter value: The input data.
    @inline(__always)
    public func syncSend(_ value: T) -> Bool {
        let p = ptr(value)
        mutex.lock()
        if nonBlockingSend(p) {
            return true
        }
        mutex.unlock()
        return false
    }
    
    @inline(__always)
    private func nonBlockingReceive() -> UnsafeRawPointer? {
        if buffer.isEmpty {
            if !sendQueue.isEmpty {
                let (p, continuation) = sendQueue.popFirst()!
                mutex.unlock()
                continuation.resume()
                return p
            } else {
                return nil
            }
        }
        
        let p = buffer.popFirst()
        
        if !sendQueue.isEmpty {
            let (value, continuation) = sendQueue.popFirst()!
            buffer.append(value)
            mutex.unlock()
            continuation.resume()
        } else {
            mutex.unlock()
        }
        return p
    }
    
    /// Receive data from the channel. This function will suspend until a sender is ready or there is data in the buffer.
    /// This functionw will return `nil` when the channel is closed after all buffered data is read.
    /// - Returns: data or nil.
    @inline(__always)
    public func receive() async -> T? {
        mutex.lock()

        if let p = nonBlockingReceive() {
            return value(p)
        }
        
        if closed {
            mutex.unlock()
            return nil
        }
        
        let p = await withUnsafeContinuation { continuation in
            recvQueue.append(continuation)
            let waiter = selectWaiter
            mutex.unlock()
            waiter?.signal()
        }
        return value(p)
    }
    
    
    /// Receive data synchronosly. Returns nil if there is no data or the channel is closed.
    /// This function will never block or suspend.
    /// - Returns: The data or nil
    @inline(__always)
    public func syncReceive() -> T? {
        mutex.lock()
        if let val = nonBlockingReceive() {
            return value(val)
        }
        mutex.unlock()
        return nil
    }
    
    
    /// Closes the channel. A channel cannot be reopened.
    /// Once a channel is closed, no more data can be writeen. The remaining data can be read until the buffer is empty.
    public func close() {
        mutex.lock()
        defer { mutex.unlock() }
        closed = true
        selectWaiter?.signal()
        
        while let recvW = recvQueue.popFirst() {
            recvW.resume(returning: nil)
        }
    }
}

