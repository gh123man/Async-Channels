import Testing
@testable import AsyncChannels

final class TestC<T: Sendable>: Sendable {
    let v: T
    let s: String
    init(_ v: T, s: String) {
        self.v = v
        self.s = s
    }
}

struct TestS<T: Sendable>: Sendable {
    let v: T
    let s: String
}

enum TestE<T: Sendable>: Sendable {
    case foo
    case bar
    case t(T)
}

@Suite(.timeLimit(.minutes(1)))
final class TypeTests {
    
    
    func assertType<T: Sendable & Equatable>(_ val: T) async {
        let c = Channel<T>(capacity: 1)
        await c <- val
        let r = await <-c
        #expect(r == val)
    }
    
    @Test func lifetimeRefType() async {
        final class RefType: Sendable {
            let s = "string foo bar"
            let i = 1
            let f = 3.12
            
            deinit {
                print("Deinit")
                print(s)
            }
        }
        let c = Channel<RefType>(capacity: 10)
        
        await {
            await c <- RefType()
        }()
        
        await {
            print((await <-c)!.s)
        }()
    }
    
    @Test func lifetimeValType() async {
        struct ValType: Sendable {
            let s = "string foo bar"
            let i = 1
            let f = 3.12
        }
        let c = Channel<ValType>(capacity: 10)
        
        await {
            await c <- ValType()
        }()
        
        await {
            print((await <-c)!.s)
        }()
    }
    
    @Test func lifetimeListCOW() async {
        let c = Channel<[Sendable]>(capacity: 10)
        var val: [Sendable] = ["abc", 1, 3.14]
        await {
            await c <- val
        }()
        val.append("foo")
        
        await {
            let v = (await <-c)!
            print(v[0])
            print(v[1])
            print(v[2])
            #expect(v.count == 3)
            print(val[3])
        }()
    }
    
    @Test func allTypes() async {
        // Primitives
        await assertType(42)
        await assertType(3.14)
        await assertType(true)
        await assertType("Hello")
        await assertType(String(repeating: "Foo Bar ", count: 10000))

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

        for _ in 0...100_000 {
            // Classes
            final class MyClass: Equatable, Sendable {
                let x: Int
                init(x: Int) { self.x = x }
                static func == (lhs: MyClass, rhs: MyClass) -> Bool { lhs.x == rhs.x }
            }
            await assertType(MyClass(x: 5))
        }

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
        
        
        // complex/generic
        
        // Uncomment and check for leaks!
//        for _ in 0...100_000 {
            let c = TestC<TestS<String>>(TestS<String>(v: "Hello", s: "foo"), s: "barA")
            let e: TestE<TestC<TestS<String>>> = .t(c)
            let l: [TestS<TestE<TestC<TestS<String>>>>] = [.init(v: e, s: "barB"), .init(v: e, s: "barB"), .init(v: e, s: "barB"), .init(v: e, s: "barB"), .init(v: e, s: "barB")]
            
            await {
                let c = Channel<[TestS<TestE<TestC<TestS<String>>>>] >(capacity: 1)
                await c <- l
                let re = (await <-c)!
                
                for r in re {
                    #expect(r.s == "barB")
                    guard case let .t(v) = r.v else {
                        Issue.record("Failed to unwrap value")
                        return
                    }
                    #expect(v.s == "barA")
                    #expect(v.v.v == "Hello")
                    #expect(v.v.s == "foo")
                    #expect(v.v.v == "Hello")
                }
            }()
//        }
    }
}
