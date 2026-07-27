@tool
class_name GameplayTagUtils
extends RefCounted
## Static helpers shared by the runtime classes.
## Mostly thin aliases so gameplay code can normalize and match tags without
## reaching for GameplayTagDatabase directly.

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


## Convenience alias for [method GameplayTagDatabase.normalize_tag].
static func normalize_tag_name(raw_tag: StringName) -> StringName:
	return GameplayTagDatabase.normalize_tag(raw_tag)


## Convenience alias for [method GameplayTagDatabase.tag_matches].
static func tag_matches(
	owned_tag: StringName, requested_tag: StringName, exact: bool = false
) -> bool:
	return GameplayTagDatabase.tag_matches(owned_tag, requested_tag, exact)


## Convenience alias for [method GameplayTagDatabase.canonicalize_tag_array].
static func canonicalize_tag_array(raw_tags: Array[StringName]) -> Array[StringName]:
	return GameplayTagDatabase.canonicalize_tag_array(raw_tags)


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
