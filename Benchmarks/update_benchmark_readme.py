#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
from typing import Iterable, Optional


START_MARKER = "<!-- benchmark-generated:start -->"
END_MARKER = "<!-- benchmark-generated:end -->"


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def latest_result(results_dir: Path, prefix: str, suffix: str) -> Optional[Path]:
    matches = sorted(
        (
            path
            for path in results_dir.glob(f"{prefix}*{suffix}")
            if "smoke" not in path.name
        ),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return matches[0] if matches else None


def markdown_table(headers: list[str], rows: Iterable[list[str]]) -> str:
    lines = [" | ".join(headers), " | ".join(["---"] * len(headers))]
    lines.extend(" | ".join(row) for row in rows)
    return "\n".join(lines)


def render_report_table(report: dict, library: str) -> str:
    rows = []
    for result in report["results"]:
        if result["library"] != library:
            continue
        rows.append(
            [
                result["name"],
                f"`{result['type']}`",
                f"`{result['averageMs']:.2f}`",
                f"`{result['medianMs']:.2f}`",
                f"`{result['operationsPerSecond']:.0f}`",
            ]
        )
    return markdown_table(
        ["Test", "Type", "Avg (ms)", "Median (ms)", "Ops/s"],
        rows,
    )


def render_swift_comparison(baseline: dict, candidate: dict) -> str:
    baseline_results = {
        (result["library"], result["name"], result["type"]): result
        for result in baseline["results"]
    }
    candidate_results = {
        (result["library"], result["name"], result["type"]): result
        for result in candidate["results"]
    }

    rows = []
    for key in sorted(set(baseline_results) & set(candidate_results)):
        before = baseline_results[key]["averageMs"]
        after = candidate_results[key]["averageMs"]
        delta = ((after - before) / before) * 100
        library, name, result_type = key
        rows.append(
            [
                library,
                name,
                f"`{result_type}`",
                f"`{before:.2f}`",
                f"`{after:.2f}`",
                f"`{delta:+.2f}%`",
            ]
        )

    return markdown_table(
        ["Library", "Test", "Type", "Baseline Avg (ms)", "Candidate Avg (ms)", "Delta %"],
        rows,
    )


def render_library_comparison(reports: list[dict]) -> str:
    merged: dict[tuple[str, str], dict[str, dict]] = {}
    for report in reports:
        for result in report["results"]:
            merged.setdefault((result["name"], result["type"]), {})[result["library"]] = result

    libraries = sorted({result["library"] for report in reports for result in report["results"]})
    headers = ["Test", "Type"] + [f"{library} Avg (ms)" for library in libraries]
    if "Go" in libraries:
        headers += [f"{library} vs Go" for library in libraries if library != "Go"]

    rows = []
    for (name, result_type), values in sorted(merged.items()):
        if len(values) < 2:
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
                row.append(
                    f"`{((result['averageMs'] - go_result['averageMs']) / go_result['averageMs']) * 100:+.2f}%`"
                    if result
                    else ""
                )

        rows.append(row)

    return markdown_table(headers, rows)


def render_environment(report: dict, label: str) -> str:
    config = report["config"]
    lines = [
        f"- {label} toolchain: `{report['toolchain']}`",
        f"- {label} host: `{report['host']}`",
        f"- {label} rounds: `{config['rounds']}` measured, `{config['warmupRounds']}` warmup",
        f"- {label} writes: `{config['writes']}`, sync writes: `{config['syncWrites']}`, select writes/channel: `{config['selectWritesPerChannel']}`, buffer: `{config['buffer']}`",
    ]
    return "\n".join(lines)


def render_generated_section(
    swift_report: dict,
    baseline_swift_report: Optional[dict],
    go_report: Optional[dict],
    go_raw_text: Optional[str],
    source_paths: dict[str, Optional[Path]],
) -> str:
    parts = [
        START_MARKER,
        "## Generated Results",
        "",
        "These sections are generated from benchmark result files in `Benchmarks/results/`.",
        "",
        "**Environment**",
        render_environment(swift_report, "Swift"),
    ]

    if baseline_swift_report:
        parts.extend(
            [
                render_environment(baseline_swift_report, "Baseline Swift"),
                "",
                f"Baseline Swift report: `{source_paths['baseline_swift'].as_posix()}`",
                f"Candidate Swift report: `{source_paths['swift'].as_posix()}`",
                "",
                "**Swift Toolchain Comparison**",
                render_swift_comparison(baseline_swift_report, swift_report),
            ]
        )

    parts.extend(
        [
            "",
            "**AsyncChannels Results**",
            render_report_table(swift_report, "AsyncChannels"),
        ]
    )

    if any(result["library"] == "AsyncAlgorithms" for result in swift_report["results"]):
        parts.extend(
            [
                "",
                "**AsyncAlgorithms Results**",
                render_report_table(swift_report, "AsyncAlgorithms"),
            ]
        )

    if go_report:
        parts.extend(
            [
                "",
                render_environment(go_report, "Go"),
                f"Go report: `{source_paths['go'].as_posix()}`",
                "",
                "**Cross-Library Comparison**",
                render_library_comparison([swift_report, go_report]),
            ]
        )

    if go_raw_text is not None:
        parts.extend(
            [
                "",
                "**Raw Go Benchmark Output**",
                "```text",
                go_raw_text.rstrip(),
                "```",
            ]
        )

    parts.append(END_MARKER)
    return "\n".join(parts)


def replace_generated_section(readme_text: str, generated_text: str) -> str:
    start = readme_text.find(START_MARKER)
    end = readme_text.find(END_MARKER)
    if start == -1 or end == -1:
        return f"{readme_text.rstrip()}\n\n{generated_text}\n"
    end += len(END_MARKER)
    return f"{readme_text[:start].rstrip()}\n\n{generated_text}\n{readme_text[end:]}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--readme", default="Benchmarks/Readme.md")
    parser.add_argument("--results-dir", default="Benchmarks/results")
    parser.add_argument("--swift")
    parser.add_argument("--baseline-swift")
    parser.add_argument("--go")
    parser.add_argument("--go-raw")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    readme_path = Path(args.readme)
    results_dir = Path(args.results_dir)

    swift_path = Path(args.swift) if args.swift else latest_result(results_dir, "swift-", ".json")
    baseline_swift_path = Path(args.baseline_swift) if args.baseline_swift else latest_result(results_dir, "swift-6.2", ".json")
    go_path = Path(args.go) if args.go else latest_result(results_dir, "go_", ".json")
    go_raw_path = Path(args.go_raw) if args.go_raw else latest_result(results_dir, "go_", ".txt")

    if swift_path is None:
        raise SystemExit("No Swift benchmark report found")

    swift_report = load_json(swift_path)
    baseline_swift_report = load_json(baseline_swift_path) if baseline_swift_path and baseline_swift_path != swift_path else None
    go_report = load_json(go_path) if go_path else None
    go_raw_text = go_raw_path.read_text(encoding="utf-8") if go_raw_path else None

    generated = render_generated_section(
        swift_report=swift_report,
        baseline_swift_report=baseline_swift_report,
        go_report=go_report,
        go_raw_text=go_raw_text,
        source_paths={
            "swift": swift_path,
            "baseline_swift": baseline_swift_path,
            "go": go_path,
            "go_raw": go_raw_path,
        },
    )

    updated = replace_generated_section(readme_path.read_text(encoding="utf-8"), generated)
    readme_path.write_text(updated, encoding="utf-8")
    print(f"Updated {readme_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
