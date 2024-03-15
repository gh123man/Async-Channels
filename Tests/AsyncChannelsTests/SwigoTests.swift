//import XCTest
//@testable import AsyncChannels
//
//
//func sleep(seconds: TimeInterval) -> Chan<Bool> {
//   let signal = Chan<Bool>(buffer: 1)
//   go {
//       Thread.sleep(forTimeInterval: seconds)
//       signal <- true
//   }
//   return signal
//}
//
//final class AsyncChannelsTests: XCTestCase {
//    func failAfter(seconds: TimeInterval) -> Chan<Bool> {
//        let stop = Chan<Bool>(buffer: 1)
//        go {
//            select {
//                rx(stop)
//                rx(sleep(seconds: seconds)) {
//                    XCTFail("Test timed out")
//                    exit(1)
//                }
//            }
//        }
//        return stop
//    }
//    
//    var stopTimeout: Chan<Bool>?
//    override func setUp() {
//        super.setUp()
//        stopTimeout = failAfter(seconds: 5)
//    }
//    
//    override func tearDown() {
//        super.tearDown()
//        stopTimeout? <- true
//    }
//    
//    func testSimple() {
//        
//        let a = Chan<Int>()
//        let b = Chan<Int>()
//        
//        go {
//            <-a
//            b <- 0
//        }
//        a <- 0
//        <-b
//    }
//    
//    func testSimpleSelect() {
//        let c = OpenChan<String>(buffer: 0)
//        let d = OpenChan<String>(buffer: 0)
//
//        go {
//            c <- "foo"
//            d <- "bar"
//        }
//
//        select {
//            rx(d) { print($0) }
//            rx(c) { print($0) }
//        }
//
//        select {
//            rx(d) { print($0) }
//            rx(c) { print($0) }
//        }
//    }
//    
//    func testBufferSelect() {
//        let c = OpenChan<String>(buffer: 3)
//        let d = OpenChan<String>(buffer: 3)
//
//        c <- "foo"
//        c <- "foo"
//        c <- "foo"
//        d <- "bar"
//        d <- "bar"
//        d <- "bar"
//
//        for _ in (0..<6) {
//            select {
//                rx(d) { print($0) }
//                rx(c) { print($0) }
//            }
//        }
//    }
//    
//    func testSelectDefault() {
//        
//        let c = OpenChan<String>(buffer: 3)
//        let d = OpenChan<String>(buffer: 3)
//        let validate = OpenChan<Bool>()
//
//        go {
//           c <- "foo"
//        }
//        
//        var cCall = 0
//        
//        let drain = {
//            select {
//                rx(d) {
//                    XCTFail()
//                }
//                rx(c) {
//                    print($0)
//                    cCall += 1
//                }
//                none {
//                    print("yay")
//                    validate <- true
//                }
//            }
//        }
//        
//        go { drain () }
//        go { drain () }
//        
//        XCTAssertTrue(<-validate)
//        XCTAssertEqual(cCall, 1)
//    }
//    
//    func testNonBlockingRead() {
//
//        let c = OpenChan<Bool>()
//        
//        go {
//            select {
//                rx(c) { print("c") }
//                none { XCTFail() }
//            }
//            
//            select {
//                rx(c) { XCTFail() }
//                none { print("none") }
//            }
//        }
//        
//        c <- true
//    }
//    
//    func testBig() {
//        
//        let startTime = CFAbsoluteTimeGetCurrent()
//        
//        let a = OpenChan<Int>()
//        var sum = 0
//        
//        
//        for _ in (0...100) {
//            go {
//                for _ in (0...10000) {
//                    a <- 1
//                }
//            }
//        }
//        
//        while sum < 1000000 {
//            sum += <-a
//        }
//        
//        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
//            print("Time elapsed: \(timeElapsed)")
//    }
//    
//    func testManyToOne() {
//        let a = OpenChan<Int>()
//        let b = OpenChan<Int>()
//        let c = OpenChan<Int>()
//        let done1 = OpenChan<Bool>()
//        let total = 10000
//        
//        go {
//            for _ in (0...total) {
//                a <- 1
//            }
//        }
//        
//        go {
//            for _ in (0...total) {
//                b <- 1
//            }
//        }
//        
//        go {
//            var done = false
//            while !done {
//                select {
//                    rx(a)     { c <- $0 }
//                    rx(b)     { c <- $0 }
//                    rx(done1) { done = true }
//                }
//            }
//        }
//        
//        var done = false
//        var count = 0
//        while !done {
//            select {
//                rx(c) {
//                    count += 1
//                    if count >= 2 * total {
//                        done = true
//                    }
//                }
//            }
//            
//        }
//        
//        XCTAssertEqual(count, 2 * total)
//        
//    }
//    
//    func testOutOfOrder() {
//        let a = OpenChan<String>(buffer: 10)
//        let b = OpenChan<String>(buffer: 10)
//        let c = OpenChan<String>(buffer: 10)
//        let d = OpenChan<String>(buffer: 10)
//
//        for _ in (0..<10) {
//            a <- "a"
//            b <- "b"
//            c <- "c"
//            d <- "d"
//        }
//        
//        var count = 0
//        var done = false
//        while !done {
//            select {
//                rx(a) { print($0) }
//                rx(b) { print($0) }
//                rx(c) { print($0) }
//                rx(d) { print($0) }
//                none {
//                    done = true
//                }
//            }
//            count += 1
//        }
//        XCTAssertEqual(41, count)
//    }
//    
//    func testTx() {
//        let a = OpenChan<String>(buffer: 10)
//        let b = OpenChan<String>(buffer: 10)
//        
//        for _ in (0..<10) {
//            a <- "a"
//        }
//        
//        for _ in (0..<20) {
//            select {
//                rx(a) { print($0) }
//                tx(b, "b")
//                none {
//                    print("NONE")
//                }
//            }
//        }
//        
//        var countB = 0
//        var done = false
//        while !done {
//            select {
//                rx(b) {
//                    countB += 1
//                    XCTAssertEqual($0, "b")
//                }
//                none {
//                    done = true
//                    print("Done")
//                }
//            }
//        }
//        
//        XCTAssertEqual(10, countB)
//    }
//    
//    func testCloseChan() {
//        let a = Chan<String>(buffer: 10)
//        
//        go {
//            for _ in (0..<10) {
//                a <- "a"
//            }
//            a.close()
//        }
//        
//        var count = 0
//        while <-a != nil {
//            count += 1
//        }
//        XCTAssertEqual(10, count)
//    }
//    
//    func testCloseSelect() {
//        let a = Chan<String>(buffer: 10)
//        let done = OpenChan<Bool>()
//        
//        go {
//            select {
//                rx(a) { val in
//                    XCTAssertNil(val)
//                }
//            }
//            done <- true
//        }
//        
//        a.close()
//        <-done
//    }
//    
//    func testLoopChan() {
//        let a = Chan<Bool>(buffer: 10)
//        let done = OpenChan<Bool>()
//        var count = 0
//        
//        go {
//            for _ in a {
//                count += 1
//            }
//            done <- true
//        }
//        
//        a <- true
//        a <- true
//        a <- true
//        a.close()
//        <-done
//        
//        XCTAssertEqual(count, 3)
//    }
//    
//    func testCloseNotify() {
//        let a = Chan<Bool>()
//        let done = Chan<Bool>()
//        
//        go {
//            print("wait 1")
//            <-a
//            done <- true
//        }
//        go {
//            print("wait 2")
//            <-a
//            done <- true
//        }
//        go {
//            print("wait 3")
//            <-a
//            done <- true
//        }
//
//        <-sleep(seconds: 0.1)
//        a.close()
//        
//        
//        <-done
//        <-done
//        <-done
//        print("Closed")
//    }
//    
//    func testReadClose() {
//        let a = Chan<Bool>()
//        a.close()
//        <-a
//        <-a
//        <-a
//    }
//    
//    func testCloseForeverRead() {
//        let a = Chan<Bool>()
//        
//        go {
//            while true {
//                <-a
//            }
//        }
//        a.close()
//        print("Closed")
//    }
//}
