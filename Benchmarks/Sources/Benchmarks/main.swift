import Foundation
import AsyncChannels
import CoreFoundation
import AsyncAlgorithms


let iterations = 10

await run()
await runAsyncAlg()

func run() async {
    await testSingleReaderManyWriter()
    await testHighConcurrency()
    await testHighConcurrencyBuffered()
    await testSyncRw()
    await testSelect()
}

func runAsyncAlg() async {
    await testAsyncAlgSingleReaderManyWriter()
    await testAsyncAlgSingleHighConcurrency()
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


// Compare to async algorithms channels

func testAsyncAlgSingleReaderManyWriter() async {
    print(#function)
    await timeIt(iterations: iterations) {
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
}

func testAsyncAlgSingleHighConcurrency() async {
    print(#function)
    await timeIt(iterations: iterations) {
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
}
