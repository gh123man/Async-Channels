import Foundation

public struct SelectHandler {
    internal let inner: SelectProtocol
    
    init(inner: SelectProtocol) {
        self.inner = inner
    }
}

protocol SelectProtocol {
    func handle(_ sm: SelectSignal) async -> Bool
}

struct RxHandler<T>: SelectProtocol {
    
    private var chan: Channel<T>
    private let outFunc: (T?) async -> ()
    
    init(chan: Channel<T>, outFunc: @escaping (T?) async -> ()) {
        self.chan = chan
        self.outFunc = outFunc
    }
    
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

struct NoneHandler: SelectProtocol {
    private let handler: () async -> ()
    
    init(handler: @escaping () async -> ()) {
        self.handler = handler
    }
    
    func handle(_ sm: SelectSignal) async -> Bool {
        await handler()
        return true
    }
}

struct TxHandler<T>: SelectProtocol {
    private var chan: Channel<T>
    private let val: T
    private let onSend: () async -> ()
    
    init(chan: Channel<T>, val: T, onSend: @escaping () async -> ()) {
        self.chan = chan
        self.val = val
        self.onSend = onSend
    }
    
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

@usableFromInline
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

public func rx<T>(_ chan: Channel<T>, _ outFunc: @escaping (T?) async -> ()) -> SelectHandler {
    return SelectHandler(inner: RxHandler(chan: chan, outFunc: outFunc))
}

public func rx<T>(_ chan: Channel<T>, _ outFunc: @escaping () async -> ()) -> SelectHandler {
    return SelectHandler(inner: RxHandler(chan: chan, outFunc: { _ in await outFunc() }))
}

public func rx<T>(_ chan: Channel<T>) -> SelectHandler {
    return SelectHandler(inner: RxHandler(chan: chan, outFunc: { _ in }))
}

public func tx<T>(_ chan: Channel<T>, _ val: T) -> SelectHandler {
    return SelectHandler(inner: TxHandler(chan: chan, val: val, onSend: {}))
}

public func tx<T>(_ chan: Channel<T>, _ val: T, _ onSend: @escaping () async -> ()) -> SelectHandler {
    return SelectHandler(inner: TxHandler(chan: chan, val: val, onSend: onSend))
}

public func none(handler: @escaping () async -> ()) -> SelectHandler {
    return SelectHandler(inner: NoneHandler(handler: handler))
}

