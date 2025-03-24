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
SPSC | `Int` | `985`
MPSC | `Int` | `560`
SPMC | `Int` | `619`
MPMC | `Int` | `522`
MPSC Write Contention | `Int` | `734`
SPSC Buffered(100) | `Int` | `254`
MPSC Buffered(100) | `Int` | `379`
SPMC Buffered(100) | `Int` | `377`
MPMC Buffered(100) | `Int` | `529`
MPSC Write Contention Buffered(100) | `Int` | `729`
SyncRW | `Int` | `1039`
Channel multi-select | `Int` | `1846`
SPSC | `String` | `1008`
MPSC | `String` | `565`
SPMC | `String` | `613`
MPMC | `String` | `538`
MPSC Write Contention | `String` | `737`
SPSC Buffered(100) | `String` | `231`
MPSC Buffered(100) | `String` | `381`
SPMC Buffered(100) | `String` | `370`
MPMC Buffered(100) | `String` | `536`
MPSC Write Contention Buffered(100) | `String` | `740`
SyncRW | `String` | `1136`
Channel multi-select | `String` | `1860`
SPSC | `ValueData` | `1000`
MPSC | `ValueData` | `558`
SPMC | `ValueData` | `612`
MPMC | `ValueData` | `533`
MPSC Write Contention | `ValueData` | `736`
SPSC Buffered(100) | `ValueData` | `229`
MPSC Buffered(100) | `ValueData` | `375`
SPMC Buffered(100) | `ValueData` | `351`
MPMC Buffered(100) | `ValueData` | `516`
MPSC Write Contention Buffered(100) | `ValueData` | `745`
SyncRW | `ValueData` | `1116`
Channel multi-select | `ValueData` | `1862`
SPSC | `RefData` | `1028`
MPSC | `RefData` | `604`
SPMC | `RefData` | `616`
MPMC | `RefData` | `565`
MPSC Write Contention | `RefData` | `769`
SPSC Buffered(100) | `RefData` | `165`
MPSC Buffered(100) | `RefData` | `346`
SPMC Buffered(100) | `RefData` | `334`
MPMC Buffered(100) | `RefData` | `565`
MPSC Write Contention Buffered(100) | `RefData` | `754`
SyncRW | `RefData` | `1162`
Channel multi-select | `RefData` | `1894`


## Async Channels vs Async Algorithms AsyncChannel

Apple has their own channel implementation in the [swift-async-algorithms package](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md). We cannot compare every benchmark since it does not support buffering or select. Below are the results from comparable tests on the same data types as above. 

Test | Type | Execution Time(ms)
-----|------|---------------
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

Async algorithms channel seems to fall apart with write contention on non integer types. 

## Future work

I have not published benchmarks on linux. Linux uses `pthread_mutex_t` and from my limited testing, performance is slightly worse than MacOS, in line compared to AsyncAlgorithms, yet still significantly slower than go. 

