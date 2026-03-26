#!/usr/bin/env bash

set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-Benchmarks/results}"
README_PATH="${README_PATH:-Benchmarks/Readme.md}"
SWIFT_REPORT="${SWIFT_REPORT:-}"
BASELINE_SWIFT_REPORT="${BASELINE_SWIFT_REPORT:-}"
GO_REPORT="${GO_REPORT:-}"
GO_RAW_REPORT="${GO_RAW_REPORT:-}"

CMD=(Benchmarks/update_benchmark_readme.py --readme "${README_PATH}" --results-dir "${RESULTS_DIR}")

if [[ -n "${SWIFT_REPORT}" ]]; then
  CMD+=(--swift "${SWIFT_REPORT}")
fi

if [[ -n "${BASELINE_SWIFT_REPORT}" ]]; then
  CMD+=(--baseline-swift "${BASELINE_SWIFT_REPORT}")
fi

if [[ -n "${GO_REPORT}" ]]; then
  CMD+=(--go "${GO_REPORT}")
fi

if [[ -n "${GO_RAW_REPORT}" ]]; then
  CMD+=(--go-raw "${GO_RAW_REPORT}")
fi

"${CMD[@]}"
