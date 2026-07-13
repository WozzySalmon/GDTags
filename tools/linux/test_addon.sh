#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4.7}"
export GODOT_SILENCE_ROOT_WARNING="${GODOT_SILENCE_ROOT_WARNING:-1}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  cat >&2 <<EOF
Could not find Godot executable: $GODOT_BIN

Set GODOT_BIN before running this script, for example:
  GODOT_BIN=/usr/local/bin/godot4.6 tools/linux/test_addon.sh
EOF
  exit 1
fi

run_script_test() {
  local label="$1"
  local script_path="$2"
  local output_file
  output_file="$(mktemp -t gameplay_tags_script_test_XXXXXX.log)"
  printf '\n=== %s ===\n' "$label"
  set +e
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "$script_path" >"$output_file" 2>&1
  local godot_exit=$?
  set -e

  cat "$output_file"
  if grep -Eiq 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$output_file"; then
    cp "$output_file" "${output_file}.failed"
    echo "Saved failed log: ${output_file}.failed"
    exit 1
  fi

  if [[ $godot_exit -ne 0 ]]; then
    rm -f "$output_file"
    exit "$godot_exit"
  fi

  rm -f "$output_file"
}

run_editor_script_test() {
  local label="$1"
  local script_path="$2"
  local output_file
  output_file="$(mktemp -t gameplay_tags_editor_script_test_XXXXXX.log)"
  printf '\n=== %s ===\n' "$label"
  set +e
  "$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" --script "$script_path" >"$output_file" 2>&1
  local godot_exit=$?
  set -e

  cat "$output_file"
  if grep -Eiq 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$output_file"; then
    cp "$output_file" "${output_file}.failed"
    echo "Saved failed log: ${output_file}.failed"
    exit 1
  fi

  if [[ $godot_exit -ne 0 ]]; then
    rm -f "$output_file"
    exit "$godot_exit"
  fi

  rm -f "$output_file"
}

run_editor_smoke() {
  local output_file
  output_file="$(mktemp -t gameplay_tags_editor_smoke_XXXXXX.log)"
  printf '\n=== Editor/plugin smoke check ===\n'
  set +e
  "$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" --quit >"$output_file" 2>&1
  local godot_exit=$?
  set -e

  if grep -Eiq 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$output_file"; then
    echo "Godot editor reported script errors:"
    grep -Ei 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$output_file" || true
    cp "$output_file" "${output_file}.failed"
    echo "Saved failed log: ${output_file}.failed"
    exit 1
  fi

  if [[ $godot_exit -ne 0 ]]; then
    echo "Godot editor exited with code $godot_exit."
    cat "$output_file"
    exit "$godot_exit"
  fi

  rm -f "$output_file"
}

"$PROJECT_DIR/tools/linux/prepare_project.sh" --force

run_script_test "GDScript Gameplay Tags workflow smoke test" "res://tests/test_gameplay_tags.gd"
run_script_test "GDScript editor workflow tests" "res://tests/test_editor_workflows.gd"
run_script_test "GDScript runtime edge-case tests" "res://tests/test_runtime_edge_cases.gd"
run_editor_script_test \
  "GDScript editor picker interaction tests" \
  "res://tests/test_editor_picker_interactions.gd"
run_editor_smoke

printf '\nAll Gameplay Tags smoke tests passed with %s.\n' "$GODOT_BIN"
