import Foundation

public struct SelectHandler {
    
    @usableFromInline
    internal let inner: SelectProtocol
    
    @inlinable
    init(inner: SelectProtocol) {
        self.inner = inner
    }
}

@usableFromInline
protocol SelectProtocol {
    func handle(_ sm: SelectSignal) async -> Bool
}

@usableFromInline
struct ReceiveHandler<T>: SelectProtocol {
    
    private var chan: Channel<T>
    private let outFunc: (T?) async -> ()
    
    @usableFromInline
    init(chan: Channel<T>, outFunc: @escaping (T?) async -> ()) {
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
struct SendHandler<T>: SelectProtocol {
    private var chan: Channel<T>
    private let val: T
    private let onSend: () async -> ()
    
    @usableFromInline
    init(chan: Channel<T>, val: T, onSend: @escaping () async -> ()) {
        self.chan = chan
        self.val = val
        self.onSend = onSend
    }
    
    @usableFromInline
    func handle(_ sm: SelectSignal) async -> Bool {
        if chan.sendOrListen(sm, value: val) {
            await onSend()
            return true
        }
        return false
    }
}

@resultBuilder
public struct SelectCollector {
    public static func buildBlock(_ handlers: SelectHandler...) -> [SelectHandler] {
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

@inlinable
@inline(__always)
public func receive<T>(_ chan: Channel<T>, _ outFunc: @escaping (T?) async -> ()) -> SelectHandler {
    return SelectHandler(inner: ReceiveHandler(chan: chan, outFunc: outFunc))
}

@inlinable
@inline(__always)
public func receive<T>(_ chan: Channel<T>, _ outFunc: @escaping () async -> ()) -> SelectHandler {
    return SelectHandler(inner: ReceiveHandler(chan: chan, outFunc: { _ in await outFunc() }))
}

@inlinable
@inline(__always)
public func receive<T>(_ chan: Channel<T>) -> SelectHandler {
    return SelectHandler(inner: ReceiveHandler(chan: chan, outFunc: { _ in }))
}

@inlinable
@inline(__always)
public func send<T>(_ val: T, to chan: Channel<T>) -> SelectHandler {
    return SelectHandler(inner: SendHandler(chan: chan, val: val, onSend: {}))
}

@inlinable
@inline(__always)
public func send<T>(_ val: T, to chan: Channel<T>, _ onSend: @escaping () async -> ()) -> SelectHandler {
    return SelectHandler(inner: SendHandler(chan: chan, val: val, onSend: onSend))
}

@inlinable
@inline(__always)
public func none(handler: @escaping () async -> ()) -> SelectHandler {
    return SelectHandler(inner: NoneHandler(handler: handler))
}

