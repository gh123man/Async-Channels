import Testing
@testable import AsyncChannels

func assertChanRx<T: Equatable>(_ channel: Channel<T>, _ expecting: T) async {
    guard let v = await <-channel else {
        Issue.record()
        return
    }
    #expect(v == expecting)
}

let numStress = 10000

// Run the tests a number of times to shake out any concurrency issues. 
func stress(_ n: Int = numStress,_ test: () async throws -> Void) async {
    for _ in 0..<n {
        try! await test()
    }
}

@Suite(.timeLimit(.minutes(1)))
final class BehaviorTests {
    
    
    // MARK: Tests
    
    @Test func unbuffered() async {
        await stress {
            let a = Channel<Int>()
            let b = Channel<Int>()
            
            let task = Task {
                await <-a
                await b <- 0
            }
            await a <- 0
            await <-b
            await task.value
        }
    }
    
    @Test func unbufferedPublicSendRec() async {
        await stress {
            let a = Channel<Int>()
            let b = Channel<Int>()
            
            let task = Task {
                await _ = a.receive()
                await b.send(0)
            }
            await a.send(0)
            await _ = b.receive()
            await task.value
        }
    }
    
    @Test func closeNotify() async {
        await stress {
            let a = Channel<Bool>()
            let done = Channel<Bool>()
            
            async let t1: () = Task {
                await <-a
                await done <- true
            }.value
            async let t2: () = Task {
                await <-a
                await done <- true
            }.value
            async let t3: () = Task {
                await <-a
                await done <- true
            }.value
            
            a.close()
            
            await <-done
            await <-done
            await <-done
            _ = await [t1, t2, t3]
        }
    }
    
    @Test func bufferOrdering() async {
        await stress {
            let a = Channel<Int>(capacity: 2)
            let resume = Channel<Bool>()
            
            let task = Task {
                await a <- 1
                await a <- 2
                await resume <- true
                await a <- 3
            }
            await <-resume
            
            await assertChanRx(a, 1)
            await assertChanRx(a, 2)
            await assertChanRx(a, 3)
            await task.value
        }
    }
    
    @Test func loopChan() async {
        await stress {
            let a = Channel<Bool>(capacity: 10)
            let done = Channel<Int>()
            
            let task = Task {
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
            await task.value
            
            #expect(count == 3)
        }
    }
    
    @Test func closeChan() async {
        await stress {
            let a = Channel<Int>(capacity: 10)
            
            let task = Task {
                for _ in (0..<10) {
                    await a <- 1
                }
                
                a.close()
            }
            await task.value
            
            let count = await a.reduce(0) { $0 + $1 }
            #expect(10 == count)
        }
    }
    
    @Test func closeChanThrowing() async {
        await stress {
            let a = ThrowingChannel<Int>(capacity: 10)
            
            try await Task {
                for _ in (0..<10) {
                    try await a <- 1
                }
                
                a.close()
            }.value
            
            do {
                try await a <- 1
            } catch ChannelError.closed {
            } catch {
                Issue.record()
            }
            
            let count = await a.reduce(0) { $0 + $1 }
            #expect(10 == count)
        }
    }
    
    @Test func closeEmpty() async {
        await stress {
            let a = Channel<String>()
            let done = Channel<Bool>()
            
            let task = Task {
                await <-a
                await done <- true
            }
            
            a.close()
            await <-done
            await task.value
        }
    }
    
    
    @Test func simpleSelect() async {
        await stress {
            let c = Channel<String>()
            let d = Channel<String>()
            let result = Channel<String>(capacity: 2)
            
            let task = Task {
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
            await task.value
            result.close()
            
            let r = await result.reduce(into: []) { $0.append($1) }
            #expect(["foo", "bar"].sorted() == r.sorted())
        }
    }
        
    @Test func dynamicSelect() async {
        await stress {
            let a = Channel<String>()
            let b = Channel<String>()
            let result = Channel<String>(capacity: 2)
            
            let task = Task {
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
            await task.value
            result.close()
            
            let r = await result.reduce(into: []) { $0.append($1) }
            #expect(["foo", "bar"].sorted() == r.sorted())
        }
    }
    
    @Test func dynamicVariadicSelect() async {
        await stress {
            let a = Channel<String>()
            let b = Channel<String>()
            let result = Channel<String>(capacity: 2)
            
            let task = Task {
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
            await task.value
            result.close()
            
            let r = await result.reduce(into: []) { $0.append($1) }
            #expect(["foo", "bar"].sorted() == r.sorted())
        }
    }
    
    @Test func optionalSomeSelect() async {
        await stress {
            let a = Channel<String>()
            let result = Channel<String>(capacity: 1)
            
            let task = Task {
                await a <- "foo"
            }
            
            await select {
                if true {
                    receive(a) { await result <- $0! }
                }
            }
            await task.value
            
            result.close()
            
            await assertChanRx(result, "foo")
        }
    }
    
    @Test func optionalNoneSelect() async throws {
        await stress {
            let a = Channel<String>()
            let done = Channel<String>()
            
            let task1 = Task {
                await a <- "foo"
            }
            
            let task2 = Task {
                await select {
                    if false {
                        receive(a) { Issue.record() }
                    }
                    none {
                        await done <- "done"
                    }
                }
            }
            
            await <-done
            await task2.value
            await <-a
            await task1.value
        }
    }
    
    @Test func eitherIfSelect() async {
        await stress {
            let a = Channel<String>()
            let b = Channel<String>()
            let result = Channel<String>(capacity: 1)
            
            let taska = Task {
                await a <- "foo"
            }
            
            let taskb = Task {
                await b <- "bar"
            }
            
            await select {
                if false {
                    receive(a) { await result <- $0! }
                } else {
                    receive(b) { await result <- $0! }
                }
            }
            
            result.close()
            
            await assertChanRx(result, "bar")
            await <-a
            await taska.value
            await taskb.value
        }
    }
    
    @Test func eitherSwitchSelect() async {
        await stress {
            let a = Channel<String>()
            let b = Channel<String>()
            let c = Channel<String>()
            let result = Channel<String>(capacity: 2)
            let x = 0
            
            async let ta: () = Task {
                await a <- "foo"
            }.value
            async let tb: () = Task {
                await b <- "bar"
            }.value
            async let tc: () = Task {
                await c <- "baz"
            }.value
            
            await select {
                switch x {
                case 0:
                    receive(a) { await result <- $0! }
                case 1:
                    receive(b) { await result <- $0! }
                default:
                    receive(c) { await result <- $0! }
                }
            }
            
            result.close()
            
            await assertChanRx(result, "foo")
            await <-b
            await <-c
            _ = await [ta, tb, tc]
        }
    }

    @Test func bufferSelect() async {
        await stress {
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
                    any(d, c) {
                        receive($0) { await result <- $0! }
                    }
                }
            }
            result.close()
            
            let r = await result.reduce(into: []) { $0.append($1) }
            #expect(["foo", "foo", "foo", "bar", "bar", "bar"].sorted() == r.sorted())
        }
    }
    
    @Test func selectDefault() async {
        await stress {
            let c = Channel<String>(capacity: 3)
            let d = Channel<String>(capacity: 3)
            let validate = Channel<Bool>(capacity: 1)
            let resume = Channel<Bool>()
            
            let task = Task {
                await c <- "foo"
                await resume <- true
            }
            
            await <-resume
            await task.value
            
            var cCall = 0
            
            let drain: () async -> Void = {
                await select {
                    receive(d) {
                        Issue.record()
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
            #expect(cCall == 1)
        }
    }
    
    @Test func nonBlockingRead() async {
        await stress {
            let c = Channel<Bool>(capacity: 1)
            await c <- true
            let result = Channel<Bool>()
            
            let task = Task {
                await select {
                    receive(c) { await result <- true }
                    none { Issue.record() }
                }
                
                await select {
                    receive(c) { Issue.record() }
                    none { await result <- true  }
                }
            }
            await <-result
            await <-result
            await task.value
            c.close()
            result.close()
        }
    }
    
    @Test func manyToOne() async {
        await stress(100) {
            let a = Channel<Int>()
            let b = Channel<Int>()
            let c = Channel<Int>()
            let total = 1000
            async let tg: () = withTaskGroup(of: Void.self) { group in
                
                group.addTask {
                    for _ in (0..<total) {
                        await a <- 1
                    }
                    a.close()
                }
                
                group.addTask {
                    for _ in (0..<total) {
                        await b <- 1
                    }
                    b.close()
                }
                
                group.addTask {
                    var done = false
                    var count = 0
                    while !done {
                        await select {
                            any(a, b) {
                                receive($0) {
                                    if let v = $0 {
                                        count += 1
                                        await c <- v
                                    }
                                    if count >= 2 * total {
                                        done = true
                                    }
                                }
                            }
                        }
                    }
                    c.close()
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
            
            #expect(count == 2 * total)
            await tg
        }
    }
    
    @Test func outOfOrder() async {
        await stress {
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
                    any(a, b, c, d) {
                        receive($0) { count += 1 }
                    }
                    none {
                        done = true
                    }
                }
                
            }
            #expect(40 == count)
        }
    }
    
    @Test func sendTest() async {
        await stress {
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
                        Issue.record()
                    }
                }
            }
            
            var countB = 0
            var done = false
            while !done {
                await select {
                    receive(b) {
                        countB += 1
                        #expect($0 == "b")
                    }
                    none {
                        done = true
                    }
                }
            }
            
            #expect(10 == countB)
        }
    }
    
    @Test func sendHandler() async {
        await stress {
            let a = Channel<String>(capacity: 1)
            let testChan = Channel<Bool>(capacity: 1)
            
            await select {
                send("b", to: a) {
                    await testChan <- true
                }
                none {
                    Issue.record()
                }
            }
            await assertChanRx(testChan, true)
        }
    }
    
    @Test func closeSelect() async {
        await stress {
            let a = Channel<String>(capacity: 10)
            
            let task = Task {
                await select {
                    receive(a) { val in
                        #expect(val == nil)
                    }
                }
            }
            
            a.close()
            await task.value
        }
    }
    
    @Test func readClose() async {
        await stress {
            let a = Channel<Bool>()
            a.close()
            await <-a
            await <-a
            await <-a
        }
    }
    
    @Test func closeForeverRead() async {
        await stress {
            let a = Channel<Bool>()
            
            let task = Task {
                for await _ in a { }
            }
            a.close()
            await task.value
        }
    }
    
    final class SomeData: Sendable {
        let name: String
        let age: Int
        
        init(name: String, age: Int) {
            self.name = name
            self.age = age
        }
    }
    
    @Test func structSend() async {
        await stress {
            let b = Channel<SomeData>(capacity: 10)
            
            let task = Task {
                await b <- SomeData(name: "bar", age: 21)
                await b <- SomeData(name: "bar", age: 21)
                await b <- SomeData(name: "bar", age: 21)
                b.close()
            }
            
            var count = 0
            for await name in b.map({ $0.name }) {
                #expect(name == "bar")
                count += 1
            }
            #expect(count == 3)
            await task.value
        }
    }

    @Test func blockWhenFull() async {
        await stress(100) {
            let c = Channel<Bool>(capacity: 100)
            
            let task = Task {
                var done = false
                while !done {
                    await select {
                        send(true, to: c)
                        none {
                            done = true
                        }
                    }
                }
                c.close()
            }
            
            await task.value
            
            var sum = 0
            for await _ in c {
                sum += 1
            }
            
            #expect(sum == 100)
        }
    }
    
    @Test func blockWhenEmpty() async {
        await stress(100) {
            let c = Channel<Bool>(capacity: 100)
            for _ in (0..<100) {
                await c <- true
            }
            
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
            
            #expect(sum == 100)
        }
    }
    
    @Test func Multiplex() async {
        await stress(100) {
            let channels = (0..<100).map { _ in Channel<Bool>() }
            let collected = Channel<Bool>()
            
            // 100 tasks writing to 100 channels
            for c in channels {
                Task {
                    await c <- true
                }
            }
            
            // 1 task recieving from 100 channels and writing the results to 1 channel.
            let task = Task {
                for _ in 0..<100 {
                    await select {
                        any(channels) { channel in
                            receive(channel) { val in
                                await collected <- val!
                            }
                        }
                    }
                }
                collected.close()
            }
            
            var sum = 0
            for await _ in collected {
                sum += 1
            }
            await task.value
            
            #expect(100 == sum)
        }
    }
    
    @Test func StopSig() async {
        await stress {
            
            enum StopSignal {
                case error
                case done
            }
            
            let data = Channel<String>()
            let signal = Channel<StopSignal>()
            
            
            let task = Task {
                var done = false
                while !done {
                    await select {
                        receive(data) { _ = $0! }
                        receive(signal) {
                            switch $0! {
                            case .error:
                                done = true
                            case .done:
                                done = true
                            }
                        }
                    }
                }
            }
            
            await data <- "foo"
            await data <- "bar"
            await signal <- .done
            await task.value
        }
    }
    
    @Test func SyncSendReceive() {
        let data = Channel<String>(capacity: 3)
        
        #expect(data.syncSend("1"))
        #expect(data.syncSend("2"))
        #expect(data.syncSend("3"))
        #expect(!data.syncSend("4"))
        
        #expect(data.syncReceive() == "1")
        #expect(data.syncReceive() == "2")
        #expect(data.syncReceive() == "3")
        #expect(data.syncReceive() == nil)
        #expect(data.syncReceive() == nil)
        
        #expect(data.syncSend("4"))
        #expect(data.syncReceive() == "4")
        
        data.close()
        #expect(data.syncReceive() == nil)
    }
    
    @Test func blockingReceive() async {
        let c = Channel<Void>()
        let counter = Channel<Int>()
        
        let task = Task {
            await c <- ()
            await counter <- 1
            
            await c <- ()
            await counter <- 2
            
            await c <- ()
            await counter <- 3
        }
        
        #expect(counter.syncReceive() == nil)
        c.blockingReceive()
        #expect(counter.blockingReceive() == 1)
        #expect(counter.syncReceive() == nil)
        c.blockingReceive()
        #expect(counter.blockingReceive() == 2)
        #expect(counter.syncReceive() == nil)
        c.blockingReceive()
        #expect(counter.blockingReceive() == 3)
        #expect(counter.syncReceive() == nil)
        await task.value
    }
    
    @Test func blockingSend() async {
        let counter = Channel<Int>()
        let done = Channel<Void>()
        
        let task = Task {
            await assertChanRx(counter, 1)
            await assertChanRx(counter, 2)
            await assertChanRx(counter, 3)
            await done <- ()
        }
        
        counter.blockingSend(1)
        counter.blockingSend(2)
        counter.blockingSend(3)
        #expect(done.blockingReceive()! == ())
        await task.value
    }
}
