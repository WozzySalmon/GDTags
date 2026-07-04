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

"$PROJECT_DIR/tools/linux/prepare_project.sh"
rm -f "$PROJECT_DIR/.godot/extension_list.cfg" 2>/dev/null || true

run_test() {
  local label="$1"
  local script_path="$2"
  printf '\n=== %s ===\n' "$label"
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "$script_path"
}

run_test "GDScript runtime smoke test" "res://tests/test_gameplay_tags.gd"
run_test "Native smoke test" "res://tests/test_native_gameplay_tags_headless.gd"
run_test "Autoload native-selection smoke test" "res://tests/test_gameplay_tags_autoload_native_headless.gd"

printf '\nAll Gameplay Tags smoke tests passed with %s.\n' "$GODOT_BIN"
