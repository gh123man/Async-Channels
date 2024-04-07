import Foundation
import AsyncChannels
import CoreFoundation
import AsyncAlgorithms


let iterations = 10


protocol Initializable {
    init()
}

extension Int : Initializable {}
extension String : Initializable {
    init() {
        self.init("My test string for benchmarking")
    }
}

struct ValueData: Initializable {
    let foo: String
    let bar: Int
    init() {
        foo = "My test string for benchmarking"
        bar = 1234
    }
}

class RefData: Initializable {
    let foo: String
    let bar: Int
    required init() {
        foo = "My test string for benchmarking"
        bar = 1234
    }
}

// MARK: Run Tests

print("Starting benchmarks with \(iterations) rounds")

await run(Int.self)
await run(String.self)
await run(ValueData.self)
await run(RefData.self)

await runAsyncAlg(Int.self)
await runAsyncAlg(String.self)
await runAsyncAlg(ValueData.self)
await runAsyncAlg(RefData.self)


func run<T: Initializable>(_ type: T.Type) async {
    print(await testSingleReaderManyWriter(type))
    print(await testHighConcurrency(type))
    print(await testHighConcurrencyBuffered(type))
    print(await testSyncRw(type))
    print(await testSelect(type))
}

func runAsyncAlg<T: Initializable>(_ type: T.Type) async {
    print(await testAsyncAlgSingleReaderManyWriter(type))
    print(await testAsyncAlgSingleHighConcurrency(type))
}

func timeIt(iterations: Int, block: () async -> ()) async -> Double {
    var sum: CFAbsoluteTime = 0
    for _ in 0..<iterations {
        let startTime = CFAbsoluteTimeGetCurrent()
        await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        sum += timeElapsed
    }
    return sum / Double(iterations)
    
}

func testSingleReaderManyWriter<T: Initializable>(_ type: T.Type) async -> (String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = Channel<T>()
        var sum = 0
        
        for _ in (0..<100) {
            Task {
                for _ in (0..<10000) {
                    await a <- T()
                }
            }
        }
        
        while sum < 1_000_000 {
            await <-a
            sum += 1
        }
    }
    return ("\(#function) \(T.self)", result)
}

func testHighConcurrency<T: Initializable>(_ type: T.Type) async -> (String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = Channel<T>()
        var sum = 0
        
        for _ in (0..<1000) {
            Task {
                for _ in (0..<1000) {
                    await a <- T()
                }
            }
        }
        
        while sum < 1_000_000 {
            await <-a
            sum += 1
        }
    }
    return ("\(#function) \(T.self)", result)
}

func testHighConcurrencyBuffered<T: Initializable>(_ type: T.Type) async -> (String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = Channel<T>(capacity: 20)
        var sum = 0
        
        for _ in (0..<1000) {
            Task {
                for _ in (0..<1000) {
                    await a <- T()
                }
            }
        }
        
        while sum < 1_000_000 {
            await <-a
            sum += 1
        }
    }
    return ("\(#function) \(T.self)", result)
}

func testSyncRw<T: Initializable>(_ type: T.Type) async -> (String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = Channel<T>(capacity: 1)
        
        for _ in (0..<5_000_000) {
            await a <- T()
            await <-a
        }
    }
    return ("\(#function) \(T.self)", result)
}



func testSelect<T: Initializable>(_ type: T.Type) async -> (String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = Channel<T>()
        let b = Channel<T>()
        let c = Channel<T>()
        let d = Channel<T>()
        let e = Channel<T>()
        let f = Channel<T>()
        
        for chan in [a, b, c, d, e, f] {
            Task {
                for _ in (0..<100_000) {
                    await chan <- T()
                }
            }
        }
        
        var sum = 0
        
        while sum < 6 * 100_000 {
            await select {
                rx(a) {
                    sum += 1
                }
                rx(b) {
                    sum += 1
                }
                rx(c) {
                    sum += 1
                }
                rx(d) {
                    sum += 1
                }
                rx(e) {
                    sum += 1
                }
                rx(f) {
                    sum += 1
                }
            }
        }
    }
    return ("\(#function) \(T.self)", result)
}


// Compare to async algorithms channels

func testAsyncAlgSingleReaderManyWriter<T: Initializable>(_ type: T.Type) async -> (String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = AsyncChannel<Int>()
        var sum = 0
        
        for _ in (0..<100) {
            Task {
                for _ in (0..<10000) {
                    await a.send(1)
                }
            }
        }
        
        for await n in a {
            sum += n
            if sum >= 1_000_000 {
                a.finish()
            }
        }
    }
    return ("\(#function) \(T.self)", result)
}

func testAsyncAlgSingleHighConcurrency<T: Initializable>(_ type: T.Type) async -> (String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = AsyncChannel<Int>()
        var sum = 0
        
        for _ in (0..<1000) {
            Task {
                for _ in (0..<1000) {
                    await a.send(1)
                }
            }
        }
        
        for await n in a {
            sum += n
            if sum >= 1_000_000 {
                a.finish()
            }
        }
    }
    return ("\(#function) \(T.self)", result)
}
