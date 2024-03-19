import Foundation

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
