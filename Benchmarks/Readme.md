# Benchmarks

This sub-project attempts to compare async channels with golang.

## Setup

All swift tests were run with `10` rounds (averaged) with default release optimizations.\
All Go tests were written as go micro benchmarks.\
All tests performed on an M1 max

## Swift vs Go

### Raw results 

First are the baseline go tests.

```
goos: darwin
goarch: arm64
pkg: benchmarks
BenchmarkSPSC-10                           	       7	 158625381 ns/op	     274 B/op	       3 allocs/op
BenchmarkMPSC-10                           	       4	 262326958 ns/op	    1160 B/op	       6 allocs/op
BenchmarkSPMC-10                           	       4	 273297438 ns/op	     992 B/op	       7 allocs/op
BenchmarkMPMC-10                           	       4	 288092292 ns/op	    1080 B/op	       5 allocs/op
BenchmarkMPSCWriteContention-10            	       4	 319210156 ns/op	   19288 B/op	     136 allocs/op
BenchmarkSPSCBuffered-10                   	      15	  72298667 ns/op	     928 B/op	       3 allocs/op
BenchmarkMPSCBuffered-10                   	      13	  90277561 ns/op	     928 B/op	       3 allocs/op
BenchmarkSPMCBuffered-10                   	      13	  90140349 ns/op	     928 B/op	       3 allocs/op
BenchmarkMPMCBuffered-10                   	      12	  92401344 ns/op	     928 B/op	       3 allocs/op
BenchmarkMPSCWriteContentionBuffered-10    	       4	 321178198 ns/op	   13696 B/op	     136 allocs/op
BenchmarkSyncRw-10                         	       8	 131667010 ns/op	     112 B/op	       1 allocs/op
BenchmarkMultiSelect-10                    	       4	 310069656 ns/op	     576 B/op	       6 allocs/op
```

The below results are from running the whole benchmark suit which covers multiple data types. 

Test | Type | Execution Time(ms)
-----|------|---------------
SPSC | `Int` | `1320`
MPSC | `Int` | `947`
SPMC | `Int` | `1195`
MPMC | `Int` | `1065`
MPSC Write Contention | `Int` | `1424`
SPSC Buffered(100) | `Int` | `446`
MPSC Buffered(100) | `Int` | `799`
SPMC Buffered(100) | `Int` | `787`
MPMC Buffered(100) | `Int` | `1071`
MPSC Write Contention Buffered(100) | `Int` | `1891`
SyncRW | `Int` | `1752`
Channel multi-select | `Int` | `1972`
SPSC | `String` | `1527`
MPSC | `String` | `1154`
SPMC | `String` | `1264`
MPMC | `String` | `1117`
MPSC Write Contention | `String` | `1544`
SPSC Buffered(100) | `String` | `623`
MPSC Buffered(100) | `String` | `895`
SPMC Buffered(100) | `String` | `873`
MPMC Buffered(100) | `String` | `1139`
MPSC Write Contention Buffered(100) | `String` | `1988`
SyncRW | `String` | `1793`
Channel multi-select | `String` | `1980`
SPSC | `ValueData` | `1386`
MPSC | `ValueData` | `1083`
SPMC | `ValueData` | `1338`
MPMC | `ValueData` | `1124`
MPSC Write Contention | `ValueData` | `1598`
SPSC Buffered(100) | `ValueData` | `550`
MPSC Buffered(100) | `ValueData` | `890`
SPMC Buffered(100) | `ValueData` | `787`
MPMC Buffered(100) | `ValueData` | `1085`
MPSC Write Contention Buffered(100) | `ValueData` | `1947`
SyncRW | `ValueData` | `1741`
Channel multi-select | `ValueData` | `1970`
SPSC | `RefData` | `1566`
MPSC | `RefData` | `1262`
SPMC | `RefData` | `1251`
MPMC | `RefData` | `1338`
MPSC Write Contention | `RefData` | `1599`
SPSC Buffered(100) | `RefData` | `753`
MPSC Buffered(100) | `RefData` | `947`
SPMC Buffered(100) | `RefData` | `959`
MPMC Buffered(100) | `RefData` | `1348`
MPSC Write Contention Buffered(100) | `RefData` | `2078`
SyncRW | `RefData` | `1996`
Channel multi-select | `RefData` | `2003`


## Async Channels vs Async Algorithms AsyncChannel

Apple has their own channel implementation in the [swift-async-algorithms package](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md). We cannot compare every benchmark since it does not support buffering or select. Below are the results from comparable tests on the same data types as above. 

Test | Type | Execution Time(ms)
-----|------|---------------
SPSC Async alg | `Int` | `3132`
MPSC Async alg | `Int` | `4476`
SPMC Async alg | `Int` | `4354`
MPMC Async alg | `Int` | `5412`
MPSC Async alg Write Contention | `Int` | `10745`
SPSC Async alg | `String` | `3024`
MPSC Async alg | `String` | `4669`
SPMC Async alg | `String` | `4437`
MPMC Async alg | `String` | `5474`
MPSC Async alg Write Contention | `String` | `21313`
SPSC Async alg | `ValueData` | `2951`
MPSC Async alg | `ValueData` | `4534`
SPMC Async alg | `ValueData` | `4420`
MPMC Async alg | `ValueData` | `5768`
MPSC Async alg Write Contention | `ValueData` | `23013`
SPSC Async alg | `RefData` | `3173`
MPSC Async alg | `RefData` | `5031`
SPMC Async alg | `RefData` | `4597`
MPMC Async alg | `RefData` | `5568`
MPSC Async alg Write Contention | `RefData` | `20117`

Async algorithms channel seems to fall apart with write contention on non integer types. 


## Why is swift slower than go?

The Swift compiler will not emit specialized implementations of generic structures (in this case, the channel and it's internals). Instead, it will use runtime generics which have significant overhead. 

[wadetregaskis](https://forums.swift.org/u/wadetregaskis/summary) on the swift.org forums [was able to prove this by manually specializing the channel](https://forums.swift.org/t/async-channels-for-swift-concurrency/70752/18). If you have ideas on how to further improve performance, or get the compiler to emit more efficient code, please open an issue or PR! 

Aside from the above limitations, special care has been taken to use efficient locking structures, queueing, and buffering to achieve as much performance as possible. We have noticed that `OSSpinLock` can achieve even greater throughput, however this API is deprecated and can cause issues in real world applications so `os_unfair_lock` is used instead. With full specialization, the locking strategy matters much less - so hopefully we can eventually achieve that with further optimization or compiler updates. 

## Future work

This has not yet been benchmarked on linux. Linux uses `pthread_mutex_t` so expect results to differ somewhat. 

