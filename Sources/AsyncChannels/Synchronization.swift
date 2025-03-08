import Foundation

@usableFromInline
actor SelectSignal {
    @usableFromInline
    var signaled = false
    @usableFromInline
    var continuation: UnsafeContinuation<Void, Never>?

    @usableFromInline
    init() {}

    @inline(__always)
    @inlinable
    func wait() async {
        if signaled {
            return
        }
        await withUnsafeContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    @inline(__always)
    @inlinable
    func _signal() {
        signaled = true
        continuation?.resume()
        continuation = nil
    }
    
    @inline(__always)
    @inlinable
    nonisolated func signal() {
        Task {
            await _signal()
        }
    }
}

