@tool
class_name GameplayTagUtils
extends RefCounted
## Static helpers shared by the runtime classes.
## Mostly thin aliases so gameplay code can normalize and match tags without
## reaching for GameplayTagDatabase directly.


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
