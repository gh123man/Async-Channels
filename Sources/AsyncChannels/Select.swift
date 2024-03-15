import Foundation

public protocol SelectHandler {
    func handle(_ sm: AsyncSemaphore) async -> Bool
}

struct RxHandler<T>: SelectHandler {
    private var chan: Channel<T>
    private let outFunc: (T?) async -> ()
    
    init(chan: Channel<T>, outFunc: @escaping (T?) async -> ()) {
        self.chan = chan
        self.outFunc = outFunc
    }
    
    func handle(_ sm: AsyncSemaphore) async -> Bool {
        if let val = await chan.receiveOrListen(sm) {
            await outFunc(val)
            return true
        }
        if await chan.isClosed() {
            await outFunc(nil)
            return true
        }
        return false
    }
}

struct NoneHandler: SelectHandler {
    private let handler: () async -> ()
    
    init(handler: @escaping () async -> ()) {
        self.handler = handler
    }
    
    func handle(_ sm: AsyncSemaphore) async -> Bool {
        await handler()
        return true
    }
}

struct TxHandler<T>: SelectHandler {
    private var chan: Channel<T>
    private let val: T
    
    init(chan: Channel<T>, val: T) {
        self.chan = chan
        self.val = val
    }
    
    func handle(_ sm: AsyncSemaphore) async -> Bool {
        return await chan.sendOrListen(sm, value: val)
    }
}

@resultBuilder
public struct SelectCollector {
    public static func buildBlock(_ handlers: SelectHandler...) -> [SelectHandler] {
        return handlers
    }
}

func handle(_ sm: AsyncSemaphore, handlers: [SelectHandler]) async -> Bool {
    var defaultCase: NoneHandler?
    
    for handler in handlers.shuffled() {
        if let noneHnadler = handler as? NoneHandler {
            defaultCase = noneHnadler
        } else if await handler.handle(sm) {
            return true
        }
    }
    return await defaultCase?.handle(sm) ?? false
}

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
    return RxHandler(chan: chan, outFunc: outFunc)
}

public func rx<T>(_ chan: Channel<T>, _ outFunc: @escaping () async -> ()) -> SelectHandler {
    return RxHandler(chan: chan, outFunc: { _ in await outFunc() })
}

public func rx<T>(_ chan: Channel<T>) -> SelectHandler {
    return RxHandler(chan: chan, outFunc: { _ in })
}

public func tx<T>(_ chan: Channel<T>, _ val: T) -> SelectHandler {
    return TxHandler(chan: chan, val: val)
}

public func none(handler: @escaping () async -> ()) -> SelectHandler {
    return NoneHandler(handler: handler)
}

