//
//  main.swift
//  Benchmarks
//
//  Created by Brian Floersch on 3/19/24.
//

import Foundation
import AsyncChannels
import Combine

let iterations = 10

@main
struct AppMain {
    static func main() async throws {
        await testSingleReaderManyWriter()
        await testHighConcurrency()
        await testHighConcurrencyBuffered()
        await testSyncRw()
        await testSelect()
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
    await timeIt(iterations: iterations) {
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
    await timeIt(iterations: iterations) {
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
    await timeIt(iterations: iterations) {
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

func testSyncRw() async {
    print(#function)
    await timeIt(iterations: iterations) {
        let a = Channel<Int>(capacity: 1)
        
        for i in (0..<5_000_000) {
            await a <- i
            await <-a
        }
    }
}



func testSelect() async {
    print(#function)
    await timeIt(iterations: iterations) {
        let a = Channel<Int>()
        let b = Channel<Int>()
        let c = Channel<Int>()
        let d = Channel<Int>()
        let e = Channel<Int>()
        let f = Channel<Int>()
        
        for chan in [a, b, c, d, e, f] {
            Task {
                for _ in (0..<100_000) {
                    await chan <- 1
                }
            }
        }
        
        var sum = 0
        
        while sum < 6 * 100_000 {
            await select {
                rx(a) {
                    sum += $0!
                }
                rx(b) {
                    sum += $0!
                }
                rx(c) {
                    sum += $0!
                }
                rx(d) {
                    sum += $0!
                }
                rx(e) {
                    sum += $0!
                }
                rx(f) {
                    sum += $0!
                }
            }
        }
    }
}



func combineTest() {
    let subject = PassthroughSubject<Int, Never>()
    var cancellables = Set<AnyCancellable>()
    let queue = DispatchQueue(label: "com.yourapp.queue", attributes: .concurrent)
    var sum = 0

    // Subscribe to the subject
    subject
        .receive(on: RunLoop.main) // Ensure the sum is updated on the main thread
        .sink(receiveValue: { value in
            sum += value
            if sum >= 1_000_000 {
                print("Sum reached: \(sum)")
                cancellables.removeAll() // Cancel the subscription once the condition is met
            }
        })
        .store(in: &cancellables)

    // Simulate the goroutines
    for _ in 0..<100 {
        queue.async {
            for _ in 0..<10000 {
                subject.send(1)
            }
        }
    }
}
