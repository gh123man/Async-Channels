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

@inline(__always)
@inlinable
func ptr<T>(_ value: T) -> UnsafeRawPointer {
    if T.self is AnyObject.Type {
        return UnsafeRawPointer(Unmanaged.passRetained(value as AnyObject).toOpaque())
    }
    let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
    ptr.initialize(to: value)
    return UnsafeRawPointer(ptr)
}

@inline(__always)
@inlinable
func value<T>(_ p: UnsafeRawPointer?) -> T? {
    guard let p = p else {
        return nil
    }
    if T.self is AnyObject.Type {
        return Unmanaged<AnyObject>.fromOpaque(p).takeRetainedValue() as? T
    }
    let pt = UnsafeMutablePointer<T>(mutating: p.assumingMemoryBound(to: T.self))
    defer {
        pt.deinitialize(count: 1)
        pt.deallocate()
    }
    return pt.pointee
}

public final class Channel<T: Sendable>: @unchecked Sendable {
    
    @usableFromInline
    let chanInternal: ChannelInternal
    
    public init(capacity: Int = 0) {
        self.chanInternal = ChannelInternal(capacity: capacity)
    }
    
    var isClosed: Bool {
        chanInternal.isClosed
    }
    
    @inline(__always)
    @inlinable
    public func send(_ value: T) async {
        await chanInternal.send(ptr(value))
    }
    
    @inline(__always)
    @inlinable
    public func receive() async -> T? {
        return value(await chanInternal.receive())
    }
    
    @inline(__always)
    @inlinable
    public func syncSend(_ value: T) -> Bool {
        chanInternal.syncSend(ptr(value))
    }
    
    @inline(__always)
    @inlinable
    public func syncReceive() -> T? {
        return value(chanInternal.syncReceive())
        
    }
    
    public func close() {
        chanInternal.close()
    }
}

