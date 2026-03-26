#!/usr/bin/env python3

import json
import sys
from pathlib import Path


def load(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def key(result: dict) -> tuple[str, str, str]:
    return (result["library"], result["name"], result["type"])


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: compare_swift_benchmarks.py <baseline.json> <candidate.json>", file=sys.stderr)
        return 1

    baseline = load(sys.argv[1])
    candidate = load(sys.argv[2])

    baseline_results = {key(result): result for result in baseline["results"]}
    candidate_results = {key(result): result for result in candidate["results"]}

    shared_keys = sorted(set(baseline_results) & set(candidate_results))

    print(f"Baseline: {Path(sys.argv[1]).name} ({baseline['toolchain']})")
    print(f"Candidate: {Path(sys.argv[2]).name} ({candidate['toolchain']})")
    print()
    print("Library | Test | Type | Baseline Avg (ms) | Candidate Avg (ms) | Delta %")
    print("--------|------|------|-------------------|--------------------|--------")

    for current_key in shared_keys:
        before = baseline_results[current_key]["averageMs"]
        after = candidate_results[current_key]["averageMs"]
        delta = ((after - before) / before) * 100
        library, name, result_type = current_key
        print(
            f"{library} | {name} | `{result_type}` | `{before:.2f}` | `{after:.2f}` | `{delta:+.2f}%`"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
