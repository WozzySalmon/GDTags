#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4.7}"
PACKAGE_ZIP="${PACKAGE_ZIP:-}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  cat >&2 <<EOF
Could not find Godot executable: $GODOT_BIN

Set GODOT_BIN before running this script.
EOF
  exit 1
fi

if [[ -z "$PACKAGE_ZIP" ]]; then
  "$PROJECT_DIR/tools/linux/package_addon.sh"
  version="$(awk -F'"' '/^version="[^"]+"/{print $2; exit}' \
    "$PROJECT_DIR/addons/gameplay_tags/plugin.cfg")"
  PACKAGE_ZIP="$PROJECT_DIR/dist/gameplay_tags-${version}.zip"
fi

if [[ ! -f "$PACKAGE_ZIP" ]]; then
  echo "Could not find addon package: $PACKAGE_ZIP" >&2
  exit 1
fi

TEMP_PROJECT="$(mktemp -d -t gameplay_tags_install_test_XXXXXX)"
EDITOR_LOG="$(mktemp -t gameplay_tags_package_editor_XXXXXX.log)"
RUNTIME_LOG="$(mktemp -t gameplay_tags_package_runtime_XXXXXX.log)"
cleanup() {
  rm -rf "$TEMP_PROJECT"
  rm -f "$EDITOR_LOG" "$RUNTIME_LOG"
}
trap cleanup EXIT

unzip -q "$PACKAGE_ZIP" -d "$TEMP_PROJECT"
cat >"$TEMP_PROJECT/project.godot" <<'EOF'
[application]
config/name="Gameplay Tags Package Install Test"

[editor_plugins]
enabled=PackedStringArray("res://addons/gameplay_tags/plugin.cfg")

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat >"$TEMP_PROJECT/install_smoke.gd" <<'EOF'
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := root.get_node_or_null("GameplayTags")
	if registry == null:
		_fail("GameplayTags autoload was not registered by the packaged plugin")
		return
	var database: Variant = registry.get_database()
	if database == null:
		_fail("Packaged plugin did not provide a gameplay tag database")
		return
	if not registry.add_tag(&"Install.Smoke", "Package installation smoke tag"):
		_fail("Packaged GameplayTags autoload could not add a tag")
		return
	if not registry.has_tag(&"Install.Smoke"):
		_fail("Packaged GameplayTags autoload could not read the added tag")
		return
	if not FileAccess.file_exists("res://gameplay_tags_database.tres"):
		_fail("Packaged plugin did not create gameplay_tags_database.tres")
		return
	if not FileAccess.file_exists("res://gameplay_tag_ids.gd"):
		_fail("Packaged plugin did not create gameplay_tag_ids.gd")
		return
	print("GAMEPLAY_TAGS_PACKAGE_INSTALL_SMOKE passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
EOF

scan_log() {
  local log_path="$1"
  if grep -Eiq 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$log_path"; then
    grep -Ei 'SCRIPT ERROR|Compile Error|Parse Error|Parser Error' "$log_path" >&2 || true
    cp "$log_path" "${log_path}.failed"
    echo "Saved failed log: ${log_path}.failed" >&2
    return 1
  fi
}

printf 'Loading packaged addon in a clean project with %s...\n' "$GODOT_BIN"
set +e
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" \
  --headless --editor --path "$TEMP_PROJECT" --quit >"$EDITOR_LOG" 2>&1
editor_exit=$?
set -e
scan_log "$EDITOR_LOG"
if [[ $editor_exit -ne 0 ]]; then
  cat "$EDITOR_LOG" >&2
  exit "$editor_exit"
fi

if [[ ! -f "$TEMP_PROJECT/gameplay_tags_database.tres" ]]; then
  echo "Packaged plugin did not create gameplay_tags_database.tres during editor load." >&2
  exit 1
fi
if [[ ! -f "$TEMP_PROJECT/gameplay_tag_ids.gd" ]]; then
  echo "Packaged plugin did not create gameplay_tag_ids.gd during editor load." >&2
  exit 1
fi

# A scripted headless editor quit does not persist add_autoload_singleton() to
# project.godot. The created database and ID script prove the packaged plugin
# loaded; seed the same owning autoload path for the separate runtime process.
cat >>"$TEMP_PROJECT/project.godot" <<'EOF'

[autoload]
GameplayTags="*res://addons/gameplay_tags/runtime/gameplay_tags.gd"
EOF

set +e
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" \
  --headless --path "$TEMP_PROJECT" --script res://install_smoke.gd >"$RUNTIME_LOG" 2>&1
runtime_exit=$?
set -e
scan_log "$RUNTIME_LOG"
if [[ $runtime_exit -ne 0 ]]; then
  cat "$RUNTIME_LOG" >&2
  exit "$runtime_exit"
fi
if ! grep -Fq 'GAMEPLAY_TAGS_PACKAGE_INSTALL_SMOKE passed' "$RUNTIME_LOG"; then
  cat "$RUNTIME_LOG" >&2
  echo "Packaged addon runtime smoke marker was not printed." >&2
  exit 1
fi

printf 'Packaged addon install smoke test passed with %s.\n' "$GODOT_BIN"
