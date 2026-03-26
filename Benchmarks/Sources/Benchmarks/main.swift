import Foundation
import Dispatch
import AsyncAlgorithms
import AsyncChannels

protocol BenchmarkPayload: Sendable {
    init()
}

extension Int: BenchmarkPayload {}

extension String: BenchmarkPayload {
    init() {
        self.init("My test string for benchmarking")
    }
}

struct ValueData: BenchmarkPayload {
    let foo: String
    let bar: Int

    init() {
        foo = "My test string for benchmarking"
        bar = 1234
    }
}

final class RefData: BenchmarkPayload {
    let foo: String
    let bar: Int

    required init() {
        foo = "My test string for benchmarking"
        bar = 1234
    }
}

enum BenchmarkError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case missingValue(String)

    var description: String {
        switch self {
        case .invalidArgument(let argument):
            return "Invalid argument: \(argument)"
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        }
    }
}

enum OutputFormat: String, Codable {
    case markdown
    case json
}

struct BenchmarkConfig: Codable {
    let rounds: Int
    let warmupRounds: Int
    let writes: Int
    let syncWrites: Int
    let selectWritesPerChannel: Int
    let buffer: Int
    let includeAsyncAlgorithms: Bool
    let outputFormat: OutputFormat

    static let `default` = BenchmarkConfig(
        rounds: 10,
        warmupRounds: 1,
        writes: 1_000_000,
        syncWrites: 5_000_000,
        selectWritesPerChannel: 100_000,
        buffer: 100,
        includeAsyncAlgorithms: true,
        outputFormat: .markdown
    )

    init(
        rounds: Int,
        warmupRounds: Int,
        writes: Int,
        syncWrites: Int,
        selectWritesPerChannel: Int,
        buffer: Int,
        includeAsyncAlgorithms: Bool,
        outputFormat: OutputFormat
    ) {
        self.rounds = rounds
        self.warmupRounds = warmupRounds
        self.writes = writes
        self.syncWrites = syncWrites
        self.selectWritesPerChannel = selectWritesPerChannel
        self.buffer = buffer
        self.includeAsyncAlgorithms = includeAsyncAlgorithms
        self.outputFormat = outputFormat
    }

    init(arguments: [String]) throws {
        var rounds = Self.default.rounds
        var warmupRounds = Self.default.warmupRounds
        var writes = Self.default.writes
        var syncWrites = Self.default.syncWrites
        var selectWritesPerChannel = Self.default.selectWritesPerChannel
        var buffer = Self.default.buffer
        var includeAsyncAlgorithms = Self.default.includeAsyncAlgorithms
        var outputFormat = Self.default.outputFormat

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--rounds":
                rounds = try Self.parseInt(arguments, index: &index, flag: argument)
            case "--warmup":
                warmupRounds = try Self.parseInt(arguments, index: &index, flag: argument)
            case "--writes":
                writes = try Self.parseInt(arguments, index: &index, flag: argument)
            case "--sync-writes":
                syncWrites = try Self.parseInt(arguments, index: &index, flag: argument)
            case "--select-writes":
                selectWritesPerChannel = try Self.parseInt(arguments, index: &index, flag: argument)
            case "--buffer":
                buffer = try Self.parseInt(arguments, index: &index, flag: argument)
            case "--skip-async-algorithms":
                includeAsyncAlgorithms = false
            case "--format":
                index += 1
                guard index < arguments.count else {
                    throw BenchmarkError.missingValue(argument)
                }
                guard let format = OutputFormat(rawValue: arguments[index]) else {
                    throw BenchmarkError.invalidArgument("\(argument) \(arguments[index])")
                }
                outputFormat = format
            case "--help", "-h":
                printUsage()
                Foundation.exit(0)
            default:
                throw BenchmarkError.invalidArgument(argument)
            }
            index += 1
        }

        self.init(
            rounds: rounds,
            warmupRounds: warmupRounds,
            writes: writes,
            syncWrites: syncWrites,
            selectWritesPerChannel: selectWritesPerChannel,
            buffer: buffer,
            includeAsyncAlgorithms: includeAsyncAlgorithms,
            outputFormat: outputFormat
        )
    }

    private static func parseInt(_ arguments: [String], index: inout Int, flag: String) throws -> Int {
        index += 1
        guard index < arguments.count else {
            throw BenchmarkError.missingValue(flag)
        }
        guard let value = Int(arguments[index]) else {
            throw BenchmarkError.invalidArgument("\(flag) \(arguments[index])")
        }
        return value
    }
}

struct BenchmarkResult: Codable {
    let library: String
    let name: String
    let type: String
    let operations: Int
    let rounds: Int
    let warmupRounds: Int
    let averageMs: Double
    let medianMs: Double
    let minMs: Double
    let maxMs: Double
    let operationsPerSecond: Double
    let samplesMs: [Double]
}

struct BenchmarkReport: Codable {
    let generatedAt: String
    let toolchain: String
    let host: String
    let config: BenchmarkConfig
    let results: [BenchmarkResult]
}

func printUsage() {
    let usage = """
    Usage: Benchmarks [options]

      --format markdown|json
      --rounds <count>
      --warmup <count>
      --writes <count>
      --sync-writes <count>
      --select-writes <count>
      --buffer <count>
      --skip-async-algorithms
      --help
    """
    print(usage)
}

func measureScenario<T>(
    library: String,
    name: String,
    type: T.Type,
    operations: Int,
    config: BenchmarkConfig,
    block: () async -> Void
) async -> BenchmarkResult {
    for _ in 0..<config.warmupRounds {
        await block()
    }

    var samplesMs = [Double]()
    samplesMs.reserveCapacity(config.rounds)

    for _ in 0..<config.rounds {
        let start = DispatchTime.now().uptimeNanoseconds
        await block()
        let elapsedNs = DispatchTime.now().uptimeNanoseconds - start
        samplesMs.append(Double(elapsedNs) / 1_000_000)
    }

    let averageMs = samplesMs.reduce(0, +) / Double(samplesMs.count)
    let sorted = samplesMs.sorted()
    let medianMs: Double
    if sorted.count.isMultiple(of: 2) {
        let mid = sorted.count / 2
        medianMs = (sorted[mid - 1] + sorted[mid]) / 2
    } else {
        medianMs = sorted[sorted.count / 2]
    }

    let operationsPerSecond = Double(operations) / (averageMs / 1000)

    return BenchmarkResult(
        library: library,
        name: name,
        type: String(describing: type),
        operations: operations,
        rounds: config.rounds,
        warmupRounds: config.warmupRounds,
        averageMs: averageMs,
        medianMs: medianMs,
        minMs: sorted.first ?? 0,
        maxMs: sorted.last ?? 0,
        operationsPerSecond: operationsPerSecond,
        samplesMs: samplesMs
    )
}

func run<T: BenchmarkPayload>(_ type: T.Type, config: BenchmarkConfig) async -> [BenchmarkResult] {
    var results = [BenchmarkResult]()

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "SPSC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 1, consumers: 1, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "MPSC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 5, consumers: 1, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "SPMC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 1, consumers: 5, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "MPMC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 5, consumers: 5, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "MPSC Write Contention",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 1000, consumers: 1, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "SPSC Buffered(\(config.buffer))",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 1, consumers: 1, writes: config.writes, buffer: config.buffer)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "MPSC Buffered(\(config.buffer))",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 5, consumers: 1, writes: config.writes, buffer: config.buffer)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "SPMC Buffered(\(config.buffer))",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 1, consumers: 5, writes: config.writes, buffer: config.buffer)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "MPMC Buffered(\(config.buffer))",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 5, consumers: 5, writes: config.writes, buffer: config.buffer)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "MPSC Write Contention Buffered(\(config.buffer))",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMC(type, producers: 1000, consumers: 1, writes: config.writes, buffer: config.buffer)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "SyncRW",
        type: type,
        operations: config.syncWrites,
        config: config
    ) {
        await runSyncRw(type, writes: config.syncWrites)
    })

    results.append(await measureScenario(
        library: "AsyncChannels",
        name: "Channel multi-select",
        type: type,
        operations: config.selectWritesPerChannel * 6,
        config: config
    ) {
        await runMultiSelect(type, writesPerChannel: config.selectWritesPerChannel)
    })

    return results
}

func runAsyncAlgorithms<T: BenchmarkPayload>(_ type: T.Type, config: BenchmarkConfig) async -> [BenchmarkResult] {
    var results = [BenchmarkResult]()

    results.append(await measureScenario(
        library: "AsyncAlgorithms",
        name: "SPSC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMCAsyncAlg(type, producers: 1, consumers: 1, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncAlgorithms",
        name: "MPSC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMCAsyncAlg(type, producers: 5, consumers: 1, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncAlgorithms",
        name: "SPMC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMCAsyncAlg(type, producers: 1, consumers: 5, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncAlgorithms",
        name: "MPMC",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMCAsyncAlg(type, producers: 5, consumers: 5, writes: config.writes)
    })

    results.append(await measureScenario(
        library: "AsyncAlgorithms",
        name: "MPSC Write Contention",
        type: type,
        operations: config.writes,
        config: config
    ) {
        await runMPMCAsyncAlg(type, producers: 1000, consumers: 1, writes: config.writes)
    })

    return results
}

func runMPMC<T: BenchmarkPayload>(
    _ type: T.Type,
    producers: Int,
    consumers: Int,
    writes: Int,
    buffer: Int = 0
) async {
    let channel = Channel<T>(capacity: buffer)

    async let writeGroup: () = withTaskGroup(of: Void.self) { group in
        for _ in 0..<producers {
            group.addTask {
                for _ in 0..<(writes / producers) {
                    await channel <- T()
                }
            }
        }
    }

    async let readGroup: () = withTaskGroup(of: Void.self) { group in
        for _ in 0..<consumers {
            group.addTask {
                for await _ in channel {}
            }
        }
    }

    await writeGroup
    channel.close()
    await readGroup
}

func runSyncRw<T: BenchmarkPayload>(_ type: T.Type, writes: Int) async {
    let channel = Channel<T>(capacity: 1)
    for _ in 0..<writes {
        await channel <- T()
        await <-channel
    }
}

func runMultiSelect<T: BenchmarkPayload>(_ type: T.Type, writesPerChannel: Int) async {
    let channels = [
        Channel<T>(),
        Channel<T>(),
        Channel<T>(),
        Channel<T>(),
        Channel<T>(),
        Channel<T>()
    ]

    for channel in channels {
        Task {
            for _ in 0..<writesPerChannel {
                await channel <- T()
            }
        }
    }

    var received = 0
    let totalWrites = writesPerChannel * channels.count

    while received < totalWrites {
        await select {
            receive(channels[0]) { received += 1 }
            receive(channels[1]) { received += 1 }
            receive(channels[2]) { received += 1 }
            receive(channels[3]) { received += 1 }
            receive(channels[4]) { received += 1 }
            receive(channels[5]) { received += 1 }
        }
    }
}

func runMPMCAsyncAlg<T: BenchmarkPayload>(
    _ type: T.Type,
    producers: Int,
    consumers: Int,
    writes: Int
) async {
    let channel = AsyncChannel<T>()

    async let writeGroup: () = withTaskGroup(of: Void.self) { group in
        for _ in 0..<producers {
            group.addTask {
                for _ in 0..<(writes / producers) {
                    await channel.send(T())
                }
            }
        }
    }

    async let readGroup: () = withTaskGroup(of: Void.self) { group in
        for _ in 0..<consumers {
            group.addTask {
                for await _ in channel {}
            }
        }
    }

    await writeGroup
    channel.finish()
    await readGroup
}

func generateReport(config: BenchmarkConfig) async -> BenchmarkReport {
    var results = [BenchmarkResult]()

    let payloadTypes: [any BenchmarkPayload.Type] = [
        Int.self,
        String.self,
        ValueData.self,
        RefData.self
    ]

    for payloadType in payloadTypes {
        switch payloadType {
        case is Int.Type:
            results.append(contentsOf: await run(Int.self, config: config))
            if config.includeAsyncAlgorithms {
                results.append(contentsOf: await runAsyncAlgorithms(Int.self, config: config))
            }
        case is String.Type:
            results.append(contentsOf: await run(String.self, config: config))
            if config.includeAsyncAlgorithms {
                results.append(contentsOf: await runAsyncAlgorithms(String.self, config: config))
            }
        case is ValueData.Type:
            results.append(contentsOf: await run(ValueData.self, config: config))
            if config.includeAsyncAlgorithms {
                results.append(contentsOf: await runAsyncAlgorithms(ValueData.self, config: config))
            }
        case is RefData.Type:
            results.append(contentsOf: await run(RefData.self, config: config))
            if config.includeAsyncAlgorithms {
                results.append(contentsOf: await runAsyncAlgorithms(RefData.self, config: config))
            }
        default:
            break
        }
    }

    let formatter = ISO8601DateFormatter()
    let toolchain = ProcessInfo.processInfo.environment["BENCHMARK_TOOLCHAIN_LABEL"] ?? "unknown"

    return BenchmarkReport(
        generatedAt: formatter.string(from: Date()),
        toolchain: toolchain,
        host: ProcessInfo.processInfo.hostName,
        config: config,
        results: results
    )
}

func formatMarkdown(_ report: BenchmarkReport) -> String {
    var lines = [String]()
    lines.append("")
    lines.append("Toolchain: \(report.toolchain)")
    lines.append("Host: \(report.host)")
    lines.append("Rounds: \(report.config.rounds), warmup: \(report.config.warmupRounds)")
    lines.append("Writes: \(report.config.writes), sync writes: \(report.config.syncWrites), select writes/channel: \(report.config.selectWritesPerChannel)")
    lines.append("")
    lines.append("Library | Test | Type | Avg (ms) | Median (ms) | Min (ms) | Max (ms) | Ops/s")
    lines.append("--------|------|------|----------|-------------|----------|----------|------")

    for result in report.results {
        lines.append(
            "\(result.library) | \(result.name) | `\(result.type)` | `\(String(format: "%.2f", result.averageMs))` | `\(String(format: "%.2f", result.medianMs))` | `\(String(format: "%.2f", result.minMs))` | `\(String(format: "%.2f", result.maxMs))` | `\(String(format: "%.0f", result.operationsPerSecond))`"
        )
    }

    return lines.joined(separator: "\n")
}

do {
    let config = try BenchmarkConfig(arguments: Array(CommandLine.arguments.dropFirst()))
    let report = await generateReport(config: config)

    switch config.outputFormat {
    case .markdown:
        print(formatMarkdown(report))
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        guard let text = String(data: data, encoding: .utf8) else {
            throw BenchmarkError.invalidArgument("Unable to encode JSON output")
        }
        print(text)
    }
} catch {
    fputs("\(error)\n", stderr)
    printUsage()
    Foundation.exit(1)
}
