@tool
class_name GameplayTagContainer
extends Resource

const GameplayTagUtilsScript := preload("res://addons/gameplay_tags/runtime/gameplay_tag_utils.gd")

@export var tags: Array[StringName] = []


func add(raw_tag: Variant) -> bool:
	var tag := _normalize(raw_tag)
	if tag == &"" or tags.has(tag):
		return false
	tags.append(tag)
	tags.sort_custom(Callable(self, "_sort_string_names"))
	emit_changed()
	return true


func add_tag(raw_tag: Variant) -> bool:
	return add(raw_tag)


func add_tags(raw_tags: Array) -> int:
	var added := 0
	for raw_tag in raw_tags:
		var tag := _normalize(raw_tag)
		if tag == &"" or tags.has(tag):
			continue
		tags.append(tag)
		added += 1
	if added > 0:
		tags.sort_custom(Callable(self, "_sort_string_names"))
		emit_changed()
	return added


func remove(raw_tag: Variant) -> bool:
	var tag := _normalize(raw_tag)
	var index := tags.find(tag)
	if index < 0:
		return false
	tags.remove_at(index)
	emit_changed()
	return true


func remove_tag(raw_tag: Variant) -> bool:
	return remove(raw_tag)


func remove_tags(raw_tags: Array) -> int:
	var removed := 0
	for raw_tag in raw_tags:
		var tag := _normalize(raw_tag)
		var index := tags.find(tag)
		if index < 0:
			continue
		tags.remove_at(index)
		removed += 1
	if removed > 0:
		emit_changed()
	return removed


func has_exact(raw_tag: Variant) -> bool:
	return tags.has(_normalize(raw_tag))


func has_tag_exact(raw_tag: Variant) -> bool:
	return has_exact(raw_tag)


func has(raw_tag: Variant) -> bool:
	var requested := String(_normalize(raw_tag))
	if requested.is_empty():
		return false

	for owned in tags:
		var owned_text := String(owned)
		if owned_text == requested or owned_text.begins_with(requested + "."):
			return true
	return false


func has_tag(raw_tag: Variant) -> bool:
	return has(raw_tag)


func has_any(other: Variant) -> bool:
	for tag in _extract_tags(other):
		if has(tag):
			return true
	return false


func has_all(other: Variant) -> bool:
	var other_tags := _extract_tags(other)
	for tag in other_tags:
		if not has(tag):
			return false
	return true


func matches_query(query: Variant) -> bool:
	return query != null and query.has_method("matches") and query.matches(self)


func clear() -> void:
	if tags.is_empty():
		return
	tags.clear()
	emit_changed()


func to_array() -> Array[StringName]:
	return tags.duplicate()


func duplicate_container() -> GameplayTagContainer:
	var copy := GameplayTagContainer.new()
	copy.tags = tags.duplicate()
	return copy


func _extract_tags(value: Variant) -> Array[StringName]:
	if value is GameplayTagContainer:
		return value.tags
	if value is GameplayTag:
		return [value.tag_name]
	if value is Array:
		var result: Array[StringName] = []
		for item in value:
			var tag := _normalize(item)
			if tag != &"":
				result.append(tag)
		return result
	var single := _normalize(value)
	if single == &"":
		return []
	return [single]


func _normalize(raw_tag: Variant) -> StringName:
	return GameplayTagUtilsScript.normalize_tag_name(raw_tag)


func _sort_string_names(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
