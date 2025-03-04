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

func ptr<T>(_ value: T) -> UnsafeRawPointer {
    if T.self is AnyObject.Type {
        return UnsafeRawPointer(Unmanaged.passRetained(value as AnyObject).toOpaque())
    }
    let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
    ptr.initialize(to: value)
    return UnsafeRawPointer(ptr)
}

func value<T>(_ p: UnsafeRawPointer?) -> T? {
    if T.self is AnyObject.Type {
        guard let p = p else {
            return nil
        }
        return Unmanaged<AnyObject>.fromOpaque(p).takeRetainedValue() as? T
    }
    defer { p?.deallocate() }
    return p?.assumingMemoryBound(to: T.self).pointee
}

public final class Channel<T: Sendable>: @unchecked Sendable {
    
    let chanInternal: ChannelInternal
    
    public init(capacity: Int = 0) {
        self.chanInternal = ChannelInternal(capacity: capacity)
    }
    
    var isClosed: Bool {
        chanInternal.isClosed
    }
    
    public func send(_ value: T) async {
        await chanInternal.send(ptr(value))
    }
    
    public func receive() async -> T? {
        return value(await chanInternal.receive())
    }
    
    public func syncSend(_ value: T) -> Bool {
        chanInternal.syncSend(ptr(value))
    }
    
    public func syncReceive() -> T? {
        return value(chanInternal.syncReceive())
        
    }
    
    public func close() {
        chanInternal.close()
    }
}

