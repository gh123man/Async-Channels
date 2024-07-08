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
                receive(stop)
                receive(sleep(for: duration)) {
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
    
    
// Aparently this crashes on linux
#if canImport(Darwin)
    // Each test is run 100 times.
    // It's not always easy to validate correct concurrent behavior with asserts. In fact
    // it's easy to miss things that can occor rarely such as race/timing issues. Sometimes
    // when these bugs happen you will get a deadlock or a panic. By running the tests lots
    // of times, we get better validation that these issues do not exist. It also helps
    // catch incorrectly written tests that have race conditions in the way that they are
    // written.
    override func invokeTest() {
        for _ in 0..<100 {
            super.invokeTest()
        }
    }
#endif
    
    
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
    
    func testUnbufferedPublicSendRec() async {
        
        let a = Channel<Int>()
        let b = Channel<Int>()
        
        Task {
            await _ = a.receive()
            await b.send(0)
        }
        await a.send(0)
        await _ = b.receive()
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
    
    func testBufferOrdering() async {
        let a = Channel<Int>(capacity: 2)
        let resume = Channel<Bool>()
        let done = Channel<Bool>()

        Task {
            await a <- 1
            await a <- 2
            await resume <- true
            await a <- 3
            await done <- true
        }
        await <-resume

        await assertChanRx(a, 1)
        await assertChanRx(a, 2)
        await assertChanRx(a, 3)
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
            receive(d) { await result <- $0! }
            receive(c) { await result <- $0! }
        }
        
        await select {
            receive(d) { await result <- $0! }
            receive(c) { await result <- $0! }
        }
        result.close()
        
        let r = await result.reduce(into: []) { $0.append($1) }
        XCTAssertEqual(["foo", "bar"].sorted(), r.sorted())
    }
        
    func testDynamicSelect() async {
        let a = Channel<String>()
        let b = Channel<String>()
        let result = Channel<String>(capacity: 2)
        
        Task {
            await a <- "foo"
            await b <- "bar"
        }
        
        await select {
            any([a, b]) {
                receive($0) { await result <- $0! }
            }
        }
        
        await select {
            any([a, b]) {
                receive($0) { await result <- $0! }
            }
        }
        result.close()
        
        let r = await result.reduce(into: []) { $0.append($1) }
        XCTAssertEqual(["foo", "bar"].sorted(), r.sorted())
    }
    
    func testDynamicVariadicSelect() async {
        let a = Channel<String>()
        let b = Channel<String>()
        let result = Channel<String>(capacity: 2)
        
        Task {
            await a <- "foo"
            await b <- "bar"
        }
        
        await select {
            any(a, b) {
                receive($0) { await result <- $0! }
            }
        }
        
        await select {
            any(a, b) {
                receive($0) { await result <- $0! }
            }
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
                receive(d) { await result <- $0! }
                receive(c) { await result <- $0! }
            }
        }
        result.close()
        
        let r = await result.reduce(into: []) { $0.append($1) }
        XCTAssertEqual(["foo", "foo", "foo", "bar", "bar", "bar"].sorted(), r.sorted())
    }
    
    func testSelectDefault() async {
        let c = Channel<String>(capacity: 3)
        let d = Channel<String>(capacity: 3)
        let validate = Channel<Bool>(capacity: 1)
        let resume = Channel<Bool>()

        Task {
            await c <- "foo"
            await resume <- true
        }
        
        await <-resume

        var cCall = 0

        let drain: () async -> Void = {
            await select {
                receive(d) {
                    XCTFail()
                }
                receive(c) {
                    cCall += 1
                }
                none {
                    await validate <- true
                }
            }
        }

        await drain()
        await drain()

        await assertChanRx(validate, true)
        XCTAssertEqual(cCall, 1)
    }
    
    func testNonBlockingRead() async {

        let c = Channel<Bool>(capacity: 1)
        await c <- true
        let result = Channel<Bool>()

        Task {
            await select {
                receive(c) { await result <- true }
                none { XCTFail() }
            }

            await select {
                receive(c) { XCTFail() }
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
        let total = 1000

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
                    receive(a)     { await c <- $0! }
                    receive(b)     { await c <- $0! }
                    receive(done1) { done = true }
                }
            }
        }

        var done = false
        var count = 0
        while !done {
            await select {
                receive(c) {
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
                receive(a) { count += 1 }
                receive(b) { count += 1 }
                receive(c) { count += 1 }
                receive(d) { count += 1 }
                none {
                    done = true
                }
            }
            
        }
        XCTAssertEqual(40, count)
    }
    
    func testSend() async {
        let a = Channel<String>(capacity: 10)
        let b = Channel<String>(capacity: 10)

        for _ in (0..<10) {
            await a <- "a"
        }

        for _ in (0..<20) {
            await select {
                receive(a)
                send("b", to: b)
                none {
                    XCTFail()
                }
            }
        }

        var countB = 0
        var done = false
        while !done {
            await select {
                receive(b) {
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
    
    func testSendHandler() async {
        let a = Channel<String>(capacity: 1)
        let testChan = Channel<Bool>(capacity: 1)
        
        await select {
            send("b", to: a) {
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
                receive(a) { val in
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
            for await _ in a { }
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
                    send(true, to: c)
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
                receive(c) {
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
