@tool
class_name GameplayTagDatabase
extends Resource

signal tags_changed

@export var tags: Array[StringName] = []:
	set(value):
		tags = canonicalize_tag_array(value)
		_rebuild_cache()
		_notify_changed()

@export var tag_descriptions: Dictionary = {}:
	set(value):
		tag_descriptions = value.duplicate()
		_notify_changed()

var _tag_set := {}


static func normalize_tag(raw_tag: Variant) -> StringName:
	if raw_tag == null:
		return &""

	var text := ""
	if raw_tag is GameplayTag:
		text = String(raw_tag.tag_name)
	elif raw_tag is StringName or raw_tag is String:
		text = String(raw_tag)
	else:
		text = str(raw_tag)

	text = text.strip_edges()
	text = text.replace("/", ".")
	text = text.replace("\\", ".")
	text = text.trim_prefix(".").trim_suffix(".")

	var clean_segments: Array[String] = []
	for segment in text.split(".", false):
		var clean := String(segment).strip_edges()
		clean = clean.replace(" ", "")
		if clean.is_empty():
			continue
		clean_segments.append(clean)

	if clean_segments.is_empty():
		return &""
	return StringName(".".join(clean_segments))


static func canonicalize_tag_array(raw_tags: Array) -> Array[StringName]:
	var unique := {}
	for raw_tag in raw_tags:
		var tag := normalize_tag(raw_tag)
		if tag == &"":
			continue
		unique[String(tag)] = tag

	var keys := unique.keys()
	keys.sort()

	var canonical: Array[StringName] = []
	for key in keys:
		canonical.append(unique[key])
	return canonical


static func tags_from_csv_text(csv_text: String) -> Array[StringName]:
	var parsed_tags: Array[StringName] = []
	for line in csv_text.split("\n", false):
		var tag_text := String(line).strip_edges().replace(",", ".")
		var tag := normalize_tag(tag_text)
		if tag != &"":
			parsed_tags.append(tag)
	return canonicalize_tag_array(parsed_tags)


static func tag_matches(owned_tag: Variant, requested_tag: Variant, exact: bool = false) -> bool:
	var owned := String(normalize_tag(owned_tag))
	var requested := String(normalize_tag(requested_tag))
	if owned.is_empty() or requested.is_empty():
		return false
	if exact:
		return owned == requested
	return owned == requested or owned.begins_with(requested + ".")


static func is_valid_tag_name(raw_tag: Variant) -> bool:
	var tag := String(normalize_tag(raw_tag))
	if tag.is_empty():
		return false

	var allowed := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
	for segment in tag.split(".", false):
		if segment.is_empty():
			return false
		for index in range(segment.length()):
			var character := segment.substr(index, 1)
			if not allowed.contains(character):
				return false

	return true


static func get_parent_tags(raw_tag: Variant) -> Array[StringName]:
	var tag := String(normalize_tag(raw_tag))
	var parents: Array[StringName] = []
	if tag.is_empty():
		return parents

	var parts := tag.split(".", false)
	var current := ""
	for index in range(parts.size() - 1):
		current = parts[index] if current.is_empty() else "%s.%s" % [current, parts[index]]
		parents.append(StringName(current))
	return parents


func add_tag(raw_tag: Variant, description: String = "") -> bool:
	var tag := normalize_tag(raw_tag)
	if tag == &"" or not is_valid_tag_name(tag) or has_tag(tag):
		return false

	var added := add_tags([tag]) == 1
	if added and not description.strip_edges().is_empty():
		tag_descriptions[String(tag)] = description.strip_edges()
		_notify_changed()
	return added


func add_tags(raw_tags: Array) -> int:
	var existing := {}
	for tag in tags:
		existing[String(tag)] = tag

	var added := 0
	var changed := false
	for raw_tag in raw_tags:
		var tag := normalize_tag(raw_tag)
		var key := String(tag)
		if tag == &"" or not is_valid_tag_name(tag) or existing.has(key):
			continue

		for parent in get_parent_tags(tag):
			var parent_key := String(parent)
			if not existing.has(parent_key):
				existing[parent_key] = parent
				changed = true

		existing[key] = tag
		added += 1
		changed = true

	if changed:
		tags = canonicalize_tag_array(existing.values())
		_notify_changed()
	return added


func add_tags_from_csv_text(csv_text: String) -> int:
	return add_tags(tags_from_csv_text(csv_text))


func to_csv_text() -> String:
	var lines: Array[String] = []
	for tag in tags:
		lines.append(String(tag))
	if lines.is_empty():
		return ""
	return "\n".join(lines) + "\n"


func remove_tag(raw_tag: Variant, remove_children: bool = false) -> bool:
	var tag := normalize_tag(raw_tag)
	if tag == &"":
		return false
	if not remove_children and _has_children_not_in_remove_set(tag, {}):
		return false

	var before := tags.size()
	var kept: Array[StringName] = []
	for existing in tags:
		if existing == tag:
			continue
		if remove_children and tag_matches(existing, tag, false):
			continue
		kept.append(existing)

	if kept.size() == before:
		return false

	tags = kept
	if remove_children:
		for existing_key in tag_descriptions.keys():
			if tag_matches(existing_key, tag, false):
				tag_descriptions.erase(existing_key)
	else:
		tag_descriptions.erase(String(tag))
	_notify_changed()
	return true


func remove_tags(raw_tags: Array) -> int:
	var remove_set := {}
	for raw_tag in raw_tags:
		var tag := normalize_tag(raw_tag)
		if tag != &"":
			remove_set[String(tag)] = true

	if remove_set.is_empty():
		return 0

	var protected_tags := _get_protected_parent_removals(remove_set)
	var removed := 0
	var kept: Array[StringName] = []
	for existing in tags:
		var existing_key := String(existing)
		if remove_set.has(existing_key):
			if protected_tags.has(existing_key):
				kept.append(existing)
				continue
			removed += 1
			continue
		kept.append(existing)

	if removed > 0:
		tags = kept
		for removed_key in remove_set.keys():
			tag_descriptions.erase(removed_key)
		_notify_changed()
	return removed


func ensure_parent_tags(raw_tag: Variant = &"") -> bool:
	var changed := false
	if raw_tag == null or normalize_tag(raw_tag) == &"":
		for tag in tags.duplicate():
			for parent in get_parent_tags(tag):
				changed = _add_tag_unchecked(parent) or changed
	else:
		for parent in get_parent_tags(raw_tag):
			changed = _add_tag_unchecked(parent) or changed

	if changed:
		_notify_changed()
	return changed


func has_tag(raw_tag: Variant) -> bool:
	if _tag_set.size() != tags.size():
		_rebuild_cache()
	return _tag_set.has(String(normalize_tag(raw_tag)))


func get_tag(raw_tag: Variant) -> GameplayTag:
	var tag := normalize_tag(raw_tag)
	if not has_tag(tag):
		return null
	return GameplayTag.new(tag)


func get_all_tags() -> Array[StringName]:
	return tags.duplicate()


func get_children(raw_parent_tag: Variant, recursive: bool = false) -> Array[GameplayTag]:
	var parent := String(normalize_tag(raw_parent_tag))
	var children: Array[GameplayTag] = []
	if parent.is_empty():
		return children

	for tag in tags:
		var text := String(tag)
		if not text.begins_with(parent + "."):
			continue
		if not recursive:
			var rest := text.substr(parent.length() + 1)
			if rest.contains("."):
				continue
		children.append(GameplayTag.new(tag))
	return children


func find_tags(search_text: String = "") -> Array[StringName]:
	var needle := search_text.strip_edges().to_lower()
	if needle.is_empty():
		return get_all_tags()

	var found: Array[StringName] = []
	for tag in tags:
		if String(tag).to_lower().contains(needle):
			found.append(tag)
	return found


func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	var missing_parent_errors := {}
	for tag in tags:
		var text := String(tag)
		if text.is_empty():
			errors.append("Empty gameplay tag")
		elif seen.has(text):
			errors.append("Duplicate gameplay tag: %s" % text)
		elif not is_valid_tag_name(tag):
			errors.append("Invalid gameplay tag: %s" % text)
		for parent in get_parent_tags(tag):
			var parent_text := String(parent)
			if not has_tag(parent) and not missing_parent_errors.has(parent_text):
				errors.append("Missing parent gameplay tag: %s" % parent_text)
				missing_parent_errors[parent_text] = true
		seen[text] = true
	return errors


func _add_tag_unchecked(tag: StringName) -> bool:
	if tag == &"" or has_tag(tag):
		return false
	tags.append(tag)
	tags = canonicalize_tag_array(tags)
	return true


func _has_children_not_in_remove_set(tag: StringName, remove_set: Dictionary) -> bool:
	var parent := String(tag)
	for existing in tags:
		var text := String(existing)
		if not text.begins_with(parent + "."):
			continue
		if not remove_set.has(text):
			return true
	return false


func _get_protected_parent_removals(remove_set: Dictionary) -> Dictionary:
	var protected_tags := {}
	for existing in tags:
		var existing_key := String(existing)
		if remove_set.has(existing_key):
			continue
		for parent in get_parent_tags(existing):
			var parent_key := String(parent)
			if remove_set.has(parent_key):
				protected_tags[parent_key] = true
	return protected_tags


func _rebuild_cache() -> void:
	_tag_set.clear()
	for tag in tags:
		_tag_set[String(tag)] = true


func _notify_changed() -> void:
	emit_changed()
	tags_changed.emit()
