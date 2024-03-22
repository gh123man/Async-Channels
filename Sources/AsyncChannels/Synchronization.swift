import Foundation

class AsyncSemaphore {
    private var permits: Int
    private let mutex = FastLock()
    private var continuationQueue: [UnsafeContinuation<Void, Never>] = []

    init(value: Int) {
        self.permits = value
    }

    func wait() async {
        await withUnsafeContinuation { continuation in
            self.mutex.lock()
            defer { self.mutex.unlock() }
            if self.permits > 0 {
                self.permits -= 1
                continuation.resume()
            } else {
                self.continuationQueue.append(continuation)
            }
        }
    }
    
    func signal() {
        self.mutex.lock()
        defer { self.mutex.unlock() }
        if let next = continuationQueue.first {
            continuationQueue.removeFirst()
            next.resume()
        } else {
            permits += 1
        }
    }
}
