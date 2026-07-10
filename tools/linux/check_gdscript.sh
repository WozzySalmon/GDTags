#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Keep the quick-check entry point aligned with the complete smoke suite so it
# cannot miss editor-only parse, compile, or plugin-loading failures.
exec "$PROJECT_DIR/tools/linux/test_native.sh"
