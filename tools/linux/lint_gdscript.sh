#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v gdlint >/dev/null 2>&1; then
  cat >&2 <<'EOF'
gdlint was not found.

Install optional GDScript linting tools with:
  python -m pip install gdtoolkit
EOF
  exit 1
fi

cd "$PROJECT_DIR"
exec gdlint "addons/gameplay_tags" "benchmarks" "tests" "$@"
