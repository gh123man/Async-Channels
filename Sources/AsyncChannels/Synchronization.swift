import Foundation

actor AsyncMutex {
    private var isLocked: Bool = false
    private var continuationQueue: [CheckedContinuation<Void, Never>] = []

    func lock() async {
        await withCheckedContinuation { continuation in
            if self.isLocked {
                self.continuationQueue.append(continuation)
            } else {
                self.isLocked = true
                continuation.resume()
            }
        }
    }

    func unlock() {
        if let next = continuationQueue.first {
            continuationQueue.removeFirst()
            next.resume()
        } else {
            isLocked = false
        }
    }
}

actor AsyncSemaphore {
    private var permits: Int
    private var continuationQueue: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.permits = value
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            if self.permits > 0 {
                self.permits -= 1
                continuation.resume()
            } else {
                self.continuationQueue.append(continuation)
            }
        }
    }

    func signal() {
        if let next = continuationQueue.first {
            continuationQueue.removeFirst()
            next.resume()
        } else {
            permits += 1
        }
    }
}
