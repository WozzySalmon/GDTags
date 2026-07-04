#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v gdformat >/dev/null 2>&1; then
  cat >&2 <<'EOF'
gdformat was not found.

Install optional GDScript formatting tools with:
  python -m pip install gdtoolkit
EOF
  exit 1
fi

exec gdformat "$PROJECT_DIR/addons/gameplay_tags" "$PROJECT_DIR/benchmarks" "$PROJECT_DIR/tests" "$@"
