@tool
class_name GameplayTagContainer
extends Resource

signal tags_changed

@export var tags: Array[StringName] = []:
	set(value):
		tags = GameplayTagDatabase.canonicalize_tag_array(value)
		_rebuild_cache()
		_notify_changed()

var _exact_tag_set: Dictionary[String, bool] = {}
var _match_tag_set: Dictionary[String, bool] = {}


func _init(initial_tags: Array[StringName] = []) -> void:
	if not initial_tags.is_empty():
		tags = GameplayTagDatabase.canonicalize_tag_array(initial_tags)


func set_tags(raw_tags: Array[StringName]) -> void:
	tags = GameplayTagDatabase.canonicalize_tag_array(raw_tags)


func add_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or tags.has(tag):
		return false
	tags.append(tag)
	tags = GameplayTagDatabase.canonicalize_tag_array(tags)
	return true


func add(raw_tag: StringName) -> bool:
	return add_tag(raw_tag)


func add_tags(raw_tags: Array[StringName]) -> int:
	var existing: Dictionary[String, StringName] = {}
	for tag in tags:
		existing[String(tag)] = tag

	var added: int = 0
	for raw_tag in raw_tags:
		var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		var key: String = String(tag)
		if tag == &"" or existing.has(key):
			continue
		existing[key] = tag
		added += 1

	if added > 0:
		tags = GameplayTagDatabase.canonicalize_tag_array(existing.values())
	return added


func remove_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var index: int = tags.find(tag)
	if index < 0:
		return false
	var updated_tags: Array[StringName] = tags.duplicate()
	updated_tags.remove_at(index)
	tags = updated_tags
	return true


func remove(raw_tag: StringName) -> bool:
	return remove_tag(raw_tag)


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


func clear() -> void:
	if tags.is_empty():
		return
	tags = []


func has_tag(raw_tag: StringName, exact: bool = false) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"":
		return false
	if exact:
		return _exact_tag_set.has(String(tag))
	return _match_tag_set.has(String(tag))


func has(raw_tag: StringName) -> bool:
	return has_tag(raw_tag, false)


func has_exact(raw_tag: StringName) -> bool:
	return has_tag(raw_tag, true)


func has_any(required_tags: Array[StringName], exact: bool = false) -> bool:
	for tag in required_tags:
		if has_tag(tag, exact):
			return true
	return false


func any(required_tags: Array[StringName], exact: bool = false) -> bool:
	return has_any(required_tags, exact)


func has_all(required_tags: Array[StringName], exact: bool = false) -> bool:
	if required_tags.is_empty():
		return true
	for tag in required_tags:
		if not has_tag(tag, exact):
			return false
	return true


func all(required_tags: Array[StringName], exact: bool = false) -> bool:
	return has_all(required_tags, exact)


func none(blocked_tags: Array[StringName], exact: bool = false) -> bool:
	return not has_any(blocked_tags, exact)


func exact(other_tags: Array[StringName]) -> bool:
	return tags == GameplayTagDatabase.canonicalize_tag_array(other_tags)


func overlap_count(other_tags: Array[StringName], exact: bool = false) -> int:
	var overlaps: int = 0
	for tag in GameplayTagDatabase.canonicalize_tag_array(other_tags):
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


func _rebuild_cache() -> void:
	_exact_tag_set.clear()
	_match_tag_set.clear()
	for tag in tags:
		var key: String = String(tag)
		_exact_tag_set[key] = true
		_match_tag_set[key] = true
		for parent in GameplayTagDatabase.get_parent_tags(tag):
			_match_tag_set[String(parent)] = true


func _notify_changed() -> void:
	emit_changed()
	tags_changed.emit()
