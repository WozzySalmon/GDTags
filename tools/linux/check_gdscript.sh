#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4.7}"
export GODOT_SILENCE_ROOT_WARNING="${GODOT_SILENCE_ROOT_WARNING:-1}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  cat >&2 <<EOF
Could not find Godot executable: $GODOT_BIN

Set GODOT_BIN before running this script, for example:
  GODOT_BIN=/usr/local/bin/godot4.6 tools/linux/check_gdscript.sh
EOF
  exit 1
fi

check_output="$(mktemp -t gameplay_tags_gdscript_check_XXXXXX.log)"
trap 'rm -f "$check_output"' EXIT

"$PROJECT_DIR/tools/linux/prepare_project.sh"
rm -f "$PROJECT_DIR/.godot/extension_list.cfg" 2>/dev/null || true

echo "Running Godot GDScript smoke check with $GODOT_BIN..."
set +e
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "res://tests/test_gameplay_tags.gd" >"$check_output" 2>&1
godot_exit=$?
set -e

if grep -Eiq 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$check_output"; then
  echo
  echo "GDScript script errors were found:"
  grep -Ei 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$check_output" || true
  echo
  echo "Full log: $check_output"
  cp "$check_output" "${check_output}.failed"
  echo "Saved failed log: ${check_output}.failed"
  exit 1
fi

if [[ $godot_exit -ne 0 ]]; then
  echo
  echo "Godot exited with code $godot_exit."
  cat "$check_output"
  exit "$godot_exit"
fi

echo "GDScript smoke check passed."
