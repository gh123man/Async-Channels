import Foundation
import Collections

extension UnsafeRawPointer: @unchecked @retroactive Sendable {}

public enum ChannelError: Error {
    case closed
}

@inline(__always)
@inlinable
func toPointer<T: Sendable>(_ value: T) -> UnsafeRawPointer {
    // Handle arc managed pointer types
    if T.self is AnyObject.Type {
        return UnsafeRawPointer(Unmanaged.passRetained(value as AnyObject).toOpaque())
    }
    // Handle struct/value types
    let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
    ptr.initialize(to: value)
    return UnsafeRawPointer(ptr)
}

@inline(__always)
@inlinable
func toValue<T: Sendable>(_ ptr: UnsafeRawPointer?) -> T? {
    guard let ptr = ptr else {
        return nil
    }
    
    // Handle arc managed pointer types
    if T.self is AnyObject.Type {
        return Unmanaged<AnyObject>.fromOpaque(ptr).takeRetainedValue() as? T
    }
    
    // Handle struct/value types
    let pt = UnsafeMutablePointer<T>(mutating: ptr.assumingMemoryBound(to: T.self))
    defer {
        pt.deinitialize(count: 1)
        pt.deallocate()
    }
    return pt.pointee
}

@usableFromInline
final class ChannelInternal: @unchecked Sendable {
    private var mutex = FastLock()
    private let capacity: Int
    private var closed = false
    private var buffer: Deque<UnsafeRawPointer>
    private var sendQueue = Deque<(UnsafeRawPointer, UnsafeContinuation<Void, Never>)>()
    private var recvQueue = Deque<UnsafeContinuation<UnsafeRawPointer?, Never>>()

    init(capacity: Int = 0) {
        self.capacity = capacity
        self.buffer = Deque(minimumCapacity: capacity)
    }

    var selectWaiter: SelectSignal?
    
    var isClosed: Bool {
        mutex.lock()
        defer { mutex.unlock() }
        return closed
    }
    
    @inline(__always)
    func receiveOrListen(_ sema: SelectSignal) -> UnsafeRawPointer? {
        mutex.lock()
        
        if let p = nonBlockingReceive() {
            return p
        }
        
        if closed {
            mutex.unlock()
            return nil
        }
        
        selectWaiter = sema
        mutex.unlock()
        return nil
    }
    
    @inline(__always)
    func sendOrListen(_ sema: SelectSignal, p: UnsafeRawPointer) throws -> Bool {
        mutex.lock()
        
        if try nonBlockingSend(p) {
            return true
        }
        
        selectWaiter = sema
        mutex.unlock()
        return false
    }
    
    @inline(__always)
    private func nonBlockingSend(_ p: UnsafeRawPointer) throws -> Bool {
        if closed {
            mutex.unlock()
            throw ChannelError.closed
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
    
    @inline(__always)
    @usableFromInline
    func send(_ p: UnsafeRawPointer) async throws {
        mutex.lock()
        
        if try nonBlockingSend(p) {
            return
        }
        
        await withUnsafeContinuation { continuation in
            sendQueue.append((p, continuation))
            let waiter = selectWaiter
            mutex.unlock()
            waiter?.signal()
        }
    }
    
    @inline(__always)
    @usableFromInline
    func syncSend(_ p: UnsafeRawPointer) throws -> Bool {
        mutex.lock()
        if try nonBlockingSend(p) {
            return true
        }
        mutex.unlock()
        return false
    }
    
    @inline(__always)
    @usableFromInline
    func nonBlockingReceive() -> UnsafeRawPointer? {
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

    @inline(__always)
    @usableFromInline
    func receive() async -> UnsafeRawPointer? {
        mutex.lock()

        if let p = nonBlockingReceive() {
            return p
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
        return p
    }
    
    @inline(__always)
    @usableFromInline
    func syncReceive() -> UnsafeRawPointer? {
        mutex.lock()
        if let p = nonBlockingReceive() {
            return p
        }
        mutex.unlock()
        return nil
    }
    
    @inline(__always)
    func close() {
        mutex.lock()
        defer { mutex.unlock() }
        closed = true
        selectWaiter?.signal()
        
        while let recvW = recvQueue.popFirst() {
            recvW.resume(returning: nil)
        }
    }
}

