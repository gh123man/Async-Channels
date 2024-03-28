import Foundation

internal class UnsafeRingBuffer<T> {
    private var buffer: UnsafeMutablePointer<T?>
    private var read: Int = 0
    private(set) var count: Int = 0
    private let capacity: Int
    
    @inlinable
    @inline(__always)
    var isEmpty: Bool {
        return count == 0
    }
    
    init(capacity: Int) {
        self.capacity = capacity
        buffer = UnsafeMutablePointer<T?>.allocate(capacity: capacity)
    }
    
    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }

    @inline(__always)
    private func mask(_ val: Int) -> Int {
        return val & (capacity - 1)
    }

    @inlinable
        @inline(__always)
    func push(_ val: T) {
        buffer.advanced(by: mask(read + count)).pointee = val
        count += 1
    }

    @inlinable
    @inline(__always)
    func pop() -> T {
        defer {
            count -= 1
            read = mask(read + 1)
        }
        return buffer.advanced(by: read).move()!
    }
}
