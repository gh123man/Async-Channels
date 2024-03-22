
## Swift channel tests 

Release with default optimizations

```
testSingleReaderManyWriter()
Time elapsed: 2.106268366177877

testHighConcurrency()
Time elapsed: 2.2055516640345254

testHighConcurrencyBuffered()
Time elapsed: 2.318518042564392 

syncRw()
Time elapsed: 2.0480897029240928
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
go ~ `6.75x` faster

`testHighConcurrency`
go ~ `6.70x` faster

`testHighConcurrencyBuffered`
go ~ `6.40x` faster

`syncRw`
go ~ `15.42x` faster