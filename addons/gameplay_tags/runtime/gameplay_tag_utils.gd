@tool
class_name GameplayTagUtils
extends RefCounted
## Shared setting-path and autoload-resolution helpers for the runtime classes.

const DATABASE_SETTING: String = "gameplay_tags/database_path"
const TAG_IDS_SETTING: String = "gameplay_tags/generated_tag_ids_path"
const DEFAULT_DATABASE_PATH: String = "res://gameplay_tags_database.tres"
const DEFAULT_TAG_IDS_PATH: String = "res://gameplay_tag_ids.gd"


## Returns the configured gameplay tag database path.
static func get_database_path() -> String:
	return resolve_setting_path(DATABASE_SETTING, DEFAULT_DATABASE_PATH)


## Returns the configured path for the generated GameplayTagIds script.
static func get_tag_ids_path() -> String:
	return resolve_setting_path(TAG_IDS_SETTING, DEFAULT_TAG_IDS_PATH)


## Reads a project setting, honouring per-platform feature tag overrides such as
## [code]gameplay_tags/database_path.mobile[/code]. [method ProjectSettings.get_setting]
## ignores those overrides, so it is deliberately not used here.
## An explicitly empty value is returned as-is; only a missing setting falls back.
static func resolve_setting_path(setting_name: String, fallback: String) -> String:
	if not ProjectSettings.has_setting(setting_name):
		return fallback
	return String(ProjectSettings.get_setting_with_override(setting_name))


## Returns the GameplayTags autoload, or null when it is not installed.
## [param context] supplies the SceneTree when called from a node outside the main loop.
static func get_registry(context: Object = null) -> Node:
	var tree: SceneTree
	if context is Node and context.is_inside_tree():
		tree = context.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameplayTags")
