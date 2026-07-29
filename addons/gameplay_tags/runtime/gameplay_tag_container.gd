@tool
class_name GameplayTagContainer
extends Resource
## A set of gameplay tags owned by one entity, with cached hierarchical matching.
## Supports stacking so several independent effects can grant the same tag; the tag
## is released only when the last stack is removed. Stack depth is runtime state and
## is not serialized.

signal tags_changed

@export var tags: Array[StringName] = []:
	set(value):
		tags = GameplayTagDatabase.canonicalize_valid_tag_array(value)
		_rebuild_cache()
		_notify_changed()

var _exact_tag_set: Dictionary[String, bool] = {}
var _match_tag_set: Dictionary[String, bool] = {}
# Stack depth per owned tag. Runtime state for overlapping effects, so it is not
# exported: a saved container restores every tag at a count of one.
var _tag_counts: Dictionary[String, int] = {}


func _init(initial_tags: Array[StringName] = []) -> void:
	if not initial_tags.is_empty():
		tags = initial_tags


## Replaces every tag in this container.
func set_tags(raw_tags: Array[StringName]) -> void:
	tags = raw_tags


## Adds one tag at a stack depth of one. Returns false if already present or unusable.
func add_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or not GameplayTagDatabase.is_valid_tag_name(tag) or tags.has(tag):
		return false
	var updated_tags: Array[StringName] = tags.duplicate()
	updated_tags.append(tag)
	tags = updated_tags
	return true


## Adds several tags and returns how many were new.
func add_tags(raw_tags: Array[StringName]) -> int:
	var existing: Dictionary[String, StringName] = {}
	for tag in tags:
		existing[String(tag)] = tag

	var added: int = 0
	for raw_tag in raw_tags:
		var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		var key: String = String(tag)
		if tag == &"" or not GameplayTagDatabase.is_valid_tag_name(tag) or existing.has(key):
			continue
		existing[key] = tag
		added += 1

	if added > 0:
		tags = existing.values()
	return added


## Applies one stack of [param raw_tag] and returns the new stack depth, or 0 if the
## tag is unusable. Use this when several independent effects can grant the same tag;
## the tag stays owned until every stack is removed.
func add_tag_stack(raw_tag: StringName) -> int:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or not GameplayTagDatabase.is_canonical_tag_name(tag):
		return 0

	var key: String = String(tag)
	if not _exact_tag_set.has(key):
		# _rebuild_cache seeds a new tag at one stack.
		add_tag(tag)
		return _tag_counts.get(key, 1)

	_tag_counts[key] = _tag_counts.get(key, 1) + 1
	_notify_changed()
	return _tag_counts[key]


## Removes one stack of [param raw_tag] and returns the remaining depth. The tag is
## released only when the last stack is removed.
func remove_tag_stack(raw_tag: StringName) -> int:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var key: String = String(tag)
	if not _exact_tag_set.has(key):
		return 0

	var remaining: int = _tag_counts.get(key, 1) - 1
	if remaining <= 0:
		remove_tag(tag)
		return 0

	_tag_counts[key] = remaining
	_notify_changed()
	return remaining


## Returns how many stacks of [param raw_tag] are applied, or 0 when it is not owned.
## Stacks are tracked per exact tag, so a parent tag never reports a child's stacks.
func get_tag_count(raw_tag: StringName) -> int:
	var key: String = String(GameplayTagDatabase.normalize_tag(raw_tag))
	if not _exact_tag_set.has(key):
		return 0
	return _tag_counts.get(key, 1)


## Sets the absolute stack depth for [param raw_tag]. A count of 0 or less releases it.
## Returns whether anything changed.
func set_tag_count(raw_tag: StringName, count: int) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or not GameplayTagDatabase.is_canonical_tag_name(tag):
		return false

	if count <= 0:
		return remove_tag(tag)

	var key: String = String(tag)
	if not _exact_tag_set.has(key):
		add_tag(tag)
	if _tag_counts.get(key, 1) == count:
		return false
	_tag_counts[key] = count
	_notify_changed()
	return true


## Removes a tag and all of its stacks. Returns whether it was present.
func remove_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var index: int = tags.find(tag)
	if index < 0:
		return false
	var updated_tags: Array[StringName] = tags.duplicate()
	updated_tags.remove_at(index)
	tags = updated_tags
	return true


## Removes several tags and returns how many were present.
func remove_tags(raw_tags: Array[StringName]) -> int:
	var remove_set: Dictionary[String, bool] = {}
	for raw_tag in raw_tags:
		var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		if tag != &"":
			remove_set[String(tag)] = true

	var removed: int = 0
	var kept: Array[StringName] = []
	for tag in tags:
		if remove_set.has(String(tag)):
			removed += 1
		else:
			kept.append(tag)

	if removed > 0:
		tags = kept
	return removed


## Removes every tag and stack.
func clear() -> void:
	if tags.is_empty():
		return
	tags = []


## Returns whether this container owns [param raw_tag].
## A parent tag matches an owned child unless [param exact] is true.
func has_tag(raw_tag: StringName, exact: bool = false) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"":
		return false
	if exact:
		return _exact_tag_set.has(String(tag))
	return _match_tag_set.has(String(tag))


## Returns whether at least one of [param required_tags] is owned.
func has_any(required_tags: Array[StringName], exact: bool = false) -> bool:
	for tag in required_tags:
		if has_tag(tag, exact):
			return true
	return false


## Returns whether every one of [param required_tags] is owned. An empty list matches.
func has_all(required_tags: Array[StringName], exact: bool = false) -> bool:
	if required_tags.is_empty():
		return true
	for tag in required_tags:
		if not has_tag(tag, exact):
			return false
	return true


## Returns whether none of [param blocked_tags] is owned.
func has_none(blocked_tags: Array[StringName], exact: bool = false) -> bool:
	return not has_any(blocked_tags, exact)


## Returns whether this container holds exactly [param other_tags] and nothing else.
func exact(other_tags: Array[StringName]) -> bool:
	return tags == GameplayTagDatabase.canonicalize_tag_array(other_tags)


## Returns how many of [param other_tags] this container owns.
func overlap_count(other_tags: Array[StringName], exact: bool = false) -> int:
	var overlaps: int = 0
	for tag in GameplayTagDatabase.canonicalize_tag_array(other_tags):
		if has_tag(tag, exact):
			overlaps += 1
	return overlaps


## Returns whether this container owns no tags.
func is_empty() -> bool:
	return tags.is_empty()


## Returns a copy of the owned tags, canonically sorted.
func get_tags() -> Array[StringName]:
	return tags.duplicate()


## Returns an independent copy, including stack depths.
func duplicate_container() -> GameplayTagContainer:
	var copy: GameplayTagContainer = GameplayTagContainer.new(tags)
	copy._tag_counts = _tag_counts.duplicate()
	return copy


func _rebuild_cache() -> void:
	_exact_tag_set.clear()
	_match_tag_set.clear()
	var reconciled_counts: Dictionary[String, int] = {}
	for tag in tags:
		var key: String = String(tag)
		_exact_tag_set[key] = true
		_match_tag_set[key] = true
		reconciled_counts[key] = maxi(1, _tag_counts.get(key, 1))
		for parent in GameplayTagDatabase.get_canonical_parent_tags(tag):
			_match_tag_set[String(parent)] = true
	_tag_counts = reconciled_counts


func _notify_changed() -> void:
	emit_changed()
	tags_changed.emit()
