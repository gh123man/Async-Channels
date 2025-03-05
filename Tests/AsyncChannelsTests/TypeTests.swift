import Testing
@testable import AsyncChannels

@Suite(.timeLimit(.minutes(1)))
final class TypeTests {
    
    
    func assertType<T: Sendable & Equatable>(_ val: T) async {
        let c = Channel<T>(capacity: 1)
        await c <- val
        let r = await <-c
        #expect(r == val)
    }
    
    @Test func allTypes() async {
        // Primitives
        await assertType(42)
        await assertType(3.14)
        await assertType(true)
        await assertType("Hello")

        // Tuples
        await {
            let c = Channel<(Int, String)>(capacity: 1)
            await c <- (1, "test")
            let r = await <-c
            #expect(r! == (1, "test"))
        }()
        
        await {
            let c = Channel<(Float, Bool)>(capacity: 1)
            await c <- (3.14, false)
            let r = await <-c
            #expect(r! == (3.14, false))
        }()
        

        // Arrays
        await assertType([1, 2, 3])
        await assertType(["a", "b", "c"])
        
        // Sets & Dictionaries
        await assertType(Set([1, 2, 3]))
        await assertType(["key": 42, "another": 99])

        // Optionals
        await assertType(Int?.none)
        await assertType(Optional("OptionalValue"))

        // Structs
        struct MyStruct: Equatable, Sendable {
            let a: Int
            let b: String
        }
        await assertType(MyStruct(a: 10, b: "struct"))

        // Enums
        enum MyEnum: Equatable, Sendable {
            case first(Int)
            case second(String)
        }
        await assertType(MyEnum.first(100))
        await assertType(MyEnum.second("enum"))

        // Classes
        final class MyClass: Equatable, Sendable {
            let x: Int
            init(x: Int) { self.x = x }
            static func == (lhs: MyClass, rhs: MyClass) -> Bool { lhs.x == rhs.x }
        }
        await assertType(MyClass(x: 5))

        // Actors
        actor MyActor: Sendable, Equatable {
            static func == (lhs: MyActor, rhs: MyActor) -> Bool {
                lhs.value == rhs.value
            }
            
            let value: Int
            init(value: Int) { self.value = value }
        }
        let actorInstance = MyActor(value: 10)
        await assertType(actorInstance)
    }
}
