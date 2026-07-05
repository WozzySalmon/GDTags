#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Native GDExtension runtime is deferred in the clean restart."
echo "Running the GDScript workflow smoke suite instead."
"$SCRIPT_DIR/test_native.sh"
