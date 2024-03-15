import Foundation

extension Array {
    mutating func popFirst() -> Element? {
        return count > 0 ? removeFirst() : nil
    }
}
