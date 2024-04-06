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

| Test case                             | Data type   | Result (seconds) |
|---------------------------------------|-------------|------------------|
| testSingleReaderManyWriter            | `Int`       | `0.684`          |
| testHighConcurrency                   | `Int`       | `0.719`          |
| testHighConcurrencyBuffered           | `Int`       | `1.104`          |
| testSyncRw                            | `Int`       | `1.508`          |
| testSelect                            | `Int`       | `1.545`          |
| testSingleReaderManyWriter            | `String`    | `0.811`          |
| testHighConcurrency                   | `String`    | `0.838`          |
| testHighConcurrencyBuffered           | `String`    | `1.137`          |
| testSyncRw                            | `String`    | `1.706`          |
| testSelect                            | `String`    | `1.562`          |
| testSingleReaderManyWriter            | `ValueData` | `0.750`          |
| testHighConcurrency                   | `ValueData` | `0.772`          |
| testHighConcurrencyBuffered           | `ValueData` | `1.159`          |
| testSyncRw                            | `ValueData` | `1.518`          |
| testSelect                            | `ValueData` | `1.560`          |
| testSingleReaderManyWriter            | `RefData`   | `0.871`          |
| testHighConcurrency                   | `RefData`   | `0.926`          |
| testHighConcurrencyBuffered           | `RefData`   | `1.187`          |
| testSyncRw                            | `RefData`   | `1.681`          |
| testSelect                            | `RefData`   | `1.543`          |
| testAsyncAlgSingleReaderManyWriter    | `Int`       | `5.436`          |
| testAsyncAlgSingleHighConcurrency     | `Int`       | `7.373`          |
| testAsyncAlgSingleReaderManyWriter    | `String`    | `5.395`          |
| testAsyncAlgSingleHighConcurrency     | `String`    | `7.340`          |
| testAsyncAlgSingleReaderManyWriter    | `ValueData` | `5.393`          |
| testAsyncAlgSingleHighConcurrency     | `ValueData` | `7.334`          |
| testAsyncAlgSingleReaderManyWriter    | `RefData`   | `5.392`          |
| testAsyncAlgSingleHighConcurrency     | `RefData`   | `7.328`          |

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

