@tool
class_name GameplayTagContainer
extends Resource

signal tags_changed

@export var tags: Array[StringName] = []:
	set(value):
		tags = GameplayTagDatabase.canonicalize_tag_array(value)
		_rebuild_cache()
		_notify_changed()

var _exact_tag_set := {}
var _match_tag_set := {}


func _init(initial_tags: Array = []) -> void:
	_rebuild_cache()
	if not initial_tags.is_empty():
		tags = GameplayTagDatabase.canonicalize_tag_array(initial_tags)
		_rebuild_cache()


func set_tags(raw_tags: Array) -> void:
	tags = GameplayTagDatabase.canonicalize_tag_array(raw_tags)


func add_tag(raw_tag: Variant) -> bool:
	var tag := GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or tags.has(tag):
		return false
	tags.append(tag)
	tags = GameplayTagDatabase.canonicalize_tag_array(tags)
	return true


func add(raw_tag: Variant) -> bool:
	return add_tag(raw_tag)


func add_tags(raw_tags: Array) -> int:
	var existing := {}
	for tag in tags:
		existing[String(tag)] = tag

	var added := 0
	for raw_tag in raw_tags:
		var tag := GameplayTagDatabase.normalize_tag(raw_tag)
		var key := String(tag)
		if tag == &"" or existing.has(key):
			continue
		existing[key] = tag
		added += 1

	if added > 0:
		tags = GameplayTagDatabase.canonicalize_tag_array(existing.values())
	return added


func remove_tag(raw_tag: Variant) -> bool:
	var tag := GameplayTagDatabase.normalize_tag(raw_tag)
	var index := tags.find(tag)
	if index < 0:
		return false
	tags.remove_at(index)
	_rebuild_cache()
	_notify_changed()
	return true


func remove(raw_tag: Variant) -> bool:
	return remove_tag(raw_tag)


func remove_tags(raw_tags: Array) -> int:
	var remove_set := {}
	for raw_tag in raw_tags:
		var tag := GameplayTagDatabase.normalize_tag(raw_tag)
		if tag != &"":
			remove_set[String(tag)] = true

	var removed := 0
	var kept: Array[StringName] = []
	for tag in tags:
		if remove_set.has(String(tag)):
			removed += 1
		else:
			kept.append(tag)

	if removed > 0:
		tags = kept
	return removed


func clear() -> void:
	if tags.is_empty():
		return
	tags.clear()
	_rebuild_cache()
	_notify_changed()


func has_tag(raw_tag: Variant, exact: bool = false) -> bool:
	var tag := GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"":
		return false
	if exact:
		return _exact_tag_set.has(String(tag))
	return _match_tag_set.has(String(tag))


func has(raw_tag: Variant) -> bool:
	return has_tag(raw_tag, false)


func has_exact(raw_tag: Variant) -> bool:
	return has_tag(raw_tag, true)


func has_any(required_tags: Variant, exact: bool = false) -> bool:
	for tag in _tags_from_variant(required_tags):
		if has_tag(tag, exact):
			return true
	return false


func any(required_tags: Variant, exact: bool = false) -> bool:
	return has_any(required_tags, exact)


func has_all(required_tags: Variant, exact: bool = false) -> bool:
	var normalized_tags := _tags_from_variant(required_tags)
	if normalized_tags.is_empty():
		return true
	for tag in normalized_tags:
		if not has_tag(tag, exact):
			return false
	return true


func all(required_tags: Variant, exact: bool = false) -> bool:
	return has_all(required_tags, exact)


func none(blocked_tags: Variant, exact: bool = false) -> bool:
	return not has_any(blocked_tags, exact)


func exact(other_tags: Variant) -> bool:
	return tags == _tags_from_variant(other_tags)


func overlap_count(other_tags: Variant, exact: bool = false) -> int:
	var overlaps := 0
	for tag in _tags_from_variant(other_tags):
		if has_tag(tag, exact):
			overlaps += 1
	return overlaps


func is_empty() -> bool:
	return tags.is_empty()


func get_tags() -> Array[StringName]:
	return tags.duplicate()


func to_array() -> Array[StringName]:
	return get_tags()


func duplicate_container() -> GameplayTagContainer:
	return GameplayTagContainer.new(tags)


func _tags_from_variant(value: Variant) -> Array[StringName]:
	if value is GameplayTagContainer:
		return value.get_tags()
	if value is Array:
		return GameplayTagDatabase.canonicalize_tag_array(value)
	return GameplayTagDatabase.canonicalize_tag_array([value])


func _rebuild_cache() -> void:
	_exact_tag_set.clear()
	_match_tag_set.clear()
	for tag in tags:
		var key := String(tag)
		_exact_tag_set[key] = true
		_match_tag_set[key] = true
		for parent in GameplayTagDatabase.get_parent_tags(tag):
			_match_tag_set[String(parent)] = true


func _notify_changed() -> void:
	emit_changed()
	tags_changed.emit()
