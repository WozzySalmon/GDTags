@tool
class_name GameplayTagComponent
extends Node
## Grants its parent node a set of gameplay tags.
## Add it as a direct child of the node that should own the tags; components nested
## deeper do not contribute. Every direct child component of a node is merged.

## Emitted once after an effective tag or stack update. No-op tag assignments emit nothing.
signal owned_tags_changed(tags: Array[StringName])

const GROUP_NAME: StringName = &"gameplay_tag_components"

## Inspector-authored tag storage. Runtime code must mutate it through the component methods;
## changing this Array in place bypasses validation, signals, indexing, and lookup-cache rebuilds.
@export var owned_tags: Array[StringName] = []:
	set(value):
		var filtered_tags: Array[StringName] = _filter_registered_tags(value)
		if owned_tags == filtered_tags:
			return
		owned_tags = filtered_tags
		_rebuild_cache()
		_prune_stack_counts()
		_refresh_owner_tag_index()
		_emit_owned_tags_changed()

@export var validate_with_database: bool = true

# Stack depth per exact tag, for tags applied more than once. Tags at depth one are
# absent rather than stored as 1, so this stays empty for the common case. Runtime
# state only: stacks are applied by gameplay, not authored in the Inspector.
var _stack_counts: Dictionary[String, int] = {}
var _exact_tag_set: Dictionary[StringName, bool] = {}
var _match_tag_set: Dictionary[StringName, bool] = {}


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
## Does nothing when filtering produces the currently owned set.
func set_owned_gameplay_tags(raw_tags: Array[StringName]) -> void:
	owned_tags = raw_tags


## Adds one tag and returns whether it was added.
## Rejects duplicates, unusable names, and, unless [member validate_with_database] is off,
## tags missing from the central database.
func add_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_usable_tag(raw_tag)
	if tag == &"" or owned_tags.has(tag):
		return false
	if validate_with_database and not _is_registered_tag(tag):
		push_warning("Gameplay tag is not in the central database: %s" % String(tag))
		return false
	var updated_tags: Array[StringName] = owned_tags.duplicate()
	updated_tags.append(tag)
	owned_tags = updated_tags
	return true


## Adds several tags and returns how many were new.
## Emits [signal owned_tags_changed] at most once for the whole batch.
func add_tags(raw_tags: Array[StringName]) -> int:
	var previous_tags: Array[StringName] = owned_tags.duplicate()
	var updated_tags: Array[StringName] = owned_tags.duplicate()
	updated_tags.append_array(raw_tags)
	owned_tags = updated_tags
	# Set membership instead of an Array scan per owned tag: counting is O(n + m),
	# not O(n * m), and reports the same result.
	var previous_set: Dictionary[StringName, bool] = {}
	for tag in previous_tags:
		previous_set[tag] = true
	var added: int = 0
	for tag in owned_tags:
		if not previous_set.has(tag):
			added += 1
	return added


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


## Removes several tags and all their stacks. Returns how many were present.
## Emits [signal owned_tags_changed] at most once for the whole batch.
func remove_tags(raw_tags: Array[StringName]) -> int:
	var remove_set: Dictionary[StringName, bool] = {}
	for raw_tag in raw_tags:
		var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		if tag != &"":
			remove_set[tag] = true

	var kept_tags: Array[StringName] = []
	for tag in owned_tags:
		if not remove_set.has(tag):
			kept_tags.append(tag)
	var removed: int = owned_tags.size() - kept_tags.size()
	if removed > 0:
		owned_tags = kept_tags
	return removed


## Applies one more stack of [param raw_tag], adding the tag when it is not yet owned.
## Returns the resulting depth, or 0 when the tag could not be added.
func add_tag_stack(raw_tag: StringName) -> int:
	var tag: StringName = GameplayTagDatabase.normalize_usable_tag(raw_tag)
	if tag == &"":
		return 0
	if not owned_tags.has(tag):
		return 1 if add_tag(tag) else 0

	var key: String = String(tag)
	_stack_counts[key] = _stack_counts.get(key, 1) + 1
	_emit_owned_tags_changed()
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

	if remaining == 1:
		_stack_counts.erase(key)
	else:
		_stack_counts[key] = remaining
	_emit_owned_tags_changed()
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
	var tag: StringName = GameplayTagDatabase.normalize_usable_tag(raw_tag)
	if tag == &"":
		return false
	if count <= 0:
		return remove_tag(tag)

	if not owned_tags.has(tag):
		if not add_tag(tag):
			return false
		if count == 1:
			return true

	var key: String = String(tag)
	if _stack_counts.get(key, 1) == count:
		return false
	if count == 1:
		_stack_counts.erase(key)
	else:
		_stack_counts[key] = count
	_emit_owned_tags_changed()
	return true


## Returns whether this component owns [param raw_tag], matching parents unless [param exact].
## Cached sets avoid scanning and re-evaluating hierarchy on gameplay hot paths.
func has_tag(raw_tag: StringName, exact: bool = false) -> bool:
	var tag_set: Dictionary[StringName, bool] = _exact_tag_set if exact else _match_tag_set
	if tag_set.has(raw_tag):
		return true
	var normalized_tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	return normalized_tag != &"" and tag_set.has(normalized_tag)


## Returns whether this component owns at least one of [param required_tags].
func has_any(required_tags: Array[StringName], exact: bool = false) -> bool:
	for tag in required_tags:
		if has_tag(tag, exact):
			return true
	return false


## Returns whether this component owns every one of [param required_tags].
## An empty list matches, and entries that normalize to an empty name are ignored.
func has_all(required_tags: Array[StringName], exact: bool = false) -> bool:
	var tag_set: Dictionary[StringName, bool] = _exact_tag_set if exact else _match_tag_set
	if tag_set.has_all(required_tags):
		return true
	for raw_tag in required_tags:
		# Set keys are canonical, so a raw-key hit already proves ownership; only a
		# miss can need the normalize pass.
		if tag_set.has(raw_tag):
			continue
		var normalized_tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		if normalized_tag != &"" and not tag_set.has(normalized_tag):
			return false
	return true


# The signal hands out a copy: a listener that appends to or clears its argument must
# not be able to mutate this component's owned set, caches, or tag index.
func _emit_owned_tags_changed() -> void:
	owned_tags_changed.emit(owned_tags.duplicate())


func _rebuild_cache() -> void:
	_exact_tag_set.clear()
	_match_tag_set.clear()
	for tag in owned_tags:
		_exact_tag_set[tag] = true
		_match_tag_set[tag] = true
		for parent in GameplayTagDatabase.get_canonical_parent_tags(tag):
			_match_tag_set[parent] = true


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

	var registry: GameplayTagRegistry = _get_registry()
	if registry == null:
		return canonical_tags

	var filtered_tags: Array[StringName] = []
	var resolved_tags: Dictionary[StringName, bool] = {}
	var redirects_changed_order: bool = false
	for tag in canonical_tags:
		# A tag authored before a rename resolves to its replacement rather than being
		# dropped, so existing scenes survive a renamed branch.
		var resolved_tag: StringName = registry.resolve_tag(tag)
		if not registry.is_valid_tag(resolved_tag):
			push_warning("Gameplay tag is not in the central database: %s" % String(tag))
			continue
		if resolved_tags.has(resolved_tag):
			redirects_changed_order = true
			continue
		resolved_tags[resolved_tag] = true
		filtered_tags.append(resolved_tag)
		redirects_changed_order = redirects_changed_order or resolved_tag != tag
	if redirects_changed_order:
		return GameplayTagDatabase.canonicalize_tag_array(filtered_tags)
	return filtered_tags


func _is_registered_tag(tag: StringName) -> bool:
	var registry: GameplayTagRegistry = _get_registry()
	return true if registry == null else registry.is_valid_tag(tag)


func _refresh_owner_tag_index(deferred: bool = false) -> void:
	var owner_node: Node = get_parent()
	if owner_node == null:
		return
	var registry: GameplayTagRegistry = _get_registry()
	if registry == null:
		return
	if deferred:
		# The owner can be freed before the deferred call runs, so pass an ID the
		# registry can validate rather than a reference that may dangle.
		registry.call_deferred("_refresh_node_tag_index_by_id", owner_node.get_instance_id())
	else:
		registry.refresh_node_tag_index(owner_node)


func _get_registry() -> GameplayTagRegistry:
	return GameplayTagUtils.get_registry(self) as GameplayTagRegistry
