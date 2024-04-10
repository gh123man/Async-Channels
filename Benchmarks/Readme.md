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
SPSC | `Int` | `1090`
MPSC | `Int` | `698`
SPMC | `Int` | `887`
MPMC | `Int` | `957`
MPSC Write Contention | `Int` | `707`
SPSC Buffered(100) | `Int` | `604`
MPSC Buffered(100) | `Int` | `639`
SPMC Buffered(100) | `Int` | `642`
MPMC Buffered(100) | `Int` | `960`
MPSC Write Contention Buffered(100) | `Int` | `1095`
SyncRW | `Int` | `1505`
Channel multi-select | `Int` | `1172`
SPSC | `String` | `1299`
MPSC | `String` | `830`
SPMC | `String` | `911`
MPMC | `String` | `1001`
MPSC Write Contention | `String` | `828`
SPSC Buffered(100) | `String` | `725`
MPSC Buffered(100) | `String` | `703`
SPMC Buffered(100) | `String` | `691`
MPMC Buffered(100) | `String` | `1014`
MPSC Write Contention Buffered(100) | `String` | `1152`
SyncRW | `String` | `1703`
Channel multi-select | `String` | `1190`
SPSC | `ValueData` | `1167`
MPSC | `ValueData` | `772`
SPMC | `ValueData` | `904`
MPMC | `ValueData` | `977`
MPSC Write Contention | `ValueData` | `768`
SPSC Buffered(100) | `ValueData` | `496`
MPSC Buffered(100) | `ValueData` | `652`
SPMC Buffered(100) | `ValueData` | `645`
MPMC Buffered(100) | `ValueData` | `987`
MPSC Write Contention Buffered(100) | `ValueData` | `1158`
SyncRW | `ValueData` | `1485`
Channel multi-select | `ValueData` | `1176`
SPSC | `RefData` | `1306`
MPSC | `RefData` | `933`
SPMC | `RefData` | `969`
MPMC | `RefData` | `1219`
MPSC Write Contention | `RefData` | `946`
SPSC Buffered(100) | `RefData` | `675`
MPSC Buffered(100) | `RefData` | `729`
SPMC Buffered(100) | `RefData` | `742`
MPMC Buffered(100) | `RefData` | `1220`
MPSC Write Contention Buffered(100) | `RefData` | `1221`
SyncRW | `RefData` | `1685`
Channel multi-select | `RefData` | `1198`
SPSC Async alg | `Int` | `3000`
MPSC Async alg | `Int` | `4030`
SPMC Async alg | `Int` | `3951`
MPMC Async alg | `Int` | `4231`
MPSC Async alg Write Contention | `Int` | `7343`
SPSC Async alg | `String` | `3021`
MPSC Async alg | `String` | `4083`
SPMC Async alg | `String` | `3937`
MPMC Async alg | `String` | `4313`
MPSC Async alg Write Contention | `String` | `21004`
SPSC Async alg | `ValueData` | `3006`
MPSC Async alg | `ValueData` | `4052`
SPMC Async alg | `ValueData` | `3911`
MPMC Async alg | `ValueData` | `4275`
MPSC Async alg Write Contention | `ValueData` | `19684`
SPSC Async alg | `RefData` | `3026`
MPSC Async alg | `RefData` | `4064`
SPMC Async alg | `RefData` | `3929`
MPMC Async alg | `RefData` | `4285`
MPSC Async alg Write Contention | `RefData` | `20992`

## Async Channels vs Async Algorithms AsyncChannel

Apple has their own channel implementation in the [swift-async-algorithms package](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md). We cannot compare every benchmark since it does not support buffering or select.


### Why is swift slower than go?

The Swift compiler will not emit specialized implementations of generic structures (in this case, the channel and it's internals). Instead, it will use runtime generics which have significant overhead. 

[wadetregaskis](https://forums.swift.org/u/wadetregaskis/summary) on the swift.org forums [was able to prove this by manually specializing the channel](https://forums.swift.org/t/async-channels-for-swift-concurrency/70752/18). If you have ideas on how to further improve performance, or get the compiler to emit more efficient code, please open an issue or PR! 

Aside from the above limitations, special care has been taken to use efficient locking structures, queueing, and buffering to achieve as much performance as possible. We have noticed that `OSSpinLock` can achieve even greater throughput, however this API is deprecated and can cause issues in real world applications so `os_unfair_lock` is used instead. With full specialization, the locking strategy matters much less - so hopefully we can eventually achieve that with further optimization or compiler updates. 

## Future work

This has not yet been benchmarked on linux. Linux uses `pthread_mutex_t` so expect results to differ somewhat. 

