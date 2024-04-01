import XCTest
@testable import AsyncChannels

final class AsyncTest: XCTestCase {
    // MARK: Utils
    
    func sleep(for time: Duration) -> Channel<Bool> {
       let signal = Channel<Bool>()
       Task {
           try? await Task.sleep(for: time)
           await signal <- true
       }
       return signal
    }
    
    func failAfter(duration: Duration) -> Channel<Bool> {
        let stop = Channel<Bool>()
        Task {
            await select {
                rx(stop)
                rx(sleep(for: duration)) {
                    XCTFail("Test timed out")
                    exit(1)
                }
            }
        }
        return stop
    }
    
    func assertChanRx<T: Equatable>(_ channel: Channel<T>, _ expecting: T) async {
        guard let v = await <-channel else {
            XCTFail()
            return
        }
        XCTAssertEqual(v, expecting)
    }
    
    var stopTimeout: Channel<Bool>?
    
    override func setUp() async throws {
        try await super.setUp()
        stopTimeout = failAfter(duration: .seconds(5))
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        await stopTimeout? <- true
    }
    
    // MARK: Tests
    
    func testUnbuffered() async {
        
        let a = Channel<Int>()
        let b = Channel<Int>()
        
        Task {
            await <-a
            await b <- 0
        }
        await a <- 0
        await <-b
    }
    
    func testCloseNotify() async {
        let a = Channel<Bool>()
        let done = Channel<Bool>()

        Task {
            await <-a
            await done <- true
        }
        Task {
            await <-a
            await done <- true
        }
        Task {
            await <-a
            await done <- true
        }

        a.close()

        await <-done
        await <-done
        await <-done
    }
    
    func testLoopChan() async {
        let a = Channel<Bool>(capacity: 10)
        let done = Channel<Int>()

        Task {
            var count = 0
            for await _ in a {
                count += 1
            }
            await done <- count
        }

        await a <- true
        await a <- true
        await a <- true
        a.close()
        
        let count = await <-done

        XCTAssertEqual(count, 3)
    }
    
    func testCloseChan() async {
        let a = Channel<Int>(capacity: 10)

        Task {
            for _ in (0..<10) {
                await a <- 1
            }
            
            a.close()
        }

        let count = await a.reduce(0) { $0 + $1 }
        XCTAssertEqual(10, count)
    }
    
    func testCloseEmpty() async {
        let a = Channel<String>()
        let done = Channel<Bool>()

        Task {
            await <-a
            await done <- true
        }
        
        a.close()
        await <-done
    }
    
    
    func testSimpleSelect() async {
        let c = Channel<String>()
        let d = Channel<String>()
        let result = Channel<String>(capacity: 2)
        
        Task {
            await c <- "foo"
            await d <- "bar"
        }
        
        await select {
            rx(d) { await result <- $0! }
            rx(c) { await result <- $0! }
        }
        
        await select {
            rx(d) { await result <- $0! }
            rx(c) { await result <- $0! }
        }
        result.close()
        
        let r = await result.reduce(into: []) { $0.append($1) }
        XCTAssertEqual(["foo", "bar"].sorted(), r.sorted())
    }
    
    func testBufferSelect() async {
        let c = Channel<String>(capacity: 3)
        let d = Channel<String>(capacity: 3)
        let result = Channel<String>(capacity: 6)

        await c <- "foo"
        await c <- "foo"
        await c <- "foo"
        await d <- "bar"
        await d <- "bar"
        await d <- "bar"

        for _ in (0..<6) {
            await select {
                rx(d) { await result <- $0! }
                rx(c) { await result <- $0! }
            }
        }
        result.close()
        
        let r = await result.reduce(into: []) { $0.append($1) }
        XCTAssertEqual(["foo", "foo", "foo", "bar", "bar", "bar"].sorted(), r.sorted())
    }
    
    func testSelectDefault() async {

        let c = Channel<String>(capacity: 3)
        let d = Channel<String>(capacity: 3)
        let validate = Channel<Bool>()

        Task {
           await c <- "foo"
        }

        var cCall = 0

        let drain: () async -> Void = {
            await select {
                rx(d) {
                    XCTFail()
                }
                rx(c) {
                    cCall += 1
                }
                none {
                    await validate <- true
                }
            }
        }

        Task { await drain() }
        Task { await drain() }

        await assertChanRx(validate, true)
        XCTAssertEqual(cCall, 1)
    }
    
    func testNonBlockingRead() async {

        let c = Channel<Bool>(capacity: 1)
        await c <- true
        let result = Channel<Bool>()

        Task {
            await select {
                rx(c) { await result <- true }
                none { XCTFail() }
            }

            await select {
                rx(c) { XCTFail() }
                none { await result <- true  }
            }
        }
        await <-result
        await <-result
    }
    
    func testManyToOne() async {
        let a = Channel<Int>()
        let b = Channel<Int>()
        let c = Channel<Int>()
        let done1 = Channel<Bool>()
        let total = 10000

        Task {
            for _ in (0...total) {
                await a <- 1
            }
        }

        Task {
            for _ in (0...total) {
                await b <- 1
            }
        }

        Task {
            var done = false
            while !done {
                await select {
                    rx(a)     { await c <- $0! }
                    rx(b)     { await c <- $0! }
                    rx(done1) { done = true }
                }
            }
        }

        var done = false
        var count = 0
        while !done {
            await select {
                rx(c) {
                    count += 1
                    if count >= 2 * total {
                        done = true
                    }
                }
            }

        }

        XCTAssertEqual(count, 2 * total)
    }
    
    func testOutOfOrder() async {
        let a = Channel<String>(capacity: 10)
        let b = Channel<String>(capacity: 10)
        let c = Channel<String>(capacity: 10)
        let d = Channel<String>(capacity: 10)

        for _ in (0..<10) {
            await a <- "a"
            await b <- "b"
            await c <- "c"
            await d <- "d"
        }

        var count = 0
        var done = false
        while !done {
            await select {
                rx(a) { count += 1 }
                rx(b) { count += 1 }
                rx(c) { count += 1 }
                rx(d) { count += 1 }
                none {
                    done = true
                }
            }
            
        }
        XCTAssertEqual(40, count)
    }
    
    func testTx() async {
        let a = Channel<String>(capacity: 10)
        let b = Channel<String>(capacity: 10)

        for _ in (0..<10) {
            await a <- "a"
        }

        for _ in (0..<20) {
            await select {
                rx(a)
                tx(b, "b")
                none {
                    XCTFail()
                }
            }
        }

        var countB = 0
        var done = false
        while !done {
            await select {
                rx(b) {
                    countB += 1
                    XCTAssertEqual($0, "b")
                }
                none {
                    done = true
                }
            }
        }

        XCTAssertEqual(10, countB)
    }
    
    func testTxHandler() async {
        let a = Channel<String>(capacity: 1)
        let testChan = Channel<Bool>(capacity: 1)
        
        await select {
            tx(a, "b") {
                await testChan <- true
            }
            none {
                XCTFail()
            }
        }
        await assertChanRx(testChan, true)
    }
    
    func testCloseSelect() async {
        let a = Channel<String>(capacity: 10)
        let done = Channel<Bool>()

        Task {
            await select {
                rx(a) { val in
                    XCTAssertNil(val)
                }
            }
            await done <- true
        }

        
        a.close()
        await <-done
    }
    
    func testReadClose() async {
        let a = Channel<Bool>()
        a.close()
        await <-a
        await <-a
        await <-a
    }
    
    func testCloseForeverRead() async {
        let a = Channel<Bool>()

        Task {
            while true {
                await <-a
            }
        }
        a.close()
    }
    
    class SomeData {
        let name: String
        let age: Int
        
        init(name: String, age: Int) {
            self.name = name
            self.age = age
        }
    }
    
    func testStructSend() async {
        
        let c = Channel<SomeData>()
        
        Task {
            await c <- SomeData(name: "foo", age: 21)
        }
        
        print((await <-c)!.name)
        
        let b = Channel<SomeData>(capacity: 10)
        
        Task {
            await b <- SomeData(name: "bar", age: 21)
            await b <- SomeData(name: "bar", age: 21)
            await b <- SomeData(name: "bar", age: 21)
            b.close()
        }
        
        var count = 0
        for await name in b.map({ $0.name }) {
            XCTAssertEqual(name, "bar")
            count += 1
        }
        XCTAssertEqual(count, 3)
    }
    
    func testBlockWhenFull() async {

        let c = Channel<Bool>(capacity: 100)
        let blocked = Channel<Bool>()

        Task {
            var done = false
            while !done {
                await select {
                    tx(c, true)
                    none {
                        done = true
                    }
                }
            }
            await blocked <- true
            c.close()
        }
        
        await <-blocked
        
        var sum = 0
        for await _ in c {
            sum += 1
        }
        
        XCTAssertEqual(sum, 100)
    }
    
    func testBlockWhenEmpty() async {
        

        let c = Channel<Bool>(capacity: 100)
        let full = Channel<Bool>()

        Task {
            for _ in (0..<100) {
                await c <- true
            }
            await full <- true
        }
        await  <-full
        
        var done = false
        var sum = 0
        while !done {
            await select {
                rx(c) {
                    sum += 1
                }
                none {
                    done = true
                }
            }
        }
        
        XCTAssertEqual(sum, 100)
    }
}
