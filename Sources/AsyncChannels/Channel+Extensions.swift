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
