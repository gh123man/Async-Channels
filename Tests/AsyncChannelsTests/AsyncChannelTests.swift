import XCTest
@testable import AsyncChannels

final class AsyncTest: XCTestCase {
    
    func sleep(for time: Duration) -> Channel<Bool> {
       let signal = Channel<Bool>(capacity: 1)
       Task {
           try? await Task.sleep(for: time)
           await signal <- true
       }
       return signal
    }
    
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSimple() async {
        
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
            print("wait 1")
            await <-a
            await done <- true
        }
        Task {
            print("wait 2")
            await <-a
            await done <- true
        }
        Task {
            print("wait 3")
            await <-a
            await done <- true
        }

        await <-sleep(for: .milliseconds(100))
        await a.close()


        await <-done
        await <-done
        await <-done
        print("Closed")
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
        await a.close()
        
        let count = await <-done

        XCTAssertEqual(count, 3)
    }
    
    func testCloseChan() async {
        let a = Channel<String>(capacity: 10)

        Task {
            for _ in (0..<10) {
                await a <- "a"
            }
            
            await a.close()
        }

        var count = 0
        while await <-a != nil {
            count += 1
        }
        XCTAssertEqual(10, count)
    }
    
    func testCloseEmpty() async {
        let a = Channel<String>()
        let done = Channel<Bool>()

        Task {
            await <-a
            await done <- true
        }
        
        await a.close()
        await <-done
    }
    
    func testBig() async {

        let startTime = CFAbsoluteTimeGetCurrent()

        let a = Channel<Int>()
        var sum = 0

        for _ in (0...100) {
            Task {
                for _ in (0...10000) {
                    await a <- 1
                }
            }
        }

        while sum < 1_000_000 {
            sum += (await <-a)!
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Time elapsed: \(timeElapsed)")
    }
    
    
    func testSimpleSelect() async {
        
        let c = Channel<String>(capacity: 0)
        let d = Channel<String>(capacity: 0)
        
        Task {
            await c <- "foo"
            await d <- "bar"
            
        }
        
        await select {
            rx(d) { print($0!) }
            rx(c) { print($0!) }
        }
        
        await select {
            rx(d) { print($0!) }
            rx(c) { print($0!) }
        }
    }
    
    func testBufferSelect() async {
        let c = Channel<String>(capacity: 3)
        let d = Channel<String>(capacity: 3)

        await c <- "foo"
        await c <- "foo"
        await c <- "foo"
        await d <- "bar"
        await d <- "bar"
        await d <- "bar"

        for _ in (0..<6) {
            await select {
                rx(d) { print($0!) }
                rx(c) { print($0!) }
            }
        }
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
                    print($0!)
                    cCall += 1
                }
                none {
                    print("yay")
                    await validate <- true
                }
            }
        }

        Task { await drain() }
        Task { await drain() }

        let result = await <-validate
        XCTAssertTrue(result!)
        XCTAssertEqual(cCall, 1)
    }
    
    func testNonBlockingRead() async {

        let c = Channel<Bool>(capacity: 1)
        await c <- true

        Task {
            await select {
                rx(c) { print("c") }
                none { XCTFail() }
            }

            await select {
                rx(c) { XCTFail() }
                none { print("none") }
            }
        }
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
                rx(a) { print($0!) }
                rx(b) { print($0!) }
                rx(c) { print($0!) }
                rx(d) { print($0!) }
                none {
                    done = true
                }
            }
            count += 1
        }
        XCTAssertEqual(41, count)
    }
    
    func testTx() async {
        let a = Channel<String>(capacity: 10)
        let b = Channel<String>(capacity: 10)

        for _ in (0..<10) {
            await a <- "a"
        }

        for _ in (0..<20) {
            await select {
                rx(a) { print($0!) }
                tx(b, "b")
                none {
                    print("NONE")
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
                    print("Done")
                }
            }
        }

        XCTAssertEqual(10, countB)
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

        
        await a.close()
        await <-done
    }
    
    func testReadClose() async {
        let a = Channel<Bool>()
        await a.close()
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
        await a.close()
        print("Closed")
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
            await c.close()
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
    
    func testDrain() async {
        let c = Channel<String>(capacity: 100)
        await c <- "a"
        await c <- "b"
        await c <- "c"
        
        await c.drain()
        
        await select {
            rx(c) {
                XCTFail()
            }
            none { }
        }
    }
    
    func testInto() async {
        let c = Channel<Int>()
        let b = Channel<String>()
        Task {
            await c <- 1
            await c <- 2
            await c <- 3
            await c.close()
        }
        
        Task {
            for await v in b {
                print(v.self)
            }
        }
        
        await c.map { "str: \($0)" }.into(b)
        
        print("Done")
        
    }
    
}

