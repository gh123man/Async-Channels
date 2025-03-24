import Foundation

infix operator <- :AssignmentPrecedence

@inline(__always)
@inlinable
public func <- <T>(c: ThrowingChannel<T>, value: T) async throws {
    try await c.send(value)
}

@inline(__always)
@inlinable
public func <- <T>(value: inout T?, chan: ThrowingChannel<T>) async {
    await value = chan.receive()
}

prefix operator <-

@inline(__always)
@inlinable
@discardableResult public prefix func <- <T>(chan: ThrowingChannel<T>) async -> T? {
    return await chan.receive()
}

public final class ThrowingChannel<T: Sendable>: @unchecked Sendable, Selectable {
    
    @usableFromInline
    let channelInternal: ChannelInternal
    
    public init(capacity: Int = 0) {
        self.channelInternal = ChannelInternal(capacity: capacity)
    }
    
    public var isClosed: Bool {
        channelInternal.isClosed
    }
    
    /// Sends data on the channel. This function will suspend until a receiver is ready or buffer space is avalible.
    /// - Parameter value: The data to send.
    @inline(__always)
    @inlinable
    public func send(_ value: T) async throws {
        try await channelInternal.send(toPointer(value))
    }
    
    
    
    /// Receive data from the channel. This function will suspend until a sender is ready or there is data in the buffer.
    /// This functionw will return `nil` when the channel is closed after all buffered data is read.
    /// - Returns: data or nil.
    @inline(__always)
    @inlinable
    public func receive() async -> T? {
        return toValue(await channelInternal.receive())
    }
    
    
    /// Sends data synchonosly. Returns true if the data was sent.
    /// A fatal error will be triggered if you attpend to send on a closed channel.
    /// - Parameter value: The input data.
    @inline(__always)
    @inlinable
    public func syncSend(_ value: T) throws -> Bool {
        return try channelInternal.syncSend(toPointer(value))
    }
    
    /// Receive data synchronosly. Returns nil if there is no data or the channel is closed.
    /// This function will never block or suspend.
    /// - Returns: The data or nil
    @inline(__always)
    @inlinable
    public func syncReceive() -> T? {
        return toValue(channelInternal.syncReceive())
        
    }
    
    /// Closes the channel. A channel cannot be reopened.
    /// Once a channel is closed, no more data can be writeen. The remaining data can be read until the buffer is empty.
    @inline(__always)
    public func close() {
        channelInternal.close()
    }
}

