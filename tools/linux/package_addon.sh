#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_CFG="$PROJECT_DIR/addons/gameplay_tags/plugin.cfg"
DIST_DIR="$PROJECT_DIR/dist"

if [[ ! -f "$PLUGIN_CFG" ]]; then
  echo "Could not find plugin.cfg at $PLUGIN_CFG" >&2
  exit 1
fi

version="$(awk -F'"' '/^version="[^"]+"/{print $2; exit}' "$PLUGIN_CFG")"
if [[ -z "$version" ]]; then
  echo "Could not read addon version from $PLUGIN_CFG" >&2
  exit 1
fi

package_name="gameplay_tags-${version}"
stage_dir="$DIST_DIR/$package_name"
zip_path="$DIST_DIR/$package_name.zip"

rm -rf "$stage_dir"
rm -f "$zip_path"
mkdir -p "$stage_dir/addons" "$DIST_DIR"
touch "$DIST_DIR/.gdignore"

cp -a "$PROJECT_DIR/addons/gameplay_tags" "$stage_dir/addons/"
stage_addon="$stage_dir/addons/gameplay_tags"

find "$stage_addon" -type f \( \
  -name '~*' -o \
  -name '*.tmp' -o \
  -name '*.TMP' -o \
  -name '.DS_Store' \
\) -delete


if [[ -f "$PROJECT_DIR/LICENSE" ]]; then
  cp "$PROJECT_DIR/LICENSE" "$stage_dir/LICENSE"
fi

(
  cd "$stage_dir"
  zip -q -r "$zip_path" .
)

if ! unzip -Z1 "$zip_path" | grep -Fxq 'addons/gameplay_tags/plugin.cfg'; then
  echo "Package validation failed: addon plugin.cfg is missing." >&2
  exit 1
fi

if unzip -Z1 "$zip_path" | grep -Eiq '(^|/)(tests|benchmarks|\.godot)(/|$)|(^|/)~|\.tmp$|\.DS_Store$'; then
  echo "Package validation failed: development artifacts were included." >&2
  exit 1
fi

printf '\nPackage created and validated:\n  %s\n' "$zip_path"
printf '\nInstall it into another Godot project so this path exists:\n'
printf '  addons/gameplay_tags/plugin.cfg\n'
