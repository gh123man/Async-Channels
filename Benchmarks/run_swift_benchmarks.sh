#!/usr/bin/env bash

set -euo pipefail

SWIFT_BIN="${SWIFT_BIN:-swift}"
ROUNDS="${ROUNDS:-6}"
WARMUP="${WARMUP:-1}"
WRITES="${WRITES:-1000000}"
SYNC_WRITES="${SYNC_WRITES:-5000000}"
SELECT_WRITES="${SELECT_WRITES:-100000}"
BUFFER="${BUFFER:-100}"
OUTPUT_DIR="${OUTPUT_DIR:-Benchmarks/results}"
SCRATCH_ROOT="${SCRATCH_ROOT:-/tmp/asyncchannels-benchmarks}"
BENCHMARK_NAME="${BENCHMARK_NAME:-}"
SKIP_ASYNC_ALGORITHMS="${SKIP_ASYNC_ALGORITHMS:-0}"
UPDATE_README="${UPDATE_README:-0}"

mkdir -p "${OUTPUT_DIR}"

if [[ -z "${BENCHMARK_NAME}" ]]; then
  BENCHMARK_NAME="$("${SWIFT_BIN}" --version | head -n1 | tr ' /()' '_' | tr -cd '[:alnum:]_.-')"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_PATH="${OUTPUT_DIR}/${BENCHMARK_NAME}-${TIMESTAMP}.json"
SCRATCH_PATH="${SCRATCH_ROOT}/${BENCHMARK_NAME}"

CMD=(
  "${SWIFT_BIN}" run -c release --package-path Benchmarks --scratch-path "${SCRATCH_PATH}" Benchmarks
  --format json
  --rounds "${ROUNDS}"
  --warmup "${WARMUP}"
  --writes "${WRITES}"
  --sync-writes "${SYNC_WRITES}"
  --select-writes "${SELECT_WRITES}"
  --buffer "${BUFFER}"
)

if [[ "${SKIP_ASYNC_ALGORITHMS}" == "1" ]]; then
  CMD+=(--skip-async-algorithms)
fi

echo "Running benchmark suite with ${SWIFT_BIN}"
echo "Writing ${OUTPUT_PATH}"

BENCHMARK_TOOLCHAIN_LABEL="${BENCHMARK_NAME}" "${CMD[@]}" > "${OUTPUT_PATH}"

echo "Finished: ${OUTPUT_PATH}"

if [[ "${UPDATE_README}" == "1" ]]; then
  SWIFT_REPORT="${OUTPUT_PATH}" Benchmarks/update_benchmark_readme.sh
fi
