import Foundation
import AsyncChannels
import CoreFoundation
import AsyncAlgorithms


let iterations = 3


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

print()
print("Starting benchmarks with \(iterations) rounds")
print()
print("Test | Type | Execution Time(ms)")
print("-----|------|---------------")

//await run(Int.self)
//await run(String.self)
//await run(ValueData.self)
//await run(RefData.self)

await runAsyncAlg(Int.self)
await runAsyncAlg(String.self)
await runAsyncAlg(ValueData.self)
await runAsyncAlg(RefData.self)


func run<T: Initializable>(_ type: T.Type) async {
    formatResult(await testSPSC(type))
    formatResult(await testMPSC(type))
    formatResult(await testSPMC(type))
    formatResult(await testMPMC(type))
    formatResult(await testMPSCWriteContention(type))

    formatResult(await testSPSCBuffered(type))
    formatResult(await testMPSCBuffered(type))
    formatResult(await testSPMCBuffered(type))
    formatResult(await testMPMCBuffered(type))
    
    formatResult(await testSyncRw(type))
    formatResult(await testMultiSelect(type))
}

func runAsyncAlg<T: Initializable>(_ type: T.Type) async {
//    formatResult(await testAsyncAlgSPSC(type))
//    formatResult(await testAsyncAlgMPSC(type))
//    formatResult(await testAsyncAlgSPMC(type))
//    formatResult(await testAsyncAlgMPMC(type))
    formatResult(await testAsyncAlgMPSCWriteContention(type))
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

func formatResult(_ result: (String, String, Double)) {
    let (name, type, val) = result
    print("\(name) | `\(type)` | `\(Int(val * 1000))`")
}

// MARK: Basic tests

func testSPSC<T: Initializable>(_ type: T.Type, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: 1, consumers: 1, writes: writes)
    return ("SPSC", "\(T.self)", result)
}

func testMPSC<T: Initializable>(_ type: T.Type, producers: Int = 5, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: producers, consumers: 1, writes: writes)
    return ("MPSC", "\(T.self)", result)
}

func testSPMC<T: Initializable>(_ type: T.Type, consumers: Int = 5, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: 1, consumers: consumers, writes: writes)
    return ("SPMC", "\(T.self)", result)
}

func testMPMC<T: Initializable>(_ type: T.Type, producers: Int = 5, consumers: Int = 5, writes: Int = 1_000_000, buffer: Int = 100) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: producers, consumers: consumers, writes: writes, buffer: buffer)
    return ("MPMC", "\(T.self)", result)
}

func testMPSCWriteContention<T: Initializable>(_ type: T.Type, producers: Int = 1000, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: producers, consumers: 1, writes: writes)
    return ("MPSC Write Contention", "\(T.self)", result)
}

// MARK: Basic tests buffered

func testSPSCBuffered<T: Initializable>(_ type: T.Type, writes: Int = 1_000_000, buffer: Int = 100) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: 1, consumers: 1, writes: writes, buffer: buffer)
    return ("SPSC Buffered(\(buffer))", "\(T.self)", result)
}

func testMPSCBuffered<T: Initializable>(_ type: T.Type, producers: Int = 5, writes: Int = 1_000_000, buffer: Int = 100) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: producers, consumers: 1, writes: writes, buffer: buffer)
    return ("MPSC Buffered(\(buffer))", "\(T.self)", result)
}

func testSPMCBuffered<T: Initializable>(_ type: T.Type, consumers: Int = 5, writes: Int = 1_000_000, buffer: Int = 100) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: 1, consumers: consumers, writes: writes, buffer: buffer)
    return ("SPMC Buffered(\(buffer))", "\(T.self)", result)
}

func testMPMCBuffered<T: Initializable>(_ type: T.Type, producers: Int = 5, consumers: Int = 5, writes: Int = 1_000_000, buffer: Int = 100) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: producers, consumers: consumers, writes: writes, buffer: buffer)
    return ("MPMC Buffered(\(buffer))", "\(T.self)", result)
}

func testMPSCWriteContentionBuffered<T: Initializable>(_ type: T.Type, producers: Int = 1000, writes: Int = 1_000_000, buffer: Int = 100) async -> (String, String, Double) {
    let result = await runMPMC(type, producers: producers, consumers: 1, writes: writes, buffer: buffer)
    return ("MPSC Write Contention Buffered(\(buffer))", "\(T.self)", result)
}

// MARK: Async alg comparison tests

func testAsyncAlgSPSC<T: Initializable>(_ type: T.Type, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMCAsyncAlg(type, producers: 1, consumers: 1, writes: writes)
    return ("SPSC Async alg", "\(T.self)", result)
}

func testAsyncAlgMPSC<T: Initializable>(_ type: T.Type, producers: Int = 5, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMCAsyncAlg(type, producers: producers, consumers: 1, writes: writes)
    return ("MPSC Async alg", "\(T.self)", result)
}

func testAsyncAlgSPMC<T: Initializable>(_ type: T.Type, consumers: Int = 5, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMCAsyncAlg(type, producers: 1, consumers: consumers, writes: writes)
    return ("SPMC Async alg", "\(T.self)", result)
}

func testAsyncAlgMPMC<T: Initializable>(_ type: T.Type, producers: Int = 5, consumers: Int = 5, writes: Int = 1_000_000, buffer: Int = 100) async -> (String, String, Double) {
    let result = await runMPMCAsyncAlg(type, producers: producers, consumers: consumers, writes: writes, buffer: buffer)
    return ("MPMC Async alg", "\(T.self)", result)
}

func testAsyncAlgMPSCWriteContention<T: Initializable>(_ type: T.Type, producers: Int = 1000, writes: Int = 1_000_000) async -> (String, String, Double) {
    let result = await runMPMCAsyncAlg(type, producers: producers, consumers: 1, writes: writes)
    return ("MPSC Async alg Write Contention", "\(T.self)", result)
}


func runMPMC<T: Initializable>(_ type: T.Type, producers: Int, consumers: Int, writes: Int, buffer: Int = 0) async -> Double {
    return await timeIt(iterations: iterations) {
        let a = Channel<T>(capacity: buffer)
        let wg = Channel<Int>(capacity: producers + consumers)
        
        for _ in 0..<producers {
            Task {
                for _ in (0 ..< writes / producers) {
                    await a <- T()
                }
                await wg <- 1
            }
        }
        
        for _ in 0..<consumers {
            Task {
                for await _ in a {}
                await wg <- 1
            }
        }
        
        var sum = 0
        while sum < producers {
            sum += (await <-wg)!
        }
        
        a.close()
        
        while sum < consumers + producers {
            sum += (await <-wg)!
        }
    }
}

func testSyncRw<T: Initializable>(_ type: T.Type, writes: Int = 5_000_000) async -> (String, String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = Channel<T>(capacity: 1)
        
        for _ in (0..<writes) {
            await a <- T()
            await <-a
        }
    }
    return ("SyncRW", "\(T.self)", result)
}



func testMultiSelect<T: Initializable>(_ type: T.Type) async -> (String, String, Double) {
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
    return ("Channel multi-select", "\(T.self)", result)
}



func runMPMCAsyncAlg<T: Initializable>(_ type: T.Type, producers: Int, consumers: Int, writes: Int, buffer: Int = 0) async -> Double {
    return await timeIt(iterations: iterations) {
        let a = AsyncChannel<T>()
        let wg = Channel<Int>(capacity: producers + consumers)
        
        for _ in 0..<producers {
            Task {
                for _ in (0 ..< writes / producers) {
                    await a.send(T())
                }
                await wg <- 1
            }
        }
        
        for _ in 0..<consumers {
            Task {
                for await _ in a {}
                await wg <- 1
            }
        }
        
        var sum = 0
        while sum < producers {
            sum += (await <-wg)!
        }
        
        a.finish()
        
        while sum < consumers + producers {
            sum += (await <-wg)!
        }
    }
}

