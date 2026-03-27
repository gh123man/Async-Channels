#!/usr/bin/env python3

import json
import re
import statistics
import sys
from pathlib import Path


BENCHMARK_NAME_MAP = {
    "SPSC": "SPSC",
    "MPSC": "MPSC",
    "SPMC": "SPMC",
    "MPMC": "MPMC",
    "MPSCWriteContention": "MPSC Write Contention",
    "SPSCBuffered": "SPSC Buffered({buffer})",
    "MPSCBuffered": "MPSC Buffered({buffer})",
    "SPMCBuffered": "SPMC Buffered({buffer})",
    "MPMCBuffered": "MPMC Buffered({buffer})",
    "MPSCWriteContentionBuffered": "MPSC Write Contention Buffered({buffer})",
    "SyncRw": "SyncRW",
    "MultiSelect": "Channel multi-select",
}

OPERATIONS_MAP = {
    "SPSC": "writes",
    "MPSC": "writes",
    "SPMC": "writes",
    "MPMC": "writes",
    "MPSCWriteContention": "writes",
    "SPSCBuffered": "writes",
    "MPSCBuffered": "writes",
    "SPMCBuffered": "writes",
    "MPMCBuffered": "writes",
    "MPSCWriteContentionBuffered": "writes",
    "SyncRw": "sync_writes",
    "MultiSelect": "select_total",
}

LINE_RE = re.compile(
    r"^Benchmark(?P<name>[A-Za-z0-9]+)-\d+\s+"
    r"(?P<iters>\d+)\s+"
    r"(?P<ns_op>\d+(?:\.\d+)?) ns/op\s+"
    r"(?P<bytes_op>\d+) B/op\s+"
    r"(?P<allocs_op>\d+) allocs/op$"
)


def usage() -> int:
    print(
        "usage: parse_go_benchmarks.py <raw.txt> <toolchain> <writes> <sync_writes> <select_writes> <buffer>",
        file=sys.stderr,
    )
    return 1


def median(values: list[float]) -> float:
    return statistics.median(values)


def main() -> int:
    if len(sys.argv) != 7:
        return usage()

    raw_path = Path(sys.argv[1])
    toolchain = sys.argv[2]
    writes = int(sys.argv[3])
    sync_writes = int(sys.argv[4])
    select_writes = int(sys.argv[5])
    buffer = int(sys.argv[6])

    metadata: dict[str, str] = {}
    grouped: dict[str, list[dict[str, float]]] = {}

    for line in raw_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("goos:"):
            metadata["goos"] = line.split(":", 1)[1].strip()
        elif line.startswith("goarch:"):
            metadata["goarch"] = line.split(":", 1)[1].strip()
        elif line.startswith("pkg:"):
            metadata["pkg"] = line.split(":", 1)[1].strip()
        elif line.startswith("cpu:"):
            metadata["cpu"] = line.split(":", 1)[1].strip()

        match = LINE_RE.match(line.strip())
        if not match:
            continue

        grouped.setdefault(match.group("name"), []).append(
            {
                "ns_op": float(match.group("ns_op")),
                "bytes_op": float(match.group("bytes_op")),
                "allocs_op": float(match.group("allocs_op")),
            }
        )

    config = {
        "rounds": max((len(samples) for samples in grouped.values()), default=0),
        "warmupRounds": 0,
        "writes": writes,
        "syncWrites": sync_writes,
        "selectWritesPerChannel": select_writes,
        "buffer": buffer,
        "includeAsyncAlgorithms": False,
        "outputFormat": "json",
    }

    operation_values = {
        "writes": writes,
        "sync_writes": sync_writes,
        "select_total": select_writes * 6,
    }

    results = []
    for raw_name, samples in sorted(grouped.items()):
        scenario_name_template = BENCHMARK_NAME_MAP[raw_name]
        scenario_name = scenario_name_template.format(buffer=buffer)
        sample_ms = [sample["ns_op"] / 1_000_000 for sample in samples]
        avg_ms = statistics.fmean(sample_ms)
        ops_count = operation_values[OPERATIONS_MAP[raw_name]]

        results.append(
            {
                "library": "Go",
                "name": scenario_name,
                "type": "Int",
                "operations": ops_count,
                "rounds": len(samples),
                "warmupRounds": 0,
                "averageMs": avg_ms,
                "medianMs": median(sample_ms),
                "minMs": min(sample_ms),
                "maxMs": max(sample_ms),
                "operationsPerSecond": ops_count / (avg_ms / 1000),
                "samplesMs": sample_ms,
                "bytesPerOp": statistics.fmean(sample["bytes_op"] for sample in samples),
                "allocsPerOp": statistics.fmean(sample["allocs_op"] for sample in samples),
            }
        )

    report = {
        "generatedAt": None,
        "toolchain": toolchain,
        "host": metadata.get("cpu", "unknown"),
        "config": config,
        "goMetadata": metadata,
        "results": results,
    }

    json.dump(report, sys.stdout, indent=2, sort_keys=True)
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
