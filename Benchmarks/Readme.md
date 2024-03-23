
All tests performed on an M1 max

## Swift channel tests 

Release with default optimizations

```
testSingleReaderManyWriter()
Time elapsed: 0.8838786125183106

testHighConcurrency()
Time elapsed: 0.8206615924835206

testHighConcurrencyBuffered()
Time elapsed: 0.8815396070480347

syncRw()
Time elapsed: 2.205623197555542
```

## Go channel tests (micro benchmarks)

```
goos: darwin
goarch: arm64
pkg: benchmarks
BenchmarkSingleReaderManyWriter-10     	       4	 318661688 ns/op	   53360 B/op	     202 allocs/op
BenchmarkHighConcurrency-10            	       4	 328830854 ns/op	   12192 B/op	     127 allocs/op
BenchmarkHighConcurrencyBuffered-10    	       3	 362022931 ns/op	   20234 B/op	     198 allocs/op
BenchmarkSyncRw-10                     	       8	 132789557 ns/op	     112 B/op	       1 allocs/op
```

## compared results 

`testSingleReaderManyWriter`
go ~ `2.77x` faster

`testHighConcurrency`
go ~ `2.50x` faster

`testHighConcurrencyBuffered`
go ~ `2.44x` faster

`syncRw`
go ~ `16.61x` faster