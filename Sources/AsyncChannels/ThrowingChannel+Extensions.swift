import Foundation

extension ThrowingChannel: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = T
    
    public func makeAsyncIterator() -> ThrowingChannel {
        return self
    }
    
    public func next() async -> T? {
        return await <-self
    }
}

extension ThrowingChannel {
    
    /// Blocks the current thread until a value is sent.
    /// Useful for synchonizing async with non-async code.
    /// Do not use this function in an async task!
    public func blockingSend(_ val: T) throws {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            // TODO
            try await self <- val
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    /// Blocks the current thread until a value is received.
    /// Useful for synchonizing async with non-async code.
    /// Do not use this function in an async task!
    public func blockingReceive() -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        var val: T?
        Task {
            val = await <-self
            semaphore.signal()
        }
        semaphore.wait()
        return val
    }
}
