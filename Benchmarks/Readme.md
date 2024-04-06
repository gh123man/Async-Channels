# Benchmarks

This sub-project attempts to compare async channels with golang.

## Setup

All swift tests were run with `10` rounds (averaged) with default release optimizations.\
All Go tests were written as go micro benchmarks.\
All tests performed on an M1 max

## Swift vs Go

(Integer input only)

| Test Case  | Go (seconds) | Swift (seconds) | Swift `n` times slower than go  |
| --------------------------- | ----------- | ----------- | ----- |
| testSingleReaderManyWriter  | `0.318661688` | `0.702384305` | `2.15x`  |
| testHighConcurrency         | `0.328830854` | `0.7504368067` | `2.19x`  |
| testHighConcurrencyBuffered | `0.362022931` | `1.144838405` | `3.05x`  |
| testSyncRw                  | `0.132789557` | `1.547898102` | `11.36x` |
| testSelect                  | `0.306248166` | `1.401787996` | `5.05x`  |

### Raw results 

The below results are from running the whole benchmark suit which covers multiple data types. 


```
("testSingleReaderManyWriter(_:) Int", 0.6841711044311524)
("testHighConcurrency(_:) Int", 0.7190240025520325)
("testHighConcurrencyBuffered(_:) Int", 1.103571593761444)
("testSyncRw(_:) Int", 1.5079661011695862)
("testSelect(_:) Int", 1.54532790184021)

("testSingleReaderManyWriter(_:) String", 0.8109323024749756)
("testHighConcurrency(_:) String", 0.8379721999168396)
("testHighConcurrencyBuffered(_:) String", 1.1374988079071044)
("testSyncRw(_:) String", 1.7057185053825379)
("testSelect(_:) String", 1.5620223045349122)

("testSingleReaderManyWriter(_:) ValueData", 0.7498844027519226)
("testHighConcurrency(_:) ValueData", 0.7715810060501098)
("testHighConcurrencyBuffered(_:) ValueData", 1.1586477041244507)
("testSyncRw(_:) ValueData", 1.517892301082611)
("testSelect(_:) ValueData", 1.5599609017372131)

("testSingleReaderManyWriter(_:) RefData", 0.8706925988197327)
("testHighConcurrency(_:) RefData", 0.9256610989570617)
("testHighConcurrencyBuffered(_:) RefData", 1.186893892288208)
("testSyncRw(_:) RefData", 1.6812219023704529)
("testSelect(_:) RefData", 1.5434199810028075)

("testAsyncAlgSingleReaderManyWriter(_:) Int", 5.4360926985740665)
("testAsyncAlgSingleHighConcurrency(_:) Int", 7.373045003414154)

("testAsyncAlgSingleReaderManyWriter(_:) String", 5.395480096340179)
("testAsyncAlgSingleHighConcurrency(_:) String", 7.339814698696136)

("testAsyncAlgSingleReaderManyWriter(_:) ValueData", 5.392919993400573)
("testAsyncAlgSingleHighConcurrency(_:) ValueData", 7.33357390165329)

("testAsyncAlgSingleReaderManyWriter(_:) RefData", 5.391775095462799)
("testAsyncAlgSingleHighConcurrency(_:) RefData", 7.327817296981811)
```

## Async Channels vs Async Algorithms AsyncChannel

Apple has their own channel implementation in the [swift-async-algorithms package](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md). We cannot compare every benchmark since it does not support buffering or select. 

| Test Case  | This Library | Async Algorithms `AsyncChannel` | This library `n` times faster   |
| --------------------------- | ----------- | ----------- | ----- |
| testSingleReaderManyWriter  | `0.7498844027519226` | `5.4360926985740665` | `7.95x`  |
| testHighConcurrency         | `0.7715810060501098` | `7.373045003414154` | `10.25x`  |

### Why is swift slower than go?

The Swift compiler will not emit specialized implementations of generic structures (in this case, the channel and it's internals). Instead, it will use runtime generics which have significant overhead. 

[wadetregaskis](https://forums.swift.org/u/wadetregaskis/summary) on the swift.org forums [was able to prove this by manually specializing the channel](https://forums.swift.org/t/async-channels-for-swift-concurrency/70752/18). If you have ideas on how to further improve performance, or get the compiler to emit more efficient code, please open an issue or PR! 

Aside from the above limitations, special care has been taken to use efficient locking structures, queueing, and buffering to achieve as much performance as possible. We have noticed that `OSSpinLock` can achieve even greater throughput, however this API is deprecated and can cause issues in real world applications so `os_unfair_lock` is used instead. With full specialization, the locking strategy matters much less - so hopefully we can eventually achieve that with further optimization or compiler updates. 

## Future work

This has not yet been benchmarked on linux. Linux uses `pthread_mutex_t` so expect results to differ somewhat. 

