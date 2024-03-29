import Foundation

public struct SelectHandler {
    internal let inner: SelectProtocol
    
    init(inner: SelectProtocol) {
        self.inner = inner
    }
}

protocol SelectProtocol {
    func handle(_ sm: AsyncSemaphore) async -> Bool
}

@usableFromInline
struct RxHandler<T>: SelectProtocol {
    
    @usableFromInline
    var chan: Channel<T>
    
    @usableFromInline
    let outFunc: (T?) async -> ()
    
    @usableFromInline
    init(chan: Channel<T>, outFunc: @escaping (T?) async -> ()) {
        self.chan = chan
        self.outFunc = outFunc
    }
    
    @inline(__always)
    @inlinable
    func handle(_ sm: AsyncSemaphore) async -> Bool {
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
    
    func handle(_ sm: AsyncSemaphore) async -> Bool {
        await handler()
        return true
    }
}

struct TxHandler<T>: SelectProtocol {
    private var chan: Channel<T>
    private let val: T
    
    init(chan: Channel<T>, val: T) {
        self.chan = chan
        self.val = val
    }
    
    func handle(_ sm: AsyncSemaphore) -> Bool {
        return chan.sendOrListen(sm, value: val)
    }
}

@resultBuilder
public struct SelectCollector {
    public static func buildBlock(_ handlers: SelectHandler...) -> [SelectHandler] {
        return handlers
    }
}

@usableFromInline
func handle(_ sm: AsyncSemaphore, handlers: [SelectHandler]) async -> Bool {
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
        let sm = AsyncSemaphore(value: 0)
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
    return SelectHandler(inner: TxHandler(chan: chan, val: val))
}

public func none(handler: @escaping () async -> ()) -> SelectHandler {
    return SelectHandler(inner: NoneHandler(handler: handler))
}

