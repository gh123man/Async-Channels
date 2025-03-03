import Foundation

public struct LinkedList<T> {
    final class Node {
        var value: T
        var next: Node?

        init(value: T) {
            self.value = value
        }
    }

    private(set) var isEmpty: Bool = true
    private var head: Node?
    private var tail: Node?
    private(set) var count: Int = 0
    
    public init() {}

    @inline(__always)
    public mutating func push(_ value: T) {
        let node = Node(value: value)
        if head == nil {
            head = node
            tail = node
        } else {
            tail?.next = node
            tail = node
        }
        count += 1
        isEmpty = false
    }
    
    @inline(__always)
    public mutating func pop() -> T? {
        let value = head?.value
        head = head?.next
        if head == nil {
            isEmpty = true
            tail = nil
        }
        count -= 1
        return value
    }
}
