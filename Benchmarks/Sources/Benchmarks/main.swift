import Foundation
import AsyncChannels
import CoreFoundation
import AsyncAlgorithms

let iterations = 10

protocol Initializable: Sendable {
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

final class RefData: Initializable {
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

//await testCoherency()
//await testLL()
await run(Int.self)
await run(String.self)
await run(ValueData.self)
await run(RefData.self)

await runAsyncAlg(Int.self)
await runAsyncAlg(String.self)
await runAsyncAlg(ValueData.self)
await runAsyncAlg(RefData.self)

class TestData {
    let foo: String
    let bar: Int
    
    init() {
        self.foo = "foo"
        self.bar = 123
    }
}

class TestDataDeinit: @unchecked Sendable {
    let foo: String
    let bar: Int
    
    init() {
        self.foo = "foo"
        self.bar = 123
    }
    
    deinit {
        print("deinited")
    }
}



struct TestStruct {
    var foo: String
    var bar: Int
    
    init() {
        self.foo = "foo"
        self.bar = 123
    }
}

func testCoherency() async {
    
    
    let c = Channel<[TestDataDeinit]>(capacity: 1)
//    for _ in 0..<10_000_000 {
        let f = [TestDataDeinit(), TestDataDeinit(), TestDataDeinit()]
        await c <- f
        let d = await <-c
        print(d![2].foo)
//    }
    print("Done with coherency")
    
    var l1 = RawLinkedList<String>()
    l1.push("foo")
    print(l1.pop()!)
    
    var l2 = RawLinkedList<Int>()
    l2.push(1)
    print(l2.pop()!)
    
    var l3 = RawLinkedList<TestStruct>()
    l3.push(TestStruct())
    print(l3.pop()!.foo)
    
    
//    var d = ["foo", "bar"]
//    var l4 = RawLinkedList<[String]>()
//    l4.push(d)
//    d[0] = "baz"
//    print(l4.pop()!)
//    print(d)
//    
//    var l5 = RawLinkedList<TestDataDeinit>()
//    l5.push(TestDataDeinit())
//    let retained = l5.pop()!
//    print(retained.foo)
}


func testLL() async {
    let size = 100_000
    let i = 4
    
    let classGenericPointer = await timeIt(iterations: i) {
        var ll = RawLinkedList<TestData>()
        for _ in 0..<size {
            for _ in 0..<100 {
                ll.push(TestData())
            }
            for _ in 0..<100 {
                _ = ll.pop()
            }
        }
    }
    print("class generic pointer", classGenericPointer)
    
    let classGeneric = await timeIt(iterations: i) {
        var ll = LinkedList<TestData>()
        for _ in 0..<size {
            for _ in 0..<100 {
                ll.push(TestData())
            }
            for _ in 0..<100 {
                _ = ll.pop()
            }
        }
    }
    print("class generic", classGeneric)
    
    let structGenericPointer = await timeIt(iterations: i) {
        var ll = RawLinkedList<TestStruct>()
        for _ in 0..<size {
            for _ in 0..<100 {
                ll.push(TestStruct())
            }
            for _ in 0..<100 {
                _ = ll.pop()
            }
        }
    }
    print("struct generic pointer", structGenericPointer)
    
    let structGeneric = await timeIt(iterations: i) {
        var ll = LinkedList<TestStruct>()
        for _ in 0..<size {
            for _ in 0..<100 {
                ll.push(TestStruct())
            }
            for _ in 0..<100 {
                _ = ll.pop()
            }
        }
    }
    print("struct generic", structGeneric)
    
    
    let intOptimized = await timeIt(iterations: i) {
        var ll = IntLinkedList()
        for _ in 0..<size {
            for i in 0..<100 {
                ll.push(i)
            }
            for _ in 0..<100 {
                _ = ll.pop()
            }
        }
    }
    print("Int", intOptimized)
}
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
    formatResult(await testMPSCWriteContentionBuffered(type))
    
    formatResult(await testSyncRw(type))
    formatResult(await testMultiSelect(type))
}

func runAsyncAlg<T: Initializable>(_ type: T.Type) async {
    formatResult(await testAsyncAlgSPSC(type))
    formatResult(await testAsyncAlgMPSC(type))
    formatResult(await testAsyncAlgSPMC(type))
    formatResult(await testAsyncAlgMPMC(type))
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

// MARK: Unbuffered tests

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

// MARK: Buffered tests

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
        
        async let writeGroup: () = withTaskGroup(of: Void.self) { group in
            for _ in 0..<producers {
                group.addTask {
                    for _ in 0 ..< writes / producers {
                        await a <- T()
                    }
                }
            }
        }
        
        async let readGroup: () = withTaskGroup(of: Void.self) { group in
            for _ in 0..<consumers {
                group.addTask {
                    for await _ in a {}
                }
            }
            
        }
        await writeGroup
        a.close()
        await readGroup
    }
}

func testSyncRw<T: Initializable>(_ type: T.Type, writes: Int = 5_000_000) async -> (String, String, Double) {
    let result = await timeIt(iterations: iterations) {
        let a = Channel<T>(capacity: 1)
        
        for _ in 0..<writes {
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
                receive(a) { sum += 1 }
                receive(b) { sum += 1 }
                receive(c) { sum += 1 }
                receive(d) { sum += 1 }
                receive(e) { sum += 1 }
                receive(f) { sum += 1 }
            }
        }
    }
    return ("Channel multi-select", "\(T.self)", result)
}



func runMPMCAsyncAlg<T: Initializable>(_ type: T.Type, producers: Int, consumers: Int, writes: Int, buffer: Int = 0) async -> Double {
    return await timeIt(iterations: iterations) {
        let a = AsyncChannel<T>()
        
        async let writeGroup: () = withTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 0 ..< writes / producers {
                    await a.send(T())
                }
            }
        }
        
        async let readGroup: () = withTaskGroup(of: Void.self) { group in
            for _ in 0..<consumers {
                group.addTask {
                    for await _ in a {}
                }
            }
        }
        
        await writeGroup
        a.finish()
        await readGroup
    }
}

