#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Cross-build Windows x86_64 Gameplay Tags GDExtension DLLs from Linux using MinGW.

Usage:
  tools/linux/build_windows_cross.sh [--no-package]

Outputs:
  addons/gameplay_tags/bin/windows/gameplay_tags.windows.template_debug.x86_64.dll
  addons/gameplay_tags/bin/windows/gameplay_tags.windows.template_release.x86_64.dll
  dist/gameplay_tags-<version>-windows-crossbuild.zip

Prerequisites:
  apt-get install mingw-w64 zip
  godot-cpp/ linked to the verified compatibility baseline, godot-4.5-stable.

Low-memory machines:
  JOBS=1 tools/linux/build_windows_cross.sh
EOF
  exit 0
fi

package=1
for arg in "$@"; do
  case "$arg" in
    --no-package) package=0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

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

missing=0
for tool in x86_64-w64-mingw32-g++ x86_64-w64-mingw32-objdump; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    missing=1
  fi
done
if [[ $package -eq 1 ]] && ! command -v zip >/dev/null 2>&1; then
  echo "Missing required tool: zip" >&2
  missing=1
fi
if [[ $missing -ne 0 ]]; then
  echo "Install dependencies with: apt-get install mingw-w64 zip" >&2
  exit 1
fi

jobs="${JOBS:-$(nproc 2>/dev/null || echo 1)}"

echo "Cleaning previous Windows outputs..."
rm -rf bin/windows addons/gameplay_tags/bin/windows
rm -f .sconsign.dblite

echo "Building Windows debug DLL..."
scons platform=windows target=template_debug arch=x86_64 -j"$jobs"

echo "Building Windows release DLL..."
scons platform=windows target=template_release arch=x86_64 -j"$jobs"

expected=(
  addons/gameplay_tags/bin/windows/gameplay_tags.windows.template_debug.x86_64.dll
  addons/gameplay_tags/bin/windows/gameplay_tags.windows.template_release.x86_64.dll
)
for dll in "${expected[@]}"; do
  if [[ ! -f "$dll" ]]; then
    echo "Missing expected DLL: $dll" >&2
    exit 1
  fi
done

echo
echo "Windows DLL dependencies:"
for dll in "${expected[@]}"; do
  echo "--- $dll ---"
  x86_64-w64-mingw32-objdump -p "$dll" | grep 'DLL Name' || true
done

if [[ $package -eq 1 ]]; then
  version="$(python3 - <<'PY'
import re
text = open('addons/gameplay_tags/plugin.cfg', encoding='utf-8').read()
match = re.search(r'^version="([^"]+)"', text, re.M)
print(match.group(1) if match else 'dev')
PY
)"
  mkdir -p dist
  zip_path="dist/gameplay_tags-${version}-windows-crossbuild.zip"
  rm -f "$zip_path"
  zip -qr "$zip_path" addons/gameplay_tags \
    -x '*/.godot/*' '*/__pycache__/*' '*.tmp' '*.TMP'
  echo
  echo "Package written: $zip_path"
fi
