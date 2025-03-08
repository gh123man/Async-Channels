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
func ptr<T: Sendable>(_ value: T) -> UnsafeRawPointer {
    if T.self is AnyObject.Type {
        return UnsafeRawPointer(Unmanaged.passRetained(value as AnyObject).toOpaque())
    }
    let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
    ptr.initialize(to: value)
    return UnsafeRawPointer(ptr)
}

@inline(__always)
@inlinable
func value<T: Sendable>(_ p: UnsafeRawPointer?) -> T? {
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
    
    public var isClosed: Bool {
        chanInternal.isClosed
    }
    
    /// Sends data on the channel. This function will suspend until a receiver is ready or buffer space is avalible.
    /// - Parameter value: The data to send.
    @inline(__always)
    @inlinable
    public func send(_ value: T) async {
        await chanInternal.send(ptr(value))
    }
    
    
    
    /// Receive data from the channel. This function will suspend until a sender is ready or there is data in the buffer.
    /// This functionw will return `nil` when the channel is closed after all buffered data is read.
    /// - Returns: data or nil.
    @inline(__always)
    @inlinable
    public func receive() async -> T? {
        return value(await chanInternal.receive())
    }
    
    
    /// Sends data synchonosly. Returns true if the data was sent.
    /// A fatal error will be triggered if you attpend to send on a closed channel.
    /// - Parameter value: The input data.
    @inline(__always)
    @inlinable
    public func syncSend(_ value: T) -> Bool {
        chanInternal.syncSend(ptr(value))
    }
    
    /// Receive data synchronosly. Returns nil if there is no data or the channel is closed.
    /// This function will never block or suspend.
    /// - Returns: The data or nil
    @inline(__always)
    @inlinable
    public func syncReceive() -> T? {
        return value(chanInternal.syncReceive())
        
    }
    
    /// Closes the channel. A channel cannot be reopened.
    /// Once a channel is closed, no more data can be writeen. The remaining data can be read until the buffer is empty.
    @inline(__always)
    public func close() {
        chanInternal.close()
    }
}

