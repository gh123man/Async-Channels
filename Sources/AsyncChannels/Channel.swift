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
        
        func get() -> U {
            Task {
                await self.sema.signal()
            }
            return value
        }
        
        func wait() async {
            await sema.wait()
        }
    }
    
    class Receiver<U> {
        private var value: U?
        private var sema = AsyncSemaphore(value: 0)
        
        func set(_ val: U?) {
            value = val
            Task {
                await sema.signal()
            }
        }
        
        func get() async -> U? {
            await sema.wait()
            return value
        }
    }
    
    private let mutex = FastLock()
    private let capacity: Int
    private var closed = false
    private var buffer: UnsafeRingBuffer<T>
    private var sendQueue = [Sender<T>]()
    private var recvQueue = [Receiver<T>]()

    public init(capacity: Int = 0) {
        self.capacity = capacity
        self.buffer = UnsafeRingBuffer(capacity: capacity)
    }

    var count: Int {
        mutex.lock()
        defer { mutex.unlock() }
        return buffer.count
    }
    
    var selectWaiter: AsyncSemaphore?
    
    var isClosed: Bool {
        mutex.lock()
        defer { mutex.unlock() }
        return closed
    }
    
    func receiveOrListen(_ sema: AsyncSemaphore) async -> T? {
        mutex.lock()
        
        if let val = nonBlockingReceive() {
            mutex.unlock()
            return val
        }
        
        if closed {
            mutex.unlock()
            return nil
        }
        
        self.selectWaiter = sema
        mutex.unlock()
        return nil
    }
    
    func sendOrListen(_ sema: AsyncSemaphore, value: T) async -> Bool {
        mutex.lock()
        
        if nonBlockingSend(value) {
            mutex.unlock()
            return true
        }
        
        self.selectWaiter = sema
        mutex.unlock()
        return false
    }
    
    
    private func nonBlockingSend(_ value: T) -> Bool {
        if closed {
            fatalError("Cannot send on a closed channel")
        }
        
        if let recvW = recvQueue.popFirst() {
            recvW.set(value)
            return true
        }

        if self.buffer.count < self.capacity {
            self.buffer.push(value)
            return true
        }
        return false
    }
    

    func send(_ value: T) async {
        mutex.lock()
        
        if nonBlockingSend(value) {
            mutex.unlock()
            return
        }
        
        let sender = Sender<T>(value: value)
        sendQueue.append(sender)
        mutex.unlock()
        await selectWaiter?.signal()
        await sender.wait()
    }
    
    private func nonBlockingReceive() -> T? {
        if buffer.isEmpty {
            return sendQueue.popFirst()?.get()
        }
        let val = buffer.pop()
        if let sendW = sendQueue.popFirst() {
            buffer.push(sendW.get())
        }
        return val
    }

    func receive() async -> T? {
        mutex.lock()

        if let val = nonBlockingReceive() {
            mutex.unlock()
            return val
        }
        
        if closed {
            mutex.unlock()
            return nil
        }
        
        let receiver = Receiver<T>()
        recvQueue.append(receiver)
        mutex.unlock()
        await selectWaiter?.signal()
        return await receiver.get()
    }
    
    func close() async {
        mutex.lock()
        closed = true
        
        while let recvW = recvQueue.popFirst() {
           recvW.set(nil)
        }
        mutex.unlock()
    }
}



