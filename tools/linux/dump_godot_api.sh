#!/usr/bin/env bash
# Generates the engine's own class reference for each supported Godot version.
#
# The XML comes from the binary itself, so it is authoritative about what exists
# and what the exact signatures are in the versions this addon actually ships
# against -- unlike documentation for "latest", which silently drifts ahead of
# the support floor declared in project.godot.
#
# Release binaries carry no prose, so the generated XML has signatures but empty
# descriptions. Use query_godot_api.py to check availability and signatures, then
# read the online class reference for semantics. See docs/VALIDATION.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_ROOT="${GODOT_API_DIR:-$REPO_ROOT/.godot-api}"

versions=("${GODOT_46_BIN:-godot4.6}" "${GODOT_47_BIN:-godot4.7}")

for godot_bin in "${versions[@]}"; do
  if ! command -v "$godot_bin" >/dev/null 2>&1; then
    printf 'Skipping %s: binary not found on PATH\n' "$godot_bin" >&2
    continue
  fi

  version_id="$("$godot_bin" --version 2>/dev/null | head -1 | cut -d. -f1,2)"
  out_dir="$OUT_ROOT/$version_id"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  printf 'Generating class reference for %s -> %s\n' "$godot_bin" "$out_dir"
  "$godot_bin" --headless --doctool "$out_dir" >/dev/null 2>&1

  printf '  %s classes\n' "$(find "$out_dir" -name '*.xml' | wc -l)"
done

printf '\nDone. Query it with:\n'
printf '  tools/linux/query_godot_api.py <Class> [member]\n'
