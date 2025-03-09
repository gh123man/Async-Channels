import Foundation

public struct SelectHandler {
    
    @usableFromInline
    internal let inner: SelectProtocol
    
    @inlinable
    init(inner: SelectProtocol) {
        self.inner = inner
    }
}

protocol Selectable {
}

extension Channel: Selectable {
    func intChan() -> ChannelInternal {
        return self.channelInternal
    }
}

@usableFromInline
protocol SelectProtocol {
    func handle(_ sm: SelectSignal) async -> Bool
}

@usableFromInline
struct ReceiveHandler: SelectProtocol {
    
    private var chan: ChannelInternal
    private let outFunc: (UnsafeRawPointer?) async -> ()
    
    @usableFromInline
    init(chan: ChannelInternal, outFunc: @escaping (UnsafeRawPointer?) async -> ()) {
        self.chan = chan
        self.outFunc = outFunc
    }
    
    @usableFromInline
    func handle(_ sm: SelectSignal) async -> Bool {
        if let val = chan.receiveOrListen(sm) {
            await outFunc(val)
            return true
        }
        if chan.isClosed {
            await outFunc(nil)
            return true
        }
        return false
    }
}

@usableFromInline
struct NoneHandler: SelectProtocol {
    private let handler: () async -> ()
    
    @usableFromInline
    init(handler: @escaping () async -> ()) {
        self.handler = handler
    }
    
    @usableFromInline
    func handle(_ sm: SelectSignal) async -> Bool {
        await handler()
        return true
    }
}

@usableFromInline
struct SendHandler: SelectProtocol {
    private var chan: ChannelInternal
    private let val: UnsafeRawPointer
    private let onSend: () async -> ()
    
    @usableFromInline
    init(chan: ChannelInternal, val: UnsafeRawPointer, onSend: @escaping () async -> ()) {
        self.chan = chan
        self.val = val
        self.onSend = onSend
    }
    
    @usableFromInline
    func handle(_ sm: SelectSignal) async -> Bool {
        if let handled = try? chan.sendOrListen(sm, p: val), handled {
            await onSend()
            return true
        }
        return false
    }
}

@resultBuilder
public struct SelectCollector {
    public static func buildBlock(_ handlers: [SelectHandler]...) -> [SelectHandler] {
        return handlers.reduce([], +)
    }
    
    public static func buildOptional(_ handlers: [SelectHandler]?) -> [SelectHandler] {
        return handlers ?? []
    }
    
    public static func buildEither(first handlers: [SelectHandler]) -> [SelectHandler] {
        return handlers
    }
    
    public static func buildEither(second handlers: [SelectHandler]) -> [SelectHandler] {
        return handlers
    }
}

@inlinable
@inline(__always)
func handle(_ sm: SelectSignal, handlers: [SelectHandler]) async -> Bool {
    var defaultCase: NoneHandler?
    
    for handler in handlers.shuffled() {
        if let noneHnadler = handler.inner as? NoneHandler {
            defaultCase = noneHnadler
        } else if await handler.inner.handle(sm) {
            return true
        }
    }
    return await defaultCase?.handle(sm) ?? false
}

@inlinable
@inline(__always)
public func select(@SelectCollector cases: () -> ([SelectHandler])) async {
    let handlers = cases()
    while true {
        let sm = SelectSignal()
        if await handle(sm, handlers: handlers) {
            return
        }
        await sm.wait()
    }
}

// MARK: Select functons for Channel<T>

public func receive<T>(_ chan: Channel<T>, _ outFunc: @escaping (T?) async -> ()) -> [SelectHandler] {
    return [SelectHandler(inner: ReceiveHandler(chan: chan.channelInternal, outFunc: { await outFunc(toValue($0)) }))]
}

public func receive<T>(_ chan: Channel<T>, _ outFunc: @escaping () async -> ()) -> [SelectHandler] {
    return [SelectHandler(inner: ReceiveHandler(chan: chan.channelInternal, outFunc: {
        // Unpack the pointer even if we don't use it - otherwise we can leak memory
        _ = toValue($0) as T?
        await outFunc()
    }))]
}

public func receive<T>(_ chan: Channel<T>) -> [SelectHandler] {
    return [SelectHandler(inner: ReceiveHandler(chan: chan.channelInternal, outFunc: {
        // Unpack the pointer even if we don't use it - otherwise we can leak memory
        _ = toValue($0) as T?
    }))]
}

public func send<T>(_ val: T, to chan: Channel<T>) -> [SelectHandler] {
    return [SelectHandler(inner: SendHandler(chan: chan.channelInternal, val: toPointer(val), onSend: {}))]
}

public func send<T>(_ val: T, to chan: Channel<T>, _ onSend: @escaping () async -> ()) -> [SelectHandler] {
    return [SelectHandler(inner: SendHandler(chan: chan.channelInternal, val: toPointer(val), onSend: onSend))]
}

public func none(handler: @escaping () async -> ()) -> [SelectHandler] {
    return [SelectHandler(inner: NoneHandler(handler: handler))]
}

public func any<S, T>(_ seq: S, @SelectCollector cases: (T) -> ([SelectHandler])) -> [SelectHandler] where S: Sequence, S.Element == T {
    return seq.flatMap { cases($0) }
}

public func any<T>(_ elements: T..., @SelectCollector cases: (T) -> ([SelectHandler])) -> [SelectHandler] {
    return elements.flatMap { cases($0) }
}

// MARK: Select functons for ThrowingChannel<T>

public func receive<T>(_ chan: ThrowingChannel<T>, _ outFunc: @escaping (T?) async -> ()) -> [SelectHandler] {
    return [SelectHandler(inner: ReceiveHandler(chan: chan.channelInternal, outFunc: { await outFunc(toValue($0)) }))]
}

public func receive<T>(_ chan: ThrowingChannel<T>, _ outFunc: @escaping () async -> ()) -> [SelectHandler] {
    return [SelectHandler(inner: ReceiveHandler(chan: chan.channelInternal, outFunc: {
        // Unpack the pointer even if we don't use it - otherwise we can leak memory
        _ = toValue($0) as T?
        await outFunc()
    }))]
}

public func receive<T>(_ chan: ThrowingChannel<T>) -> [SelectHandler] {
    return [SelectHandler(inner: ReceiveHandler(chan: chan.channelInternal, outFunc: {
        // Unpack the pointer even if we don't use it - otherwise we can leak memory
        _ = toValue($0) as T?
    }))]
}

public func send<T>(_ val: T, to chan: ThrowingChannel<T>) -> [SelectHandler] {
    return [SelectHandler(inner: SendHandler(chan: chan.channelInternal, val: toPointer(val), onSend: {}))]
}

public func send<T>(_ val: T, to chan: ThrowingChannel<T>, _ onSend: @escaping () async -> ()) -> [SelectHandler] {
    return [SelectHandler(inner: SendHandler(chan: chan.channelInternal, val: toPointer(val), onSend: onSend))]
}

