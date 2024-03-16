import Foundation

infix operator <- :AssignmentPrecedence
public func <- <T>(c: Channel<T>, value: T) async {
    await c.send(value)
}
public func <- <T>(value: inout T?, chan: Channel<T>) async {
    await value = chan.receive()
}

prefix operator <-
@discardableResult public prefix func <- <T>(chan: Channel<T>) async -> T? {
    return await chan.receive()
}

public final class Channel<T: Sendable>: @unchecked Sendable {
    class Sender<U> {
        private var value: U
        private var sema = AsyncSemaphore(value: 0)
        
        init(value: U) {
            self.value = value
        }
        
        func get() async -> U {
            await self.sema.signal()
            return value
        }
        
        func wait() async {
            await sema.wait()
        }
    }
    
    class Receiver<U> {
        private var value: U?
        private var sema = AsyncSemaphore(value: 0)
        
        func set(_ val: U?) async {
            value = val
            await sema.signal()
        }
        
        func get() async -> U? {
            await sema.wait()
            return value
        }
    }
    
    private let mutex = AsyncMutex()
    private let capacity: Int
    private var closed = false
    private var buffer = [T]()
    private var sendQueue = [Sender<T>]()
    private var recvQueue = [Receiver<T>]()

    public init(capacity: Int = 0) {
        self.capacity = capacity
    }

    var count: Int {
        return buffer.count
    }
    
    var selectWaiter: AsyncSemaphore?
    
    
    func isClosed() async -> Bool {
        await mutex.lock()
        let c = closed
        await mutex.unlock()
        return c
    }
    
    func receiveOrListen(_ sema: AsyncSemaphore) async -> T? {
        await mutex.lock()
        
        if let val = await nonBlockingReceive() {
            await mutex.unlock()
            return val
        }
        
        if closed {
            await mutex.unlock()
            return nil
        }
        
        self.selectWaiter = sema
        await mutex.unlock()
        return nil
    }
    
    func sendOrListen(_ sema: AsyncSemaphore, value: T) async -> Bool {
        await mutex.lock()
        
        if await nonBlockingSend(value) {
            await mutex.unlock()
            return true
        }
        
        self.selectWaiter = sema
        await mutex.unlock()
        return false
    }
    
    
    private func nonBlockingSend(_ value: T) async -> Bool {
        if closed {
            fatalError("Cannot send on a closed channel")
        }
        
        if let recvW = recvQueue.popFirst() {
            await recvW.set(value)
            return true
        }

        if self.buffer.count < self.capacity {
            self.buffer.append(value)
            return true
        }
        return false
    }
    

    func send(_ value: T) async {
        await mutex.lock()
        await selectWaiter?.signal()
        
        if await nonBlockingSend(value) {
            await mutex.unlock()
            return
        }
        
        let sender = Sender<T>(value: value)
        sendQueue.append(sender)
        await mutex.unlock()
        await sender.wait()
    }
    
    private func nonBlockingReceive() async -> T? {
        if let val = buffer.popFirst() {
            if let sendW = sendQueue.popFirst() {
                buffer.append(await sendW.get())
            }
            return val
        }
        return await sendQueue.popFirst()?.get()
    }

    func receive() async -> T? {
        await mutex.lock()
        await selectWaiter?.signal()

        if let val = await nonBlockingReceive() {
            await mutex.unlock()
            return val
        }
        
        if closed {
            await mutex.unlock()
            return nil
        }
        
        let receiver = Receiver<T>()
        recvQueue.append(receiver)
        await mutex.unlock()
        return await receiver.get()
    }
    
    func close() async {
        await mutex.lock()
        
        closed = true
        
        while let recvW = recvQueue.popFirst() {
            await recvW.set(nil)
        }
        await mutex.unlock()
    }
}



