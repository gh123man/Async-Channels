import Foundation

@usableFromInline
actor SelectSignal {
    private var signaled = false
    private var continuation: UnsafeContinuation<Void, Never>?

    @usableFromInline
    init() {}

    @usableFromInline
    func wait() async {
        if signaled {
            return
        }
        await withUnsafeContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    private func _signal() {
        signaled = true
        continuation?.resume()
        continuation = nil
    }
    
    nonisolated func signal() {
        Task {
            await _signal()
        }
    }
}

