# AGENTS.md

This repository is a Swift package implementing async channel primitives and a benchmark suite used to drive performance work.

## Priorities

- Go is the performance baseline.
- `AsyncChannels` is the implementation under optimization.
- `AsyncAlgorithms` is a useful secondary comparison, but not the golden target.
- Prefer changes that improve the full benchmark suite, not just one synthetic case.

## Repository Layout

- [Package.swift](Package.swift): root Swift package manifest.
- [Sources/AsyncChannels](Sources/AsyncChannels): library implementation.
- [Tests/AsyncChannelsTests](Tests/AsyncChannelsTests): behavior, type, and README examples.
- [Benchmarks](Benchmarks): Swift and Go benchmark harnesses and benchmark docs.
- [Examples/ImageConverter](Examples/ImageConverter): example package using the library.

## Code Navigation

Start here when working on channel performance or behavior:

- [Channel.swift](Sources/AsyncChannels/Channel.swift): public `Channel<T>` API, send/receive operators, sync helpers, close.
- [ThrowingChannel.swift](Sources/AsyncChannels/ThrowingChannel.swift): throwing variant of the channel API.
- [ChannelInternal.swift](Sources/AsyncChannels/ChannelInternal.swift): core queueing, continuation handoff, buffering, close behavior, and payload boxing.
- [Select.swift](Sources/AsyncChannels/Select.swift): select implementation and dynamic case handling.
- [FastLock.swift](Sources/AsyncChannels/FastLock.swift): platform-specific lock implementation. On Darwin it uses `os_unfair_lock`; on Linux it uses `pthread_mutex_t`.

Useful test files:

- [BehaviorTests.swift](Tests/AsyncChannelsTests/BehaviorTests.swift): stress and concurrency behavior tests.
- [TypeTests.swift](Tests/AsyncChannelsTests/TypeTests.swift): type behavior and sendability-focused tests.
- [ReadmeTests.swift](Tests/AsyncChannelsTests/ReadmeTests.swift): examples mirrored from the README.

## Running Tests

From the repo root:

```bash
swift test
```

If you are validating a specific installed Swift toolchain:

```bash
xcrun swift test
$HOME/.swiftly/bin/swift test
```

Thread Sanitizer:

```bash
swift test --sanitize=thread
```

Current status on this machine/toolchain:

- `swift test --sanitize=thread` on Swift 6.2.3 still reports continuation-boundary races in `ChannelInternal.swift`.
- The reports land on `withUnsafeContinuation`/`resume` interactions rather than unlocked channel state.
- A real close-path bug did exist separately: blocked senders were not resumed on `close()`. Keep coverage for that behavior.
- Treat the remaining sanitizer warnings as unresolved and tooling-suspect, not as a reason by themselves to accept major benchmark regressions.
- Track follow-up investigation in GitHub issue [#25](https://github.com/gh123man/Async-Channels/issues/25).
- If you investigate them further, capture the exact toolchain, platform, reproduction command, and stack traces in a GitHub issue before changing hot paths.

## Benchmark Layout

Swift benchmark files:

- [Benchmarks/Sources/Benchmarks/main.swift](Benchmarks/Sources/Benchmarks/main.swift): configurable Swift benchmark executable.
- [Benchmarks/run_swift_benchmarks.sh](Benchmarks/run_swift_benchmarks.sh): wrapper that runs the Swift benchmark suite and writes JSON reports.
- [Benchmarks/compare_swift_benchmarks.py](Benchmarks/compare_swift_benchmarks.py): compares two Swift JSON reports.

Go benchmark files:

- [Benchmarks/golang/benchmark_test.go](Benchmarks/golang/benchmark_test.go): Go benchmark suite.
- [Benchmarks/run_go_benchmarks.sh](Benchmarks/run_go_benchmarks.sh): wrapper that runs Go benchmarks and writes raw text plus normalized JSON.
- [Benchmarks/parse_go_benchmarks.py](Benchmarks/parse_go_benchmarks.py): converts `go test -bench` output to JSON.
- [Benchmarks/compare_library_benchmarks.py](Benchmarks/compare_library_benchmarks.py): compares Go vs Swift reports.

README generation:

- [Benchmarks/update_benchmark_readme.py](Benchmarks/update_benchmark_readme.py): rebuilds the generated benchmark section in the README from result files.
- [Benchmarks/update_benchmark_readme.sh](Benchmarks/update_benchmark_readme.sh): wrapper for the README generator.
- [Benchmarks/Readme.md](Benchmarks/Readme.md): benchmark documentation with generated result tables.

## Running Benchmarks

Run Swift benchmarks with the system toolchain:

```bash
BENCHMARK_NAME=swift-current Benchmarks/run_swift_benchmarks.sh
```

Run Swift benchmarks with a specific Swiftly toolchain:

```bash
BENCHMARK_NAME=swift-6.3.0 SWIFT_BIN=$HOME/.swiftly/bin/swift Benchmarks/run_swift_benchmarks.sh
```

Run Go benchmarks:

```bash
BENCHMARK_NAME=go-1.26.1 Benchmarks/run_go_benchmarks.sh
```

Important knobs:

- `ROUNDS`: measured rounds for Swift benchmarks.
- `WARMUP`: warmup rounds for Swift benchmarks.
- `COUNT`: benchmark count for Go.
- `WRITES`
- `SYNC_WRITES`
- `SELECT_WRITES`
- `BUFFER`
- `UPDATE_README=1`: refresh [Benchmarks/Readme.md](Benchmarks/Readme.md) after the run.

Examples:

```bash
UPDATE_README=1 BENCHMARK_NAME=swift-6.3.0 SWIFT_BIN=$HOME/.swiftly/bin/swift Benchmarks/run_swift_benchmarks.sh
UPDATE_README=1 BENCHMARK_NAME=go-1.26.1 Benchmarks/run_go_benchmarks.sh
```

## Comparing Results

Compare two Swift toolchains:

```bash
Benchmarks/compare_swift_benchmarks.py \
  Benchmarks/results/swift-6.2.3-<timestamp>.json \
  Benchmarks/results/swift-6.3.0-<timestamp>.json
```

Compare Swift vs Go on the same machine:

```bash
Benchmarks/compare_library_benchmarks.py \
  Benchmarks/results/swift-6.3.0-<timestamp>.json \
  Benchmarks/results/go-1.26.1-<timestamp>.json
```

The generated README treats Go as the primary baseline near the top.

## Updating Benchmark Docs

Regenerate the benchmark README from the latest local result files:

```bash
Benchmarks/update_benchmark_readme.sh
```

You can also pin exact result files:

```bash
SWIFT_REPORT=Benchmarks/results/swift-6.3.0-<timestamp>.json \
GO_REPORT=Benchmarks/results/go-1.26.1-<timestamp>.json \
GO_RAW_REPORT=Benchmarks/results/go-1.26.1-<timestamp>.txt \
Benchmarks/update_benchmark_readme.sh
```

`Benchmarks/results/` is gitignored. Result files are intentionally local unless someone explicitly decides to commit them elsewhere.

## Tooling Notes

- Go is installed via Homebrew on this machine.
- If `go` is missing, install it with:

```bash
brew install go
```

- Swift benchmark runs use separate scratch paths per toolchain in `/tmp/asyncchannels-benchmarks` to avoid mixed-build artifacts.

## Practical Advice For Performance Work

- If you change queueing, continuation handoff, locking, or select behavior, rerun the full benchmark suite, not only one scenario.
- Use a reduced Swift benchmark config while iterating on correctness work, then rerun the full suite once the design is settled.
- When benchmarking, keep the machine and workload constant. Cross-machine comparisons are not useful.
- The most important files for hot-path performance work are [ChannelInternal.swift](Sources/AsyncChannels/ChannelInternal.swift), [Select.swift](Sources/AsyncChannels/Select.swift), and [FastLock.swift](Sources/AsyncChannels/FastLock.swift).
