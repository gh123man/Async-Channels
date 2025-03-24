import Testing
@testable import AsyncChannels

// Tests to ensure the code in the readme actually works
@Suite(.timeLimit(.minutes(1)))
final class ReadmeTests {
    
    @Test func simpleExample() async {
        let stringChannel = Channel<String>(capacity: 3)

        // Spawn a task to print the strings.
        let task = Task {
            // Task will wait until the channel is closed.
            for await message in stringChannel {
                print(message)
            }
        }

        // Send some strings
        await stringChannel <- "Swift"
        await stringChannel <- "❤️"
        await stringChannel <- "Channels"

        // Close the channel, allowing the task to complete.
        stringChannel.close()
        await task.value
    }
    
    @Test func unbuffered() async {
        let msg = Channel<String>()

        Task {
            // Send a value. Send will suspend until the channel is read.
            await msg <- "foo"
        }

        Task {
            // Receive a value. Receive will suspend until a value is ready
            let foo = await <-msg
            print(foo!)
        }
    }
    
    @Test func buffered() async {
        // Create a buffered channel that can hold 2 items
        let msg = Channel<String>(capacity: 2)

        // Writing to a buffered channel will not suspend until the channel is full
        await msg <- "foo"
        await msg <- "bar"

        // Messages are received in the order they are sent
        print((await <-msg)!) // foo
        print((await <-msg)!) // bar

        // The msg channel is now empty.
    }
    
    @Test func closeChannel() async {
        let a = Channel<String>()

        let task = Task {
            // a will suspend because there is nothing to receive
            await <-a
        }

        // Close will send `nil` causing a to resume in the task above
        a.close()
        // Task will resume and complete and return a nil from the received channel.
        _ = await task.value
    }
    
    @Test func selectExample() async {
        
        let c = Channel<String>()
        let d = Channel<String>()
        
        Task {
            await c <- "foo"
            await d <- "bar"
        }
        
        // Will print foo or bar
        await select {
            receive(d) { print($0!) }
            receive(c) { print($0!) }
        }
    }

    @Test func selectExample2() async {
        let a = Channel<String>(capacity: 10)
        let b = Channel<String>(capacity: 10)

        // Fill up channel a
        for _ in (0..<10) {
            await a <- "a"
        }

        for _ in (0..<20) {
            await select {
                // receive from a and print it
                receive(a) { print($0!) }
                // send "b" to b
                send("b", to: b)
                // if both a and b suspend, print "NONE"
                none {
                    print("NONE")
                }
            }
        }
    }
    
    
    @Test func multiplex() async {
        let channels = (0..<100).map { _ in Channel<Bool>() }
        let collected = Channel<Bool>()

        // 100 tasks writing to 100 channels
        for c in channels {
            Task {
                await c <- true
            }
        }

        // 1 task receiving from 100 channels and writing the results to 1 channel.
        Task {
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
    }
    
    @Test func conditionlaCase() async {
        let a = Channel<String>()
        let b = Channel<String>()
        let result = Channel<String>(capacity: 1)

        let task = Task {
            await a <- "foo"
        }

        let enableReceive = true
        await select {
            if enableReceive {
                receive(a) { await result <- $0! }
            }
            send("b", to: b)
        }
        await <-result
        await task.value
    }
    
}
