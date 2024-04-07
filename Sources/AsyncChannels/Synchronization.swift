import Foundation

@usableFromInline
class AsyncSemaphore {
    private var permits: Int
    private var mutex = FastLock()
    private var continuationQueue = LinkedList<UnsafeContinuation<Void, Never>>()

    @usableFromInline
    init(value: Int) {
        self.permits = value
    }

    @usableFromInline
    func wait() async {
        await withUnsafeContinuation { continuation in
            self.mutex.lock()
            if self.permits > 0 {
                self.permits -= 1
                self.mutex.unlock()
                continuation.resume()
            } else {
                self.continuationQueue.push(continuation)
                self.mutex.unlock()
            }
        }
    }
    
    func signal() {
        self.mutex.lock()
        if let next = continuationQueue.pop() {
            self.mutex.unlock()
            next.resume()
        } else {
            permits += 1
            self.mutex.unlock()
        }
    }
}
