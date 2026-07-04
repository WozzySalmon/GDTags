@tool
class_name GameplayTagDatabase
extends Resource

const GameplayTagUtilsScript := preload("res://addons/gameplay_tags/runtime/gameplay_tag_utils.gd")

@export var tags: Array[StringName] = []
@export var tag_descriptions: Dictionary = {}


func normalize_tag_name(raw_tag: Variant) -> StringName:
	return GameplayTagUtilsScript.normalize_tag_name(raw_tag)


func add_tag(raw_tag: Variant, description: String = "") -> bool:
	var tag := normalize_tag_name(raw_tag)
	if tag == &"" or tags.has(tag):
		return false

	tags.append(tag)

	if not description.is_empty():
		tag_descriptions[String(tag)] = description

	emit_changed()
	return true


func add_tags(raw_tags: Array) -> int:
	var added := 0
	for raw_tag in raw_tags:
		var tag := normalize_tag_name(raw_tag)
		if tag == &"" or tags.has(tag):
			continue
		tags.append(tag)
		added += 1
	if added > 0:
		emit_changed()
	return added


func remove_tag(raw_tag: Variant, remove_children: bool = false) -> bool:
	var tag := normalize_tag_name(raw_tag)
	if tag == &"":
		return false

	if not remove_children:
		var index := tags.find(tag)
		if index < 0:
			return false
		tags.remove_at(index)
		tag_descriptions.erase(String(tag))
		emit_changed()
		return true

	var removed := false
	var kept: Array[StringName] = []
	var tag_text := String(tag)
	for existing in tags:
		var existing_text := String(existing)
		var should_remove := existing == tag or existing_text.begins_with(tag_text + ".")

		if should_remove:
			removed = true
			tag_descriptions.erase(existing_text)
		else:
			kept.append(existing)

	if removed:
		tags = kept
		emit_changed()
	return removed


func remove_tags(raw_tags: Array, remove_children: bool = false) -> int:
	var removed := 0
	for raw_tag in raw_tags:
		var tag := normalize_tag_name(raw_tag)
		if tag == &"":
			continue

		if not remove_children:
			var index := tags.find(tag)
			if index < 0:
				continue
			tags.remove_at(index)
			tag_descriptions.erase(String(tag))
			removed += 1
			continue

		var kept: Array[StringName] = []
		var tag_text := String(tag)
		var removed_this_tag := false
		for existing in tags:
			var existing_text := String(existing)
			var should_remove := existing == tag or existing_text.begins_with(tag_text + ".")
			if should_remove:
				removed_this_tag = true
				tag_descriptions.erase(existing_text)
			else:
				kept.append(existing)
		if removed_this_tag:
			tags = kept
			removed += 1

	if removed > 0:
		emit_changed()
	return removed


func has_tag(raw_tag: Variant) -> bool:
	return tags.has(normalize_tag_name(raw_tag))


func get_tag(raw_tag: Variant) -> GameplayTag:
	var tag := normalize_tag_name(raw_tag)
	if tag == &"" or not tags.has(tag):
		return null
	return GameplayTag.new(tag)


func get_parent(raw_tag: Variant) -> GameplayTag:
	var tag := normalize_tag_name(raw_tag)
	var text := String(tag)
	var dot := text.rfind(".")
	if dot <= 0:
		return null

	var parent := StringName(text.substr(0, dot))
	if not tags.has(parent):
		return null
	return GameplayTag.new(parent)


func get_children(raw_parent: Variant, recursive: bool = false) -> Array[GameplayTag]:
	var parent := normalize_tag_name(raw_parent)
	var parent_text := String(parent)
	var children: Array[GameplayTag] = []
	if parent_text.is_empty():
		return children

	var prefix := parent_text + "."
	for tag in tags:
		var text := String(tag)
		if not text.begins_with(prefix):
			continue
		var rest := text.substr(prefix.length())
		if recursive or not rest.contains("."):
			children.append(GameplayTag.new(tag))
	return children


func get_all_tags() -> Array[GameplayTag]:
	var result: Array[GameplayTag] = []
	for tag in tags:
		result.append(GameplayTag.new(tag))
	return result


func ensure_parent_tags() -> bool:
	var changed := false
	var missing: Array[StringName] = []

	for tag in tags:
		var text := String(tag)
		while text.contains("."):
			text = text.substr(0, text.rfind("."))
			var parent := StringName(text)
			if not tags.has(parent) and not missing.has(parent):
				missing.append(parent)

	for parent in missing:
		tags.append(parent)
		changed = true

	if changed:
		tags.sort_custom(Callable(self, "_sort_string_names"))
		emit_changed()
	return changed


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}

	for tag in tags:
		var text := String(tag)
		if text.is_empty():
			errors.append("Empty tag name")
		if seen.has(text):
			errors.append("Duplicate tag: %s" % text)
		seen[text] = true
		if text.begins_with(".") or text.ends_with(".") or text.contains(".."):
			errors.append("Invalid hierarchy path: %s" % text)

	return errors


func _sort_string_names(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
