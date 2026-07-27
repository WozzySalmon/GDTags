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
		_prune_stack_counts()
		_refresh_owner_tag_index()
		owned_tags_changed.emit(owned_tags)

@export var validate_with_database: bool = true

# Stack depth per exact tag, for tags applied more than once. Tags at depth one are
# absent rather than stored as 1, so this stays empty for the common case. Runtime
# state only: stacks are applied by gameplay, not authored in the Inspector.
var _stack_counts: Dictionary[String, int] = {}


func _enter_tree() -> void:
	add_to_group(GROUP_NAME)
	_refresh_owner_tag_index()


func _exit_tree() -> void:
	# The parent link is still live here, so this component's tags would still be
	# counted. Refresh once the tree change has settled instead.
	_refresh_owner_tag_index(true)


## Returns this component's tags as a container, carrying any stack depths with them.
func get_owned_gameplay_tags() -> GameplayTagContainer:
	var container: GameplayTagContainer = GameplayTagContainer.new(owned_tags)
	for tag_key in _stack_counts:
		container.set_tag_count(StringName(tag_key), _stack_counts[tag_key])
	return container


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


## Removes one owned tag and every stack of it. Returns whether it was present.
func remove_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var index: int = owned_tags.find(tag)
	if index < 0:
		return false
	var updated_tags: Array[StringName] = owned_tags.duplicate()
	updated_tags.remove_at(index)
	owned_tags = updated_tags
	return true


## Applies one more stack of [param raw_tag], adding the tag when it is not yet owned.
## Returns the resulting depth, or 0 when the tag could not be added.
func add_tag_stack(raw_tag: StringName) -> int:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or not GameplayTagDatabase.is_valid_tag_name(tag):
		return 0
	if not owned_tags.has(tag):
		return 1 if add_tag(tag) else 0

	var key: String = String(tag)
	_stack_counts[key] = _stack_counts.get(key, 1) + 1
	owned_tags_changed.emit(owned_tags)
	return _stack_counts[key]


## Releases one stack of [param raw_tag], removing the tag when the last stack goes.
## Returns the remaining depth.
func remove_tag_stack(raw_tag: StringName) -> int:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if not owned_tags.has(tag):
		return 0

	var key: String = String(tag)
	var remaining: int = _stack_counts.get(key, 1) - 1
	if remaining <= 0:
		remove_tag(tag)
		return 0

	_stack_counts[key] = remaining
	owned_tags_changed.emit(owned_tags)
	return remaining


## Returns how many stacks of [param raw_tag] are applied, or 0 when it is not owned.
## Stacks are tracked per exact tag, so a parent tag never reports a child's stacks.
func get_tag_count(raw_tag: StringName) -> int:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if not owned_tags.has(tag):
		return 0
	return _stack_counts.get(String(tag), 1)


## Sets the absolute stack depth for [param raw_tag]. A count of 0 or less releases it.
## Returns whether anything changed.
func set_tag_count(raw_tag: StringName, count: int) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or not GameplayTagDatabase.is_valid_tag_name(tag):
		return false
	if count <= 0:
		return remove_tag(tag)

	if not owned_tags.has(tag) and not add_tag(tag):
		return false

	var key: String = String(tag)
	if _stack_counts.get(key, 1) == count:
		return false
	if count == 1:
		_stack_counts.erase(key)
	else:
		_stack_counts[key] = count
	owned_tags_changed.emit(owned_tags)
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


# Stack depths only mean something while the tag is owned, so drop the rest whenever
# the owned set is replaced.
func _prune_stack_counts() -> void:
	if _stack_counts.is_empty():
		return
	for tag_key in _stack_counts.keys():
		if not owned_tags.has(StringName(tag_key)):
			_stack_counts.erase(tag_key)


func _filter_registered_tags(raw_tags: Array[StringName]) -> Array[StringName]:
	var canonical_tags: Array[StringName] = GameplayTagDatabase.canonicalize_valid_tag_array(
		raw_tags
	)
	if not validate_with_database:
		return canonical_tags

	var registry: Node = _get_registry()
	if registry == null or not registry.has_method("is_valid_tag"):
		return canonical_tags

	var can_resolve: bool = registry.has_method("resolve_tag")
	var filtered_tags: Array[StringName] = []
	for tag in canonical_tags:
		# A tag authored before a rename resolves to its replacement rather than being
		# dropped, so existing scenes survive a renamed branch.
		var resolved_tag: StringName = registry.resolve_tag(tag) if can_resolve else tag
		if bool(registry.is_valid_tag(resolved_tag)):
			filtered_tags.append(resolved_tag)
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
