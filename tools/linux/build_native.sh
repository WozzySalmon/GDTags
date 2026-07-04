#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Build the Gameplay Tags Godot GDExtension on Linux.

Usage:
  tools/linux/build_native.sh [SCons args]

Defaults:
  platform=linux target=template_debug -j$(nproc)

Examples:
  tools/linux/build_native.sh
  tools/linux/build_native.sh target=template_release
  tools/linux/build_native.sh -c
  tools/linux/build_native.sh -j1 verbose=yes
EOF
  exit 0
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f godot-cpp/SConstruct ]]; then
  cat >&2 <<'EOF'
godot-cpp is not available.

Run the local bootstrap if available:
  /root/projects/gameplay-tags-dev/bootstrap-gameplay-tags.sh

Or manually create/link a compatible checkout:
  git clone --branch godot-4.5-stable https://github.com/godotengine/godot-cpp.git godot-cpp
EOF
  exit 1
fi

args=("$@")
has_target=0
has_platform=0
has_jobs=0
for arg in "${args[@]}"; do
  [[ "$arg" == target=* ]] && has_target=1
  [[ "$arg" == platform=* ]] && has_platform=1
  [[ "$arg" == -j* ]] && has_jobs=1
done

[[ $has_platform -eq 0 ]] && args=("platform=linux" "${args[@]}")
[[ $has_target -eq 0 ]] && args=("target=template_debug" "${args[@]}")
if [[ $has_jobs -eq 0 ]]; then
  jobs="$(nproc 2>/dev/null || echo 1)"
  args=("-j${jobs}" "${args[@]}")
fi

printf '\nBuilding Gameplay Tags native extension\n  %s\n\n' "${args[*]}"
exec scons "${args[@]}"
