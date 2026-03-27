#!/usr/bin/env python3

import json
import sys
from collections import defaultdict


def sort_libraries(libraries: set[str]) -> list[str]:
    preferred = ["Go", "AsyncChannels", "AsyncAlgorithms"]
    remainder = sorted(library for library in libraries if library not in preferred)
    return [library for library in preferred if library in libraries] + remainder


def load(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: compare_library_benchmarks.py <report.json> [report.json ...]", file=sys.stderr)
        return 1

    merged = defaultdict(dict)
    for report_path in sys.argv[1:]:
        report = load(report_path)
        for result in report["results"]:
            merged[(result["name"], result["type"])][result["library"]] = result

    libraries = sort_libraries({library for values in merged.values() for library in values})
    if not libraries:
        return 0

    header = ["Test", "Type"] + [f"{library} Avg (ms)" for library in libraries]
    if "Go" in libraries:
        header += [f"{library} vs Go" for library in libraries if library != "Go"]
    print(" | ".join(header))
    print(" | ".join(["---"] * len(header)))

    for (name, result_type), values in sorted(merged.items()):
        if len(values) < 2:
            continue
        if "Go" in libraries and "Go" not in values:
            continue
        row = [name, f"`{result_type}`"]
        for library in libraries:
            result = values.get(library)
            row.append(f"`{result['averageMs']:.2f}`" if result else "")

        go_result = values.get("Go")
        if go_result:
            for library in libraries:
                if library == "Go":
                    continue
                result = values.get(library)
                if result:
                    delta = ((result["averageMs"] - go_result["averageMs"]) / go_result["averageMs"]) * 100
                    row.append(f"`{delta:+.2f}%`")
                else:
                    row.append("")

        print(" | ".join(row))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
