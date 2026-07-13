#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
versions=("${GODOT_46_BIN:-godot4.6}" "${GODOT_47_BIN:-godot4.7}")

for godot_bin in "${versions[@]}"; do
  printf '\n##############################\n'
  printf '# Testing with %s\n' "$godot_bin"
  printf '##############################\n'
  GODOT_BIN="$godot_bin" "$SCRIPT_DIR/test_addon.sh"
done

printf '\nAll configured Godot version smoke tests passed.\n'
