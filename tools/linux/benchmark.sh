#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4.7}"
BENCHMARK_MAX_TOTAL_MS="${BENCHMARK_MAX_TOTAL_MS:-5000}"
export GODOT_SILENCE_ROOT_WARNING="${GODOT_SILENCE_ROOT_WARNING:-1}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  cat >&2 <<EOF
Could not find Godot executable: $GODOT_BIN

Set GODOT_BIN before running this script, for example:
  GODOT_BIN=/usr/local/bin/godot4.6 tools/linux/benchmark.sh
EOF
  exit 1
fi

output_file="$(mktemp -t gameplay_tags_benchmark_XXXXXX.log)"
trap 'rm -f "$output_file"' EXIT

set +e
"$GODOT_BIN" \
  --headless \
  --path "$PROJECT_DIR" \
  --script "res://benchmarks/bench_10000_tags.gd" >"$output_file" 2>&1
godot_exit=$?
set -e

cat "$output_file"

if grep -Eiq 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$output_file"; then
  cp "$output_file" "${output_file}.failed"
  echo "Saved failed log: ${output_file}.failed"
  exit 1
fi

if [[ $godot_exit -ne 0 ]]; then
  exit "$godot_exit"
fi

total_ms="$(awk -F= '/^METRIC total_ms=/{print $2; exit}' "$output_file")"
if [[ -z "$total_ms" ]]; then
  echo "Benchmark did not report METRIC total_ms." >&2
  exit 1
fi

if ! awk -v actual="$total_ms" -v maximum="$BENCHMARK_MAX_TOTAL_MS" 'BEGIN { exit !(actual <= maximum) }'; then
  echo "Benchmark regression: ${total_ms} ms exceeded ${BENCHMARK_MAX_TOTAL_MS} ms." >&2
  exit 1
fi

printf 'Gameplay Tags benchmark passed: %s ms <= %s ms.\n' \
  "$total_ms" "$BENCHMARK_MAX_TOTAL_MS"
