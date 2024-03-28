# Benchmarks

This sub-project attempts to compare async channels with go and other channel implementations. 

## Results

All swift tests were run with `10` rounds (averaged) with default release optimizations.\
All Go tests were written as go micro benchmarks.\
All tests performed on an M1 max

| Test Case  | Go (seconds) | Swift (seconds) | Swift `n` times slower than go  |
| --------------------------- | ----------- | ----------- | ----- |
| testSingleReaderManyWriter  | `0.318661688` | `1.292844605` | `4.06x`  |
| testHighConcurrency         | `0.328830854` | `1.387607598` | `4.22x`  |
| testHighConcurrencyBuffered | `0.362022931` | `1.330690598` | `3.68x`  |
| testSyncRw                  | `0.132789557` | `2.225011003` | `16.76x` |
| testSelect                  | `0.306248166` | `1.589311111` | `5.19x`  |

### Why is swift slower than go?

The Swift compiler will not emit specialized implementations of generic structures (in this case, the channel and it's internals). Instead, it will use runtime generics which have significant overhead. 

[wadetregaskis](https://forums.swift.org/u/wadetregaskis/summary) on the swift.org forums [was able to prove this by manually specializing the channel](https://forums.swift.org/t/async-channels-for-swift-concurrency/70752/18). If you have ideas on how to further improve performance, or get the compiler to emit more efficient code, please open an issue or PR! 

Aside from the above limitations, special care has been taken to use efficient locking structures, queueing, and buffering to achieve as much performance as possible. We have noticed that `OSSpinLock` can achieve even greater throughput, however this API is deprecated and can cause issues in real world applications so `os_unfair_lock` is used instead. With full specialization, the locking strategy matters much less - so hopefully we can eventually achieve that with further optimization or compiler updates. 

## Future work

This has not yet been benchmarked on linux. Linux uses `pthread_mutex_t` so expect results to differ somewhat. 