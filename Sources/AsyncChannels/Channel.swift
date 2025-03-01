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
    
    @inline(__always)
    public var isClosed: Bool {
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
    
    /// Sends data on the channel. This function will suspend until a reciever is ready or buffer space is avalible.
    /// - Parameter value: The data to send.
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
    
    /// Sends data synchonosly. Returns true if the data was sent.
    /// A fatal error will be triggered if you attpend to send on a closed channel.
    /// - Parameter value: The input data.
    @inline(__always)
    public func syncSend(_ value: T) -> Bool {
        mutex.lock()
        if nonBlockingSend(value) {
            return true
        }
        mutex.unlock()
        return false
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
    
    /// Receive data from the channel. This function will suspend until a sender is ready or there is data in the buffer.
    /// This functionw will return `nil` when the channel is closed after all buffered data is read.
    /// - Returns: data or nil.
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
    
    
    /// Receive data synchronosly. Returns nil if there is no data or the channel is closed.
    /// This function will never block or suspend.
    /// - Returns: The data or nil
    @inline(__always)
    public func syncReceive() -> T? {
        mutex.lock()
        if let val = nonBlockingReceive() {
            return val
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
        
        while let recvW = recvQueue.pop() {
            recvW.resume(returning: nil)
        }
    }
}
