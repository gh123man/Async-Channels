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
        var value: OpaquePointer
        var next: Node?

        init(value: OpaquePointer) {
            self.value = value
        }
    }

    public init() { }
    
    private(set) var isEmpty: Bool = true
    private var head: Node?
    private var tail: Node?
    private(set) var count: Int = 0

    @inline(__always)
    public mutating func push(_ value: OpaquePointer) {
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
    public mutating func pop() -> OpaquePointer? {
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
    
    private var data = PtrLinkedList()
    
    public init() {
    }
    
}

extension RawLinkedList where T: AnyObject {
    public mutating func push(_ value: T) {
        data.push(OpaquePointer(Unmanaged.passRetained(value).toOpaque()))
    }
    
    public mutating func pop() -> T? {
        let p = data.pop()
        return Unmanaged<T>.fromOpaque(UnsafeRawPointer(p)!).takeRetainedValue()
    }
}

extension RawLinkedList where T: Any {
    public mutating func push(_ value: T) {
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        ptr.initialize(to: value)
        let optr = OpaquePointer(ptr)
        data.push(optr)
    }
    
    public mutating func pop() -> T? {
        return UnsafeMutablePointer<T>(data.pop())?.pointee
    }
}


