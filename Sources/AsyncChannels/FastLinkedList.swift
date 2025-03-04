import Foundation

public func isPointer<T>(_ type: T.Type) -> Bool {
    return (type is AnyObject.Type)
}

public struct IntLinkedList {
    final class Node {
        var value: Int
        var next: Node?

        init(value: Int) {
            self.value = value
        }
    }

    private(set) var isEmpty: Bool = true
    private var head: Node?
    private var tail: Node?
    private(set) var count: Int = 0
    
    public init() { }

    @inline(__always)
    public mutating func push(_ value: Int) {
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
    public mutating func pop() -> Int? {
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

public struct PtrLinkedList {
    final class Node {
        var value: UnsafeRawPointer
        var next: Node?

        init(value: UnsafeRawPointer) {
            self.value = value
        }
    }

    public init() { }
    
    private(set) var isEmpty: Bool = true
    private var head: Node?
    private var tail: Node?
    private(set) var count: Int = 0

    @inline(__always)
    public mutating func push(_ value: UnsafeRawPointer) {
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
    public mutating func pop() -> UnsafeRawPointer? {
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

public struct RawLinkedList<T> {
    
    @usableFromInline
    var data = PtrLinkedList()
    var count: Int {
        return data.count
    }
    
    var isEmpty: Bool {
        return data.isEmpty
    }
    
    public init() {
    }
    
}


extension RawLinkedList where T: Any {
    @inlinable
    @inline(__always)
    public mutating func push(_ value: T) {
        data.push(ptr(value))
    }
    
    @inlinable
    @inline(__always)
    public mutating func pop() -> T? {
        return value(data.pop())
    }
}


