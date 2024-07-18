# Async Channels

Performant channels for Swift concurrency.


> Don't communicate by sharing memory; share memory by communicating
> 
> \- Rob Pike

Channels are a typed conduit through which you can send and receive values - usually across threads or in this case, Swift async tasks. This library is modeled after go's channel behaviors. 

If you are familiar with golang and the go ecosystem, you can skip to the [go comparisons section.](/GolangVsSwift.md)

## Example

```swift
let msg = Channel<String>(capacity: 3)
let done = Channel<Bool>()

Task {
    for await message in msg {
        print(message)
    }
    await done <- true
}

await msg <- "Swift"
await msg <- "❤️"
await msg <- "Channels"

msg.close()
await <-done
```

## Benchmarks

### This Library vs go vs [Apple's Async Algorithms channel implementation](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md)
![Swift vs Go](media/vs-async-alg.png)

### This library vs equivalent [go code](/Benchmarks/golang/benchmark_test.go)
![Swift vs Go](media/swift-vs-go.png)

Obviously being as fast as go is a lofty goal that we may never reach, but it's still pretty fast!

*The above results were sampled from the `Int` tests in the detailed benchmark results*

For more detailed results (on a variety of data types) see the [Benchmarks](/Benchmarks/) readme.

## Usage

1. Add `https://github.com/gh123man/Async-Channels` as a Swift package dependency to your project. 
2. `import AsyncChannels` and go!

## Channel Operations


Un-Buffered Channels
```swift
// Create an un-buffered channel
let msg = Channel<String>()

Task {
    // Send a value. Send will suspend until the channel is read. 
    await msg <- "foo" 
}

Task {
    // Receive a value. Receive will suspend until a value is ready
    let foo = await <-msg
}
```

Buffered Channels
```swift
// Create a buffered channel that can hold 2 items
let msg = Channel<String>(capacity: 2)

// Writing to a buffered channel will not suspend until the channel is full
await msg <- "foo" 
await msg <- "bar" 

// Messages are received in the order they are sent
print(await <-msg) // foo
print(await <-msg) // bar

// The msg channel is now empty. 
```

### Closing Channels

A Channel can be closed. In Swift, the channel receive (`<-`) operator returns `T?` because a channel read will return `nil` when the channel is closed. If you try to write to a closed channel, a fatalError will be triggered.

```swift
let a = Channel<String>()
let done = Channel<Bool>()

Task {
    // a will suspend because there is nothing to receive
    await <-a 
    await done <- true
}

// Close will send `nil` causing a to resume in the task above
a.close() 
// done is signaled 
await <-done
```

### Sequence operations 

`Channel` implements `AsyncSequence` so you may write:
```swift
let a = Channel<String>() 

for await message in a {
    print(message)
}
```

The loop will break when the channel is closed. 

## Select

`select` lets a single task wait on multiple channel operations. `select` will suspend until at least one of the cases is ready. If multiple cases are ready it will choose one randomly. 

### Operations

`receive(c)` receive a value, but do nothing with it. 

`receive(c) { v in ... }` receive a value and do something with it. 

`send("foo", to: c)` send a value and do nothing.

`send("foo", to: c) { ... }` run some code if a send is successful. 

`none { ... }` if none of the channel operations were ready, none will execute instead. 

`any(x1, x2, ...) { x in ... }` or `any(seq) { el in ... }` operates on a sequence and is useful for performing the same operations on multiple channels.

### Examples

```swift

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
```

```swift 
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
```

## Wait Group

This library also includes a `WaitGroup` implementation. Wait groups are useful when you want to wait for multiple tasks to finish. 

### Example

```swift
let wg = WaitGroup()
let signal = Channel<Bool>()
let done = Channel<Bool>()

// Task that drains the signal channel
Task {
    for await _ in signal { }
    await done <- true
}

// 100 workers that write to the signal channel
for _ in 0..<100 {
    await wg.add(1)
    Task {
        await signal <- true
        await wg.done()
    }
}
// When all workers are done - signal is drained, so wg will be done.
await wg.wait()

// Closing the signal channel means it's empty, so done is signaled.
signal.close()
await <-done
```

## Advanced Usage
This library also includes some extra features that are made possible by the flexibility of Swift's `resultBuilder`. 

### Examples

Multiplexing `n:1` channels using select `any`
```swift
let channels = (0..<100).map { _ in Channel<Bool>() }
let collected = Channel<Bool>()

// 100 tasks writing to 100 channels
for c in channels {
    Task {
        await c <- true
    }
}

// 1 task recieving from 100 channels and writing the results to 1 channel. 
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
```

Conditional cases
```swift 
let a = Channel<String>()
let b = Channel<String>()

Task {
    await a <- "foo"
}

var enableRecieve = true
await select {
    if enableRecieve {
        receive(a) { await result <- $0! }
    }
    send("b", to: b)
}

```

## Code Samples

See the [Examples](/Examples/) folder for real world usage. 

- [Parallel image converter](/Examples/ImageConverter/Sources/ImageConverter/main.swift) - Saturate the CPU to convert images applying back pressure to the input. 


# Special Thanks

I could not have gotten this far without the help from the folks over at [forums.swift.org](https://forums.swift.org/t/async-channels-for-swift-concurrency/70752) and contributors on github. Big shout-out and thank you to:
- [wadetregaskis](https://forums.swift.org/u/wadetregaskis/summary) for optimizing much of this code and finding the more challenging performance limitations (compiler limitations, locking strategies)
- [vns](https://forums.swift.org/u/vns/summary) for proposing a `LinkedList` backing data structure
- [Kuniwak](https://github.com/Kuniwak) for proposing and adding the select `any` function.
