@tool
class_name GameplayTagComponent
extends Node
## Grants its parent node a set of gameplay tags.
## Add it as a direct child of the node that should own the tags; components nested
## deeper do not contribute. Every direct child component of a node is merged.

signal owned_tags_changed(tags: Array[StringName])

const GROUP_NAME: StringName = &"gameplay_tag_components"

@export var owned_tags: Array[StringName] = []:
	set(value):
		owned_tags = _filter_registered_tags(value)
		_refresh_owner_tag_index()
		owned_tags_changed.emit(owned_tags)

@export var validate_with_database: bool = true


func _enter_tree() -> void:
	add_to_group(GROUP_NAME)
	_refresh_owner_tag_index()


func _exit_tree() -> void:
	# The parent link is still live here, so this component's tags would still be
	# counted. Refresh once the tree change has settled instead.
	_refresh_owner_tag_index(true)


## Returns this component's tags as a container.
func get_owned_gameplay_tags() -> GameplayTagContainer:
	return GameplayTagContainer.new(owned_tags)


## Replaces every owned tag, applying the same validation as the exported property.
func set_owned_gameplay_tags(raw_tags: Array[StringName]) -> void:
	owned_tags = _filter_registered_tags(raw_tags)


## Adds one tag and returns whether it was added.
## Rejects duplicates, unusable names, and — unless [member validate_with_database] is off —
## tags missing from the central database.
func add_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or not GameplayTagDatabase.is_valid_tag_name(tag) or owned_tags.has(tag):
		return false
	if validate_with_database and not _is_registered_tag(tag):
		push_warning("Gameplay tag is not in the central database: %s" % String(tag))
		return false
	var updated_tags: Array[StringName] = owned_tags.duplicate()
	updated_tags.append(tag)
	owned_tags = updated_tags
	return true


## Removes one owned tag and returns whether it was present.
func remove_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var index: int = owned_tags.find(tag)
	if index < 0:
		return false
	var updated_tags: Array[StringName] = owned_tags.duplicate()
	updated_tags.remove_at(index)
	owned_tags = updated_tags
	return true


## Returns whether this component owns [param raw_tag], matching parents unless [param exact].
func has_tag(raw_tag: StringName, exact: bool = false) -> bool:
	return get_owned_gameplay_tags().has_tag(raw_tag, exact)


## Returns whether this component owns at least one of [param required_tags].
func has_any(required_tags: Array[StringName], exact: bool = false) -> bool:
	return get_owned_gameplay_tags().has_any(required_tags, exact)


## Returns whether this component owns every one of [param required_tags].
func has_all(required_tags: Array[StringName], exact: bool = false) -> bool:
	return get_owned_gameplay_tags().has_all(required_tags, exact)


func _filter_registered_tags(raw_tags: Array[StringName]) -> Array[StringName]:
	var canonical_tags: Array[StringName] = GameplayTagDatabase.canonicalize_valid_tag_array(
		raw_tags
	)
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


func _refresh_owner_tag_index(deferred: bool = false) -> void:
	var owner_node: Node = get_parent()
	if owner_node == null:
		return
	var registry: Node = _get_registry()
	if registry == null or not registry.has_method("refresh_node_tag_index"):
		return
	if deferred:
		# The owner can be freed before the deferred call runs, so pass an ID the
		# registry can validate rather than a reference that may dangle.
		registry.call_deferred("_refresh_node_tag_index_by_id", owner_node.get_instance_id())
	else:
		registry.refresh_node_tag_index(owner_node)


func _get_registry() -> Node:
	return GameplayTagUtils.get_registry(self)
