#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4.7}"
FORCE=0
if [[ "${1:-}" == "--force" ]]; then
  FORCE=1
fi

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  cat >&2 <<EOF
Could not find Godot executable: $GODOT_BIN

Set GODOT_BIN before running this script, for example:
  GODOT_BIN=/usr/local/bin/godot4.6 tools/linux/prepare_project.sh
EOF
  exit 1
fi

cache_file="$PROJECT_DIR/.godot/global_script_class_cache.cfg"
if [[ $FORCE -eq 0 && -f "$cache_file" ]]; then
  exit 0
fi

output_file="$(mktemp -t gameplay_tags_editor_import_XXXXXX.log)"
trap 'rm -f "$output_file"' EXIT

printf 'Preparing Godot project cache with %s...\n' "$GODOT_BIN"
set +e
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" --headless --editor --path "$PROJECT_DIR" --quit >"$output_file" 2>&1
godot_exit=$?
set -e

if grep -Eiq 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$output_file"; then
  echo "Godot editor import reported script errors:"
  grep -Ei 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$output_file" || true
  cp "$output_file" "${output_file}.failed"
  echo "Saved failed log: ${output_file}.failed"
  exit 1
fi

if [[ $godot_exit -ne 0 ]]; then
  if [[ -f "$cache_file" ]]; then
    echo "Godot editor import exited with code $godot_exit after creating the script class cache; continuing."
    exit 0
  fi
  echo "Godot editor import failed with code $godot_exit."
  cat "$output_file"
  exit "$godot_exit"
fi

echo "Godot project cache prepared."
