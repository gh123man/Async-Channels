
<table>
<tr><th> 

![Swift](https://skillicons.dev/icons?i=swift)</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)</th>
</tr>
<tr style="vertical-align: top;"><td> 

```swift
let msg = Channel<String>()
let done = Channel<Bool>()

Task {
    for await m in msg {
        print(m)
    }
    print("closed")
    await done <- true
}

await msg <- "hi"
await msg.close()
await <-done
```
</td><td>


```go
msg := make(chan string)
done := make(chan bool)

go func() {
    for m := range msg {
        fmt.Println(m)
    }
    fmt.Println("closed")
    done <- true
}()

msg <- "hi"
close(msg)
<-done
```
</td></tr>
</table>

### Buffered Channels

Channels in Swift can be buffered or unbuffered


<table>
<tr><th> 

![Swift](https://skillicons.dev/icons?i=swift)</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)</th>
</tr>
<tr style="vertical-align: top;"><td> 

```swift
let count = Channel<Int>(capacity: 100)

for i in (0..<100) {
    await count <- i
}
await count.close()


let sum = await count.reduce(0) { sum, next in
    sum + next
}
print(sum)
```
</td><td>


```go
count := make(chan int, 100)

for i := 0; i < 100; i++ {
    count <- i
}
close(count)

sum := 0
for v := range count {
    sum += v
}
fmt.Println(sum)
```
</td></tr>
</table>

Also `map`, `reduce`, etc work on channels in Swift too thanks to `Sequence`!


### Select 

Swift has reserve words for `case` and `default` and the operator support is not flexible enough to support inline channel operations in the select statement. So instead they are implemented as follows: 

<table>
<tr><th> 

![Swift](https://skillicons.dev/icons?i=swift)</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)</th>
</tr>

<tr style="vertical-align: top;">
<td> 

`rx(c)`
</td><td>

`case <-c:`
</td>
</tr>

<tr>
<td> 

`rx(c) { v in ... }`
</td><td>

`case v := <-c: ...`
</td>
</tr>

<tr>
<td> 

`tx(c, "foo")`
</td><td>

`case c <- "foo":`
</td>
</tr>

<tr>
<td> 

`none { ... }`
</td><td>

`default: ...`
</td>
</tr>

</table>

**Gotcha:** You cannot `return` from `none` to break an outer loop in Swift since it's inside a closure. To break a loop surrounding a `select`, you must explicitly set some control variable (ex: `while !done` and `done = true`)

#### Examples

<table>
<tr>
<th> 
Example
<th> 

![Swift](https://skillicons.dev/icons?i=swift)
</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)
</th>
</tr>


<tr>
<td> 


`chan receive`
</td>
<td> 

```swift
let a = Channel<String>(capacity: 1)
await a <- "foo"

await select {
    rx(a) { av in
        print(av!)
    }
    none {
        print("Not called")
    }
}
```
</td><td>


```go
a := make(chan string, 1)
a <- "foo"

select {
case av := <-a:
    fmt.Println(av)

default:
    fmt.Println("Not called")

}
```
</td></tr>

<tr>
<td> 

`chan send`
</td>
<td> 

```swift
let a = Channel<String>(capacity: 1)

await select {
    tx(a, "foo")
    none {
        print("Not called")
    }
}
print(await <-a)

```
</td><td>


```go
a := make(chan string, 1)

select {
case a <- "foo":
default:
    fmt.Println("Not called")
}

fmt.Println(<-a)

```
</td></tr>

<tr>
<td> 

`default`
</td>
<td> 

```swift
let a = Channel<Bool>()

await select {
    rx(a)
    none {
        print("Default case!")
    }
}
```
</td><td>


```go
a := make(chan bool)

select {
case <-a:
default:
    fmt.Println("Default case!")

}
```
</td></tr>
</table> 