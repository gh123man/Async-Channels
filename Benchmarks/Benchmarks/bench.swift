//
//  main.swift
//  Benchmarks
//
//  Created by Brian Floersch on 3/19/24.
//

import Foundation
import AsyncChannels

@main
struct AppMain {
    static func main() async throws {
        await testSingleReaderManyWriter()
        await testHighConcurrency()
        await testHighConcurrencyBuffered()
        await syncRw()
//        await syncRwActor()
//        await testUnsafeRing()
//        await testRing()
    }
}

func timeIt(iterations: Int, block: () async -> ()) async {
    var sum: CFAbsoluteTime = 0
    for _ in 0..<iterations {
        let startTime = CFAbsoluteTimeGetCurrent()
        await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        sum += timeElapsed
    }
    print("Time elapsed: \(sum / Double(iterations))")
    
}

func testSingleReaderManyWriter() async {
    print(#function)
    await timeIt(iterations: 3) {
        let a = Channel<Int>()
        var sum = 0
        
        for _ in (0..<100) {
            Task {
                for _ in (0..<10000) {
                    await a <- 1
                }
            }
        }
        
        while sum < 1_000_000 {
            sum += (await <-a)!
        }
    }
}

func testHighConcurrency() async {
    print(#function)
    await timeIt(iterations: 3) {
        let a = Channel<Int>()
        var sum = 0
        
        for _ in (0..<1000) {
            Task {
                for _ in (0..<1000) {
                    await a <- 1
                }
            }
        }
        
        while sum < 1_000_000 {
            sum += (await <-a)!
        }
    }
}

func testHighConcurrencyBuffered() async {
    print(#function)
    await timeIt(iterations: 1) {
        let a = Channel<Int>(capacity: 20)
        var sum = 0
        
        for _ in (0..<1000) {
            Task {
                for _ in (0..<1000) {
                    await a <- 1
                }
            }
        }
        
        while sum < 1_000_000 {
            sum += (await <-a)!
        }
    }
}

func syncRw() async {
    print(#function)
    await timeIt(iterations: 3) {
        let a = Channel<Int>(capacity: 1)
        
        for i in (0..<5_000_000) {
            await a <- i
            await <-a
        }
    }
}


func syncRwActor() async {
    print(#function)
    await timeIt(iterations: 3) {
        for i in (0..<5_000_000) {
            var t = Thing()
            await t.set(i)
            await _ = t.get()
        }
    }
}

func testUnsafeRing() async {
    print(#function)
    await timeIt(iterations: 1) {
        
        let r = UnsafeRingBuffer<Int>(capacity: 100)
        for i in (0..<10_000_000) {
            for _ in (0..<50) {
                r.push(i)
            }
            for _ in (0..<50) {
                _ = r.pop()
            }
        }
    }
}

func testRing() async {
    print(#function)
    await timeIt(iterations: 1) {
        
        let r = RingBuffer<Int>(capacity: 100)
        for i in (0..<10_000_000) {
            for _ in (0..<50) {
                r.push(i)
            }
            for _ in (0..<50) {
                _ = r.pop()
            }
        }
    }
}



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

class RingBuffer<T> {
    private var buffer: [T?]
    private var read: Int = 0
    private(set) var count: Int = 0
    private let capacity: Int
    
    var isEmpty: Bool {
        return count == 0
    }
    
    init(capacity: Int) {
        self.capacity = capacity
        buffer = [T?](repeating: nil, count: capacity)
    }
    

    private func mask(_ val: Int) -> Int {
        return val & (capacity - 1)
    }

    func push(_ val: T) {
        buffer[mask(read + count)] = val
        count += 1
    }

    func pop() -> T {
        defer {
            count -= 1
            read = mask(read + 1)
        }
        return buffer[read]!
    }

}
