# Benchmarks

This sub-project attempts to compare async channels with golang.

## Setup

All swift tests were run with `10` rounds (averaged) with default release optimizations.\
All Go tests were written as go micro benchmarks.\
All tests performed on an M1 max

## Swift vs Go

| Test Case  | Go (seconds) | Swift (seconds) | Swift `n` times slower than go  |
| --------------------------- | ----------- | ----------- | ----- |
| testSingleReaderManyWriter  | `0.318661688` | `0.7567623973` | `2.37x`  |
| testHighConcurrency         | `0.328830854` | `0.7811600089` | `2.38x`  |
| testHighConcurrencyBuffered | `0.362022931` | `1.191550505` | `3.29x`  |
| testSyncRw                  | `0.132789557` | `1.517975307` | `11.43x` |
| testSelect                  | `0.306248166` | `1.376920402` | `4.50x`  |

## Async Channels vs Async Algorithms AsyncChannel

Apple has their own channel implementation in the [swift-async-algorithms package](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md). We cannot compare every benchmark since it does not support buffering or select. 

| Test Case  | This Library | Async Algorithms `AsyncChannel` | This library `n` times faster   |
| --------------------------- | ----------- | ----------- | ----- |
| testSingleReaderManyWriter  | `0.7567623973` | `5.884461689` | `7.78x`  |
| testHighConcurrency         | `0.7811600089` | `8.240125799` | `10.55x`  |

### Why is swift slower than go?

The Swift compiler will not emit specialized implementations of generic structures (in this case, the channel and it's internals). Instead, it will use runtime generics which have significant overhead. 

[wadetregaskis](https://forums.swift.org/u/wadetregaskis/summary) on the swift.org forums [was able to prove this by manually specializing the channel](https://forums.swift.org/t/async-channels-for-swift-concurrency/70752/18). If you have ideas on how to further improve performance, or get the compiler to emit more efficient code, please open an issue or PR! 

Aside from the above limitations, special care has been taken to use efficient locking structures, queueing, and buffering to achieve as much performance as possible. We have noticed that `OSSpinLock` can achieve even greater throughput, however this API is deprecated and can cause issues in real world applications so `os_unfair_lock` is used instead. With full specialization, the locking strategy matters much less - so hopefully we can eventually achieve that with further optimization or compiler updates. 

## Future work

This has not yet been benchmarked on linux. Linux uses `pthread_mutex_t` so expect results to differ somewhat. 