# Benchmarks

This sub-project attempts to compare async channels with golang.

## Setup

The Swift benchmark harness now supports configurable rounds, warmups, and JSON output for version-to-version comparisons.

Recommended workflow:

```bash
BENCHMARK_NAME=swift-6.2.3 Benchmarks/run_swift_benchmarks.sh
BENCHMARK_NAME=swift-6.3.0 SWIFT_BIN=$HOME/.swiftly/bin/swift Benchmarks/run_swift_benchmarks.sh
Benchmarks/compare_swift_benchmarks.py \
  Benchmarks/results/swift-6.2.3-<timestamp>.json \
  Benchmarks/results/swift-6.3.0-<timestamp>.json
```

For cross-library comparison on the same machine:

```bash
BENCHMARK_NAME=swift-6.3.0 SWIFT_BIN=$HOME/.swiftly/bin/swift Benchmarks/run_swift_benchmarks.sh
BENCHMARK_NAME=go-1.26.1 Benchmarks/run_go_benchmarks.sh
Benchmarks/compare_library_benchmarks.py \
  Benchmarks/results/swift-6.3.0-<timestamp>.json \
  Benchmarks/results/go-1.26.1-<timestamp>.json
```

Useful knobs:

```bash
xcrun swift run -c release --package-path Benchmarks Benchmarks --help
```

Results written to `Benchmarks/results/` are ignored by git so local benchmark output does not dirty the repository.

All Go tests were written as go micro benchmarks.\
All tests performed on the local machine used to generate the current results.

The benchmark README is generated from local result files:

```bash
Benchmarks/update_benchmark_readme.sh
```

Or as part of a benchmark run:

```bash
UPDATE_README=1 BENCHMARK_NAME=swift-6.3.0 SWIFT_BIN=$HOME/.swiftly/bin/swift Benchmarks/run_swift_benchmarks.sh
UPDATE_README=1 BENCHMARK_NAME=go-1.26.1 Benchmarks/run_go_benchmarks.sh
```

<!-- benchmark-generated:start -->
## Generated Results

These sections are generated from benchmark result files in `Benchmarks/results/`.

**Environment**
- Swift toolchain: `swift-6.3.0`
- Swift host: `brians-macbook-air.local`
- Swift rounds: `5` measured, `1` warmup
- Swift writes: `1000000`, sync writes: `5000000`, select writes/channel: `100000`, buffer: `100`
- Baseline Swift toolchain: `swift-6.2.3`
- Baseline Swift host: `brians-macbook-air.local`
- Baseline Swift rounds: `5` measured, `1` warmup
- Baseline Swift writes: `1000000`, sync writes: `5000000`, select writes/channel: `100000`, buffer: `100`

Baseline Swift report: `Benchmarks/results/swift-6.2.3-20260326-185306.json`
Candidate Swift report: `Benchmarks/results/swift-6.3.0-20260326-191022.json`

**Swift Toolchain Comparison**
Library | Test | Type | Baseline Avg (ms) | Candidate Avg (ms) | Delta %
--- | --- | --- | --- | --- | ---
AsyncAlgorithms | MPMC | `Int` | `7027.25` | `5215.65` | `-25.78%`
AsyncAlgorithms | MPMC | `RefData` | `7504.62` | `5588.75` | `-25.53%`
AsyncAlgorithms | MPMC | `String` | `8709.50` | `5587.76` | `-35.84%`
AsyncAlgorithms | MPMC | `ValueData` | `9590.54` | `5014.12` | `-47.72%`
AsyncAlgorithms | MPSC | `Int` | `4788.59` | `3761.30` | `-21.45%`
AsyncAlgorithms | MPSC | `RefData` | `5180.12` | `3945.61` | `-23.83%`
AsyncAlgorithms | MPSC | `String` | `6355.52` | `4179.43` | `-34.24%`
AsyncAlgorithms | MPSC | `ValueData` | `6757.28` | `4236.05` | `-37.31%`
AsyncAlgorithms | MPSC Write Contention | `Int` | `9298.62` | `5591.63` | `-39.87%`
AsyncAlgorithms | MPSC Write Contention | `RefData` | `8655.29` | `6262.41` | `-27.65%`
AsyncAlgorithms | MPSC Write Contention | `String` | `10685.25` | `6139.55` | `-42.54%`
AsyncAlgorithms | MPSC Write Contention | `ValueData` | `10456.41` | `5252.34` | `-49.77%`
AsyncAlgorithms | SPMC | `Int` | `4789.23` | `3622.70` | `-24.36%`
AsyncAlgorithms | SPMC | `RefData` | `5223.19` | `4114.84` | `-21.22%`
AsyncAlgorithms | SPMC | `String` | `6353.19` | `3890.67` | `-38.76%`
AsyncAlgorithms | SPMC | `ValueData` | `6499.68` | `3986.87` | `-38.66%`
AsyncAlgorithms | SPSC | `Int` | `2871.85` | `2305.84` | `-19.71%`
AsyncAlgorithms | SPSC | `RefData` | `2927.92` | `2418.31` | `-17.41%`
AsyncAlgorithms | SPSC | `String` | `3467.80` | `2350.12` | `-32.23%`
AsyncAlgorithms | SPSC | `ValueData` | `4047.56` | `2420.69` | `-40.19%`
AsyncChannels | Channel multi-select | `Int` | `1695.74` | `1381.14` | `-18.55%`
AsyncChannels | Channel multi-select | `RefData` | `1893.57` | `1176.29` | `-37.88%`
AsyncChannels | Channel multi-select | `String` | `1878.38` | `1362.78` | `-27.45%`
AsyncChannels | Channel multi-select | `ValueData` | `2183.19` | `1449.17` | `-33.62%`
AsyncChannels | MPMC | `Int` | `933.62` | `773.33` | `-17.17%`
AsyncChannels | MPMC | `RefData` | `983.93` | `725.90` | `-26.22%`
AsyncChannels | MPMC | `String` | `930.62` | `818.39` | `-12.06%`
AsyncChannels | MPMC | `ValueData` | `977.47` | `815.51` | `-16.57%`
AsyncChannels | MPMC Buffered(100) | `Int` | `454.85` | `459.06` | `+0.92%`
AsyncChannels | MPMC Buffered(100) | `RefData` | `649.37` | `501.98` | `-22.70%`
AsyncChannels | MPMC Buffered(100) | `String` | `495.95` | `445.53` | `-10.17%`
AsyncChannels | MPMC Buffered(100) | `ValueData` | `602.29` | `499.51` | `-17.06%`
AsyncChannels | MPSC | `Int` | `476.00` | `332.49` | `-30.15%`
AsyncChannels | MPSC | `RefData` | `638.52` | `323.41` | `-49.35%`
AsyncChannels | MPSC | `String` | `599.85` | `330.18` | `-44.96%`
AsyncChannels | MPSC | `ValueData` | `640.65` | `315.16` | `-50.81%`
AsyncChannels | MPSC Buffered(100) | `Int` | `264.37` | `157.45` | `-40.44%`
AsyncChannels | MPSC Buffered(100) | `RefData` | `474.13` | `147.87` | `-68.81%`
AsyncChannels | MPSC Buffered(100) | `String` | `365.77` | `212.38` | `-41.94%`
AsyncChannels | MPSC Buffered(100) | `ValueData` | `481.41` | `230.82` | `-52.05%`
AsyncChannels | MPSC Write Contention | `Int` | `511.44` | `385.93` | `-24.54%`
AsyncChannels | MPSC Write Contention | `RefData` | `730.74` | `376.60` | `-48.46%`
AsyncChannels | MPSC Write Contention | `String` | `681.47` | `390.94` | `-42.63%`
AsyncChannels | MPSC Write Contention | `ValueData` | `697.42` | `419.93` | `-39.79%`
AsyncChannels | MPSC Write Contention Buffered(100) | `Int` | `520.99` | `395.09` | `-24.17%`
AsyncChannels | MPSC Write Contention Buffered(100) | `RefData` | `788.64` | `356.57` | `-54.79%`
AsyncChannels | MPSC Write Contention Buffered(100) | `String` | `650.07` | `435.39` | `-33.02%`
AsyncChannels | MPSC Write Contention Buffered(100) | `ValueData` | `725.20` | `424.92` | `-41.41%`
AsyncChannels | SPMC | `Int` | `589.31` | `320.46` | `-45.62%`
AsyncChannels | SPMC | `RefData` | `631.42` | `302.77` | `-52.05%`
AsyncChannels | SPMC | `String` | `510.73` | `297.05` | `-41.84%`
AsyncChannels | SPMC | `ValueData` | `632.23` | `307.19` | `-51.41%`
AsyncChannels | SPMC Buffered(100) | `Int` | `283.86` | `219.90` | `-22.53%`
AsyncChannels | SPMC Buffered(100) | `RefData` | `428.43` | `180.02` | `-57.98%`
AsyncChannels | SPMC Buffered(100) | `String` | `319.52` | `228.32` | `-28.54%`
AsyncChannels | SPMC Buffered(100) | `ValueData` | `424.22` | `217.26` | `-48.79%`
AsyncChannels | SPSC | `Int` | `432.39` | `300.47` | `-30.51%`
AsyncChannels | SPSC | `RefData` | `594.98` | `355.01` | `-40.33%`
AsyncChannels | SPSC | `String` | `705.70` | `332.97` | `-52.82%`
AsyncChannels | SPSC | `ValueData` | `600.47` | `346.81` | `-42.24%`
AsyncChannels | SPSC Buffered(100) | `Int` | `494.76` | `439.99` | `-11.07%`
AsyncChannels | SPSC Buffered(100) | `RefData` | `622.45` | `368.84` | `-40.74%`
AsyncChannels | SPSC Buffered(100) | `String` | `609.59` | `469.59` | `-22.97%`
AsyncChannels | SPSC Buffered(100) | `ValueData` | `821.87` | `485.11` | `-40.97%`
AsyncChannels | SyncRW | `Int` | `487.80` | `327.48` | `-32.87%`
AsyncChannels | SyncRW | `RefData` | `669.29` | `363.38` | `-45.71%`
AsyncChannels | SyncRW | `String` | `651.87` | `357.71` | `-45.13%`
AsyncChannels | SyncRW | `ValueData` | `702.92` | `356.54` | `-49.28%`

**AsyncChannels Results**
Test | Type | Avg (ms) | Median (ms) | Ops/s
--- | --- | --- | --- | ---
SPSC | `Int` | `300.47` | `310.60` | `3328111`
MPSC | `Int` | `332.49` | `332.27` | `3007626`
SPMC | `Int` | `320.46` | `319.93` | `3120474`
MPMC | `Int` | `773.33` | `771.20` | `1293105`
MPSC Write Contention | `Int` | `385.93` | `382.52` | `2591141`
SPSC Buffered(100) | `Int` | `439.99` | `439.22` | `2272779`
MPSC Buffered(100) | `Int` | `157.45` | `159.26` | `6351100`
SPMC Buffered(100) | `Int` | `219.90` | `225.18` | `4547510`
MPMC Buffered(100) | `Int` | `459.06` | `457.86` | `2178367`
MPSC Write Contention Buffered(100) | `Int` | `395.09` | `396.82` | `2531067`
SyncRW | `Int` | `327.48` | `324.22` | `15267918`
Channel multi-select | `Int` | `1381.14` | `1373.23` | `434425`
SPSC | `String` | `332.97` | `332.17` | `3003284`
MPSC | `String` | `330.18` | `332.04` | `3028678`
SPMC | `String` | `297.05` | `299.69` | `3366381`
MPMC | `String` | `818.39` | `822.43` | `1221912`
MPSC Write Contention | `String` | `390.94` | `385.97` | `2557931`
SPSC Buffered(100) | `String` | `469.59` | `475.72` | `2129497`
MPSC Buffered(100) | `String` | `212.38` | `212.69` | `4708434`
SPMC Buffered(100) | `String` | `228.32` | `230.53` | `4379802`
MPMC Buffered(100) | `String` | `445.53` | `444.08` | `2244504`
MPSC Write Contention Buffered(100) | `String` | `435.39` | `412.69` | `2296794`
SyncRW | `String` | `357.71` | `354.91` | `13977834`
Channel multi-select | `String` | `1362.78` | `1348.23` | `440275`
SPSC | `ValueData` | `346.81` | `344.38` | `2883405`
MPSC | `ValueData` | `315.16` | `315.01` | `3172962`
SPMC | `ValueData` | `307.19` | `312.51` | `3255301`
MPMC | `ValueData` | `815.51` | `803.69` | `1226221`
MPSC Write Contention | `ValueData` | `419.93` | `416.36` | `2381321`
SPSC Buffered(100) | `ValueData` | `485.11` | `505.86` | `2061394`
MPSC Buffered(100) | `ValueData` | `230.82` | `228.44` | `4332345`
SPMC Buffered(100) | `ValueData` | `217.26` | `206.35` | `4602739`
MPMC Buffered(100) | `ValueData` | `499.51` | `507.02` | `2001955`
MPSC Write Contention Buffered(100) | `ValueData` | `424.92` | `424.22` | `2353377`
SyncRW | `ValueData` | `356.54` | `353.95` | `14023849`
Channel multi-select | `ValueData` | `1449.17` | `1433.59` | `414029`
SPSC | `RefData` | `355.01` | `347.87` | `2816820`
MPSC | `RefData` | `323.41` | `326.96` | `3092084`
SPMC | `RefData` | `302.77` | `303.59` | `3302870`
MPMC | `RefData` | `725.90` | `720.67` | `1377600`
MPSC Write Contention | `RefData` | `376.60` | `371.72` | `2655310`
SPSC Buffered(100) | `RefData` | `368.84` | `376.02` | `2711186`
MPSC Buffered(100) | `RefData` | `147.87` | `142.17` | `6762521`
SPMC Buffered(100) | `RefData` | `180.02` | `179.84` | `5554794`
MPMC Buffered(100) | `RefData` | `501.98` | `502.03` | `1992126`
MPSC Write Contention Buffered(100) | `RefData` | `356.57` | `355.07` | `2804511`
SyncRW | `RefData` | `363.38` | `362.71` | `13759573`
Channel multi-select | `RefData` | `1176.29` | `1155.01` | `510079`

**AsyncAlgorithms Results**
Test | Type | Avg (ms) | Median (ms) | Ops/s
--- | --- | --- | --- | ---
SPSC | `Int` | `2305.84` | `2305.39` | `433681`
MPSC | `Int` | `3761.30` | `3758.22` | `265865`
SPMC | `Int` | `3622.70` | `3625.11` | `276037`
MPMC | `Int` | `5215.65` | `5232.01` | `191731`
MPSC Write Contention | `Int` | `5591.63` | `5600.81` | `178839`
SPSC | `String` | `2350.12` | `2351.79` | `425510`
MPSC | `String` | `4179.43` | `4111.78` | `239267`
SPMC | `String` | `3890.67` | `3896.53` | `257025`
MPMC | `String` | `5587.76` | `5588.08` | `178963`
MPSC Write Contention | `String` | `6139.55` | `6254.25` | `162878`
SPSC | `ValueData` | `2420.69` | `2420.30` | `413106`
MPSC | `ValueData` | `4236.05` | `4238.90` | `236069`
SPMC | `ValueData` | `3986.87` | `4006.63` | `250824`
MPMC | `ValueData` | `5014.12` | `5013.27` | `199437`
MPSC Write Contention | `ValueData` | `5252.34` | `5050.63` | `190391`
SPSC | `RefData` | `2418.31` | `2292.62` | `413512`
MPSC | `RefData` | `3945.61` | `3793.76` | `253446`
SPMC | `RefData` | `4114.84` | `4196.80` | `243023`
MPMC | `RefData` | `5588.75` | `5980.78` | `178931`
MPSC Write Contention | `RefData` | `6262.41` | `6268.68` | `159683`

- Go toolchain: `go_version_go1.26.1_darwin_arm64`
- Go host: `Apple M5`
- Go rounds: `5` measured, `0` warmup
- Go writes: `1000000`, sync writes: `5000000`, select writes/channel: `100000`, buffer: `100`
Go report: `Benchmarks/results/go_version_go1.26.1_darwin_arm64-20260326-193146.json`

**Cross-Library Comparison**
Test | Type | AsyncAlgorithms Avg (ms) | AsyncChannels Avg (ms) | Go Avg (ms) | AsyncAlgorithms vs Go | AsyncChannels vs Go
--- | --- | --- | --- | --- | --- | ---
Channel multi-select | `Int` |  | `1381.14` | `552.71` |  | `+149.88%`
MPMC | `Int` | `5215.65` | `773.33` | `241.73` | `+2057.62%` | `+219.91%`
MPMC | `RefData` | `5588.75` | `725.90` | 
MPMC | `String` | `5587.76` | `818.39` | 
MPMC | `ValueData` | `5014.12` | `815.51` | 
MPMC Buffered(100) | `Int` |  | `459.06` | `138.23` |  | `+232.10%`
MPSC | `Int` | `3761.30` | `332.49` | `244.90` | `+1435.87%` | `+35.77%`
MPSC | `RefData` | `3945.61` | `323.41` | 
MPSC | `String` | `4179.43` | `330.18` | 
MPSC | `ValueData` | `4236.05` | `315.16` | 
MPSC Buffered(100) | `Int` |  | `157.45` | `80.55` |  | `+95.48%`
MPSC Write Contention | `Int` | `5591.63` | `385.93` | `503.68` | `+1010.15%` | `-23.38%`
MPSC Write Contention | `RefData` | `6262.41` | `376.60` | 
MPSC Write Contention | `String` | `6139.55` | `390.94` | 
MPSC Write Contention | `ValueData` | `5252.34` | `419.93` | 
MPSC Write Contention Buffered(100) | `Int` |  | `395.09` | `642.26` |  | `-38.48%`
SPMC | `Int` | `3622.70` | `320.46` | `259.52` | `+1295.95%` | `+23.49%`
SPMC | `RefData` | `4114.84` | `302.77` | 
SPMC | `String` | `3890.67` | `297.05` | 
SPMC | `ValueData` | `3986.87` | `307.19` | 
SPMC Buffered(100) | `Int` |  | `219.90` | `124.92` |  | `+76.03%`
SPSC | `Int` | `2305.84` | `300.47` | `99.82` | `+2209.98%` | `+201.01%`
SPSC | `RefData` | `2418.31` | `355.01` | 
SPSC | `String` | `2350.12` | `332.97` | 
SPSC | `ValueData` | `2420.69` | `346.81` | 
SPSC Buffered(100) | `Int` |  | `439.99` | `32.32` |  | `+1261.22%`
SyncRW | `Int` |  | `327.48` | `205.30` |  | `+59.52%`

**Raw Go Benchmark Output**
```text
goos: darwin
goarch: arm64
pkg: benchmarks
cpu: Apple M5
BenchmarkSPSC-10                           	      10	 100272954 ns/op	     393 B/op	       5 allocs/op
BenchmarkSPSC-10                           	      12	 102025347 ns/op	     316 B/op	       5 allocs/op
BenchmarkSPSC-10                           	      12	  98038990 ns/op	     225 B/op	       5 allocs/op
BenchmarkSPSC-10                           	      12	  98737108 ns/op	     356 B/op	       5 allocs/op
BenchmarkSPSC-10                           	      12	 100029587 ns/op	     216 B/op	       5 allocs/op
BenchmarkMPSC-10                           	       5	 237266517 ns/op	     907 B/op	      11 allocs/op
BenchmarkMPSC-10                           	       5	 250905517 ns/op	    1643 B/op	      11 allocs/op
BenchmarkMPSC-10                           	       5	 244221625 ns/op	    1473 B/op	      12 allocs/op
BenchmarkMPSC-10                           	       5	 248658942 ns/op	    2100 B/op	      13 allocs/op
BenchmarkMPSC-10                           	       5	 243436267 ns/op	    1620 B/op	      12 allocs/op
BenchmarkSPMC-10                           	       5	 258839358 ns/op	     920 B/op	      11 allocs/op
BenchmarkSPMC-10                           	       4	 259902323 ns/op	    1368 B/op	      13 allocs/op
BenchmarkSPMC-10                           	       4	 260214886 ns/op	    1560 B/op	      12 allocs/op
BenchmarkSPMC-10                           	       4	 260728906 ns/op	    1368 B/op	      13 allocs/op
BenchmarkSPMC-10                           	       4	 257892062 ns/op	     368 B/op	       9 allocs/op
BenchmarkMPMC-10                           	       5	 245182675 ns/op	    1473 B/op	      16 allocs/op
BenchmarkMPMC-10                           	       5	 228625383 ns/op	    1169 B/op	      15 allocs/op
BenchmarkMPMC-10                           	       5	 231445842 ns/op	     926 B/op	      14 allocs/op
BenchmarkMPMC-10                           	       5	 237985958 ns/op	    1502 B/op	      16 allocs/op
BenchmarkMPMC-10                           	       5	 265417000 ns/op	    1368 B/op	      14 allocs/op
BenchmarkMPSCWriteContention-10            	       3	 473304681 ns/op	   64168 B/op	    1144 allocs/op
BenchmarkMPSCWriteContention-10            	       3	 450217056 ns/op	   66301 B/op	    1151 allocs/op
BenchmarkMPSCWriteContention-10            	       3	 462066264 ns/op	   66872 B/op	    1171 allocs/op
BenchmarkMPSCWriteContention-10            	       3	 479075514 ns/op	   63026 B/op	    1136 allocs/op
BenchmarkMPSCWriteContention-10            	       3	 653751097 ns/op	   81730 B/op	    1303 allocs/op
BenchmarkSPSCBuffered-10                   	      36	  45888530 ns/op	    1128 B/op	       5 allocs/op
BenchmarkSPSCBuffered-10                   	      33	  38004106 ns/op	    1128 B/op	       5 allocs/op
BenchmarkSPSCBuffered-10                   	      45	  25035363 ns/op	    1128 B/op	       5 allocs/op
BenchmarkSPSCBuffered-10                   	      46	  25337199 ns/op	    1128 B/op	       5 allocs/op
BenchmarkSPSCBuffered-10                   	      42	  27350754 ns/op	    1128 B/op	       5 allocs/op
BenchmarkMPSCBuffered-10                   	      18	  77956752 ns/op	    1320 B/op	       9 allocs/op
BenchmarkMPSCBuffered-10                   	      16	  80845818 ns/op	    1320 B/op	       9 allocs/op
BenchmarkMPSCBuffered-10                   	      12	  90167514 ns/op	    1320 B/op	       9 allocs/op
BenchmarkMPSCBuffered-10                   	      13	  80640811 ns/op	    1320 B/op	       9 allocs/op
BenchmarkMPSCBuffered-10                   	      15	  73124811 ns/op	    1320 B/op	       9 allocs/op
BenchmarkSPMCBuffered-10                   	      15	  80036100 ns/op	    1224 B/op	       9 allocs/op
BenchmarkSPMCBuffered-10                   	      12	 115830795 ns/op	    1224 B/op	       9 allocs/op
BenchmarkSPMCBuffered-10                   	       9	 115885287 ns/op	    1224 B/op	       9 allocs/op
BenchmarkSPMCBuffered-10                   	      12	 178193066 ns/op	    1224 B/op	       9 allocs/op
BenchmarkSPMCBuffered-10                   	       9	 134650676 ns/op	    1224 B/op	       9 allocs/op
BenchmarkMPMCBuffered-10                   	       9	 128738537 ns/op	    1416 B/op	      13 allocs/op
BenchmarkMPMCBuffered-10                   	       9	 117296884 ns/op	    1416 B/op	      13 allocs/op
BenchmarkMPMCBuffered-10                   	      14	 158546688 ns/op	    1416 B/op	      13 allocs/op
BenchmarkMPMCBuffered-10                   	      10	 139077846 ns/op	    1416 B/op	      13 allocs/op
BenchmarkMPMCBuffered-10                   	       8	 147492698 ns/op	    1416 B/op	      13 allocs/op
BenchmarkMPSCWriteContentionBuffered-10    	       2	 622269584 ns/op	   88952 B/op	    1360 allocs/op
BenchmarkMPSCWriteContentionBuffered-10    	       2	 733462500 ns/op	   70808 B/op	    1198 allocs/op
BenchmarkMPSCWriteContentionBuffered-10    	       3	 606159264 ns/op	   76445 B/op	    1248 allocs/op
BenchmarkMPSCWriteContentionBuffered-10    	       6	 619955701 ns/op	   64312 B/op	    1140 allocs/op
BenchmarkMPSCWriteContentionBuffered-10    	       3	 629465417 ns/op	   81858 B/op	    1296 allocs/op
BenchmarkSyncRw-10                         	       5	 316503150 ns/op	     128 B/op	       1 allocs/op
BenchmarkSyncRw-10                         	      19	 173398162 ns/op	     128 B/op	       1 allocs/op
BenchmarkSyncRw-10                         	      10	 147316417 ns/op	     128 B/op	       1 allocs/op
BenchmarkSyncRw-10                         	       6	 197205194 ns/op	     128 B/op	       1 allocs/op
BenchmarkSyncRw-10                         	       9	 192063287 ns/op	     128 B/op	       1 allocs/op
BenchmarkMultiSelect-10                    	       3	 555280958 ns/op	     816 B/op	      12 allocs/op
BenchmarkMultiSelect-10                    	       2	 560279688 ns/op	     816 B/op	      12 allocs/op
BenchmarkMultiSelect-10                    	       2	 593197979 ns/op	     816 B/op	      12 allocs/op
BenchmarkMultiSelect-10                    	       3	 544327736 ns/op	     816 B/op	      12 allocs/op
BenchmarkMultiSelect-10                    	       3	 510480069 ns/op	     816 B/op	      12 allocs/op
PASS
ok  	benchmarks	142.460s
```
<!-- benchmark-generated:end -->



## Future work

I have not published benchmarks on linux. Linux uses `pthread_mutex_t` and from my limited testing, performance is slightly worse than MacOS, in line compared to AsyncAlgorithms, yet still significantly slower than go. 
