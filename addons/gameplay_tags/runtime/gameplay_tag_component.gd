@tool
class_name GameplayTagComponent
extends Node

signal owned_tags_changed(tags: Array[StringName])

const GROUP_NAME: StringName = &"gameplay_tag_components"

@export var owned_tags: Array[StringName] = []:
	set(value):
		owned_tags = _filter_registered_tags(value)
		owned_tags_changed.emit(owned_tags)

@export var validate_with_database: bool = true


func _enter_tree() -> void:
	add_to_group(GROUP_NAME)


func get_owned_gameplay_tags() -> GameplayTagContainer:
	return GameplayTagContainer.new(owned_tags)


func set_owned_gameplay_tags(raw_tags: Array[StringName]) -> void:
	owned_tags = _filter_registered_tags(raw_tags)


func add_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or owned_tags.has(tag):
		return false
	if validate_with_database and not _is_registered_tag(tag):
		push_warning("Gameplay tag is not in the central database: %s" % String(tag))
		return false
	owned_tags.append(tag)
	owned_tags = GameplayTagDatabase.canonicalize_tag_array(owned_tags)
	return true


func remove_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var index: int = owned_tags.find(tag)
	if index < 0:
		return false
	var updated_tags: Array[StringName] = owned_tags.duplicate()
	updated_tags.remove_at(index)
	owned_tags = updated_tags
	return true


func has_tag(raw_tag: StringName, exact: bool = false) -> bool:
	return get_owned_gameplay_tags().has_tag(raw_tag, exact)


func has_any(required_tags: Array[StringName], exact: bool = false) -> bool:
	return get_owned_gameplay_tags().has_any(required_tags, exact)


func has_all(required_tags: Array[StringName], exact: bool = false) -> bool:
	return get_owned_gameplay_tags().has_all(required_tags, exact)


func _filter_registered_tags(raw_tags: Array[StringName]) -> Array[StringName]:
	var canonical_tags: Array[StringName] = GameplayTagDatabase.canonicalize_tag_array(raw_tags)
	if not validate_with_database:
		return canonical_tags

	var registry: Node = _get_registry()
	if registry == null or not registry.has_method("is_valid_tag"):
		return canonical_tags

	var filtered_tags: Array[StringName] = []
	for tag in canonical_tags:
		if bool(registry.is_valid_tag(tag)):
			filtered_tags.append(tag)
		else:
			push_warning("Gameplay tag is not in the central database: %s" % String(tag))
	return filtered_tags


func _is_registered_tag(tag: StringName) -> bool:
	var registry: Node = _get_registry()
	if registry == null or not registry.has_method("is_valid_tag"):
		return true
	return bool(registry.is_valid_tag(tag))


func _get_registry() -> Node:
	return GameplayTagUtils.get_registry(self)
