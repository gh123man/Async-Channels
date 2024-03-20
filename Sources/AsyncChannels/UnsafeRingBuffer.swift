import Foundation

class UnsafeRingBuffer<T> {
    private var buffer: UnsafeMutablePointer<T?>
    private var read: Int = 0
    private(set) var count: Int = 0
    private let capacity: Int
    
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

    private func mask(_ val: Int) -> Int {
        return val & (capacity - 1)
    }

    func push(_ val: T) {
        buffer.advanced(by: mask(read + count)).pointee = val
        count += 1
    }

    func pop() -> T {
        defer {
            count -= 1
            read = mask(read + 1)
        }
        return buffer.advanced(by: read).move()!
    }
}
