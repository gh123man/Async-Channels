import Foundation

extension Channel: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = T
    
    public func makeAsyncIterator() -> Channel {
        return self
    }
    
    public func next() async -> T? {
        return await <-self
    }
}

extension Channel {
    func drain() async {
        var done = false
        while !done {
            await select {
                rx(self)
                none {
                    done = true
                }
            }
        }
    }
}

struct ChannelSubscription {
    internal let cancellation = Channel<Bool>()
    
    func cacnel() async {
        await cancellation <- true
    }
    
}

extension AsyncSequence where Element: Sendable {
    func into<T: Sendable>(_ output: Channel<T>) async where T == Element -> ChannelSubscription {
        
        let sub = ChannelSubscription()
        var done = false
        while !done {
            await select {
                rx(self) {
                    await output <- $0
                }
                rx(sub.cancellation) {
                    done = true
                }
            }
        }
        
//        do {
//            for try await value in self {
//                // Assuming your Channel type has a method to send values asynchronously
//                await channel.send(value)
//            }
//        } catch {}
        
        // Assuming your Channel type has a method to mark it as complete
        await channel.close()
    }
}
