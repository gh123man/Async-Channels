import Foundation

@usableFromInline
actor AsyncSemaphore {
    private var signaled = false
    private var continuation: UnsafeContinuation<Void, Never>?

    @usableFromInline
    init(value: Int) {
//        self.permits = value
    }

    @usableFromInline
    func wait() async {
        if signaled {
            return
        }
        await withUnsafeContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    private func signalInternal() {
        signaled = true
        continuation?.resume()
        continuation = nil
    }
    
    nonisolated func signal() {
        Task {
            await signalInternal()
        }
        
    }
}

public actor WaitGroup {
    
    private var count = 0
    private var continuationQueue = LinkedList<UnsafeContinuation<Void, Never>>()

    public init(count: Int = 0) {
        self.count = count
    }
    
    public func add(_ val: Int) {
        count += val
    }
    
    public func done() {
        count -= 1
        if count <= 0 {
            count = 0
            while let waiter = continuationQueue.pop() {
                waiter.resume()
            }
            continuationQueue = LinkedList<UnsafeContinuation<Void, Never>>()
        }
    }
    
    public func wait() async {
        await withUnsafeContinuation { continuation in
            self.continuationQueue.push(continuation)
        }
    }
}
