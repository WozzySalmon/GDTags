#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4.7}"
export GODOT_SILENCE_ROOT_WARNING="${GODOT_SILENCE_ROOT_WARNING:-1}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  cat >&2 <<EOF
Could not find Godot executable: $GODOT_BIN

Set GODOT_BIN before running this script, for example:
  GODOT_BIN=/usr/local/bin/godot4.6 tools/linux/test_native.sh
EOF
  exit 1
fi

run_script_test() {
  local label="$1"
  local script_path="$2"
  printf '\n=== %s ===\n' "$label"
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "$script_path"
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
rm -f "$PROJECT_DIR/.godot/extension_list.cfg" 2>/dev/null || true

run_script_test "GDScript Gameplay Tags workflow smoke test" "res://tests/test_gameplay_tags.gd"
run_editor_smoke

printf '\nAll Gameplay Tags smoke tests passed with %s. Native runtime is deferred in this clean restart.\n' "$GODOT_BIN"
