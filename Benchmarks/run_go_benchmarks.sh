#!/usr/bin/env bash

set -euo pipefail

GO_BIN="${GO_BIN:-go}"
COUNT="${COUNT:-5}"
WRITES="${WRITES:-1000000}"
SYNC_WRITES="${SYNC_WRITES:-5000000}"
SELECT_WRITES="${SELECT_WRITES:-100000}"
BUFFER="${BUFFER:-100}"
OUTPUT_DIR="${OUTPUT_DIR:-Benchmarks/results}"
BENCHMARK_NAME="${BENCHMARK_NAME:-}"

mkdir -p "${OUTPUT_DIR}"

if [[ -z "${BENCHMARK_NAME}" ]]; then
  BENCHMARK_NAME="$("${GO_BIN}" version | tr ' /()' '_' | tr -cd '[:alnum:]_.-')"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RAW_OUTPUT_PATH="${OUTPUT_DIR}/${BENCHMARK_NAME}-${TIMESTAMP}.txt"
JSON_OUTPUT_PATH="${OUTPUT_DIR}/${BENCHMARK_NAME}-${TIMESTAMP}.json"

echo "Running Go benchmark suite with ${GO_BIN}"
echo "Writing raw output to ${RAW_OUTPUT_PATH}"

(
  cd Benchmarks/golang
  "${GO_BIN}" test -run '^$' -bench . -benchmem -count "${COUNT}"
) | tee "${RAW_OUTPUT_PATH}"

Benchmarks/parse_go_benchmarks.py \
  "${RAW_OUTPUT_PATH}" \
  "${BENCHMARK_NAME}" \
  "${WRITES}" \
  "${SYNC_WRITES}" \
  "${SELECT_WRITES}" \
  "${BUFFER}" > "${JSON_OUTPUT_PATH}"

echo "Finished: ${JSON_OUTPUT_PATH}"
