@tool
class_name GameplayTagDatabase
extends Resource

signal tags_changed

@export var tags: Array[StringName] = []:
	set(value):
		tags = canonicalize_tag_array(value)
		_rebuild_cache()
		_notify_changed()

@export var tag_descriptions: Dictionary[String, String] = {}:
	set(value):
		tag_descriptions = value.duplicate()
		_notify_changed()

var _tag_set: Dictionary[String, bool] = {}


static func normalize_tag(raw_tag: StringName) -> StringName:
	if raw_tag == &"":
		return &""

	var text: String = String(raw_tag)
	text = text.strip_edges()
	text = text.replace("/", ".")
	text = text.replace("\\", ".")
	text = text.trim_prefix(".").trim_suffix(".")

	var clean_segments: Array[String] = []
	for segment in text.split(".", false):
		var clean: String = String(segment).strip_edges()
		clean = clean.replace(" ", "")
		if clean.is_empty():
			continue
		clean_segments.append(clean)

	if clean_segments.is_empty():
		return &""
	return StringName(".".join(clean_segments))


static func canonicalize_tag_array(raw_tags: Array[StringName]) -> Array[StringName]:
	var unique: Dictionary[String, StringName] = {}
	for raw_tag in raw_tags:
		var tag: StringName = normalize_tag(raw_tag)
		if tag == &"":
			continue
		unique[String(tag)] = tag

	var sorted_keys: Array[String] = []
	for key in unique:
		sorted_keys.append(key)
	sorted_keys.sort()

	var canonical: Array[StringName] = []
	for key in sorted_keys:
		canonical.append(unique[key])
	return canonical


static func tags_from_csv_text(csv_text: String) -> Array[StringName]:
	var parsed_tags: Array[StringName] = []
	for line in csv_text.split("\n", false):
		var tag_text: String = String(line).strip_edges().replace(",", ".")
		var tag: StringName = normalize_tag(StringName(tag_text))
		if tag != &"":
			parsed_tags.append(tag)
	return canonicalize_tag_array(parsed_tags)


static func tag_matches(
	owned_tag: StringName, requested_tag: StringName, exact: bool = false
) -> bool:
	var owned: String = String(normalize_tag(owned_tag))
	var requested: String = String(normalize_tag(requested_tag))
	if owned.is_empty() or requested.is_empty():
		return false
	if exact:
		return owned == requested
	return owned == requested or owned.begins_with(requested + ".")


static func is_valid_tag_name(raw_tag: StringName) -> bool:
	var tag: String = String(normalize_tag(raw_tag))
	if tag.is_empty():
		return false

	var allowed: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
	for segment in tag.split(".", false):
		if segment.is_empty():
			return false
		for index in range(segment.length()):
			var character: String = segment.substr(index, 1)
			if not allowed.contains(character):
				return false

	return true


static func get_parent_tags(raw_tag: StringName) -> Array[StringName]:
	var tag: String = String(normalize_tag(raw_tag))
	var parents: Array[StringName] = []
	if tag.is_empty():
		return parents

	var parts: PackedStringArray = tag.split(".", false)
	var current: String = ""
	for index in range(parts.size() - 1):
		current = parts[index] if current.is_empty() else "%s.%s" % [current, parts[index]]
		parents.append(StringName(current))
	return parents


func add_tag(raw_tag: StringName, description: String = "") -> bool:
	var tag: StringName = normalize_tag(raw_tag)
	if tag == &"" or not is_valid_tag_name(tag) or has_tag(tag):
		return false

	var added: bool = add_tags([tag]) == 1
	if added and not description.strip_edges().is_empty():
		tag_descriptions[String(tag)] = description.strip_edges()
		_notify_changed()
	return added


func set_tag_description(raw_tag: StringName, description: String) -> bool:
	var tag: StringName = normalize_tag(raw_tag)
	if not has_tag(tag):
		return false

	var tag_key: String = String(tag)
	var clean_description: String = description.strip_edges()
	var current_description: String = tag_descriptions.get(tag_key, "")
	if current_description == clean_description:
		return false

	if clean_description.is_empty():
		tag_descriptions.erase(tag_key)
	else:
		tag_descriptions[tag_key] = clean_description
	_notify_changed()
	return true


func rename_tag(raw_tag: StringName, raw_new_tag: StringName) -> bool:
	var tag: StringName = normalize_tag(raw_tag)
	var new_tag: StringName = normalize_tag(raw_new_tag)
	if not has_tag(tag) or new_tag == &"" or not is_valid_tag_name(new_tag) or tag == new_tag:
		return false

	var tag_text: String = String(tag)
	var new_tag_text: String = String(new_tag)
	if new_tag_text.begins_with("%s." % tag_text):
		return false

	var renamed_tags: Dictionary[StringName, StringName] = {}
	var unaffected_tags: Dictionary[String, bool] = {}
	for existing_tag in tags:
		if tag_matches(existing_tag, tag, false):
			var suffix: String = String(existing_tag).trim_prefix(tag_text)
			renamed_tags[existing_tag] = StringName("%s%s" % [new_tag_text, suffix])
		else:
			unaffected_tags[String(existing_tag)] = true

	for renamed_tag in renamed_tags.values():
		if unaffected_tags.has(String(renamed_tag)):
			return false

	var updated_tags: Array[StringName] = []
	for existing_tag in tags:
		if renamed_tags.has(existing_tag):
			updated_tags.append(renamed_tags[existing_tag])
		else:
			updated_tags.append(existing_tag)
	for renamed_tag in renamed_tags.values():
		updated_tags.append_array(get_parent_tags(renamed_tag))

	var updated_descriptions: Dictionary[String, String] = tag_descriptions.duplicate(true)
	for description_key in tag_descriptions.keys():
		var described_tag: StringName = normalize_tag(StringName(description_key))
		if not renamed_tags.has(described_tag):
			continue
		var renamed_description_key: String = String(renamed_tags[described_tag])
		var description: String = tag_descriptions[description_key]
		updated_descriptions.erase(description_key)
		updated_descriptions[renamed_description_key] = description

	_prune_empty_old_parents(updated_tags, updated_descriptions, get_parent_tags(tag))
	tags = canonicalize_tag_array(updated_tags)
	tag_descriptions = updated_descriptions
	return true


func _prune_empty_old_parents(
	updated_tags: Array[StringName],
	updated_descriptions: Dictionary[String, String],
	old_parents: Array[StringName],
) -> void:
	old_parents.reverse()
	for old_parent in old_parents:
		var old_parent_text: String = String(old_parent)
		if updated_descriptions.has(old_parent_text):
			continue
		var has_remaining_child: bool = false
		for candidate in updated_tags:
			if String(candidate).begins_with(old_parent_text + "."):
				has_remaining_child = true
				break
		if not has_remaining_child:
			updated_tags.erase(old_parent)


func add_tags(raw_tags: Array[StringName]) -> int:
	var existing: Dictionary[String, StringName] = {}
	for tag in tags:
		existing[String(tag)] = tag

	var added: int = 0
	var changed: bool = false
	for raw_tag in raw_tags:
		var tag: StringName = normalize_tag(raw_tag)
		var key: String = String(tag)
		if tag == &"" or not is_valid_tag_name(tag) or existing.has(key):
			continue

		for parent in get_parent_tags(tag):
			var parent_key: String = String(parent)
			if not existing.has(parent_key):
				existing[parent_key] = parent
				changed = true

		existing[key] = tag
		added += 1
		changed = true

	if changed:
		tags = canonicalize_tag_array(existing.values())
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


func remove_tag(raw_tag: StringName, remove_children: bool = false) -> bool:
	var tag: StringName = normalize_tag(raw_tag)
	if tag == &"":
		return false
	if not remove_children and _has_children_not_in_remove_set(tag, {}):
		return false

	var before: int = tags.size()
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
	var description_changed: bool = false
	if remove_children:
		for existing_key in tag_descriptions.keys():
			if tag_matches(StringName(existing_key), tag, false):
				tag_descriptions.erase(existing_key)
				description_changed = true
	else:
		var tag_key: String = String(tag)
		if tag_descriptions.has(tag_key):
			tag_descriptions.erase(tag_key)
			description_changed = true
	if description_changed:
		_notify_changed()
	return true


func remove_tags(raw_tags: Array[StringName]) -> int:
	var remove_set: Dictionary[String, bool] = {}
	for raw_tag in raw_tags:
		var tag: StringName = normalize_tag(raw_tag)
		if tag != &"":
			remove_set[String(tag)] = true

	if remove_set.is_empty():
		return 0

	var protected_tags: Dictionary[String, bool] = _get_protected_parent_removals(remove_set)
	var removed_keys: Dictionary[String, bool] = {}
	var removed: int = 0
	var kept: Array[StringName] = []
	for existing in tags:
		var existing_key: String = String(existing)
		if remove_set.has(existing_key):
			if protected_tags.has(existing_key):
				kept.append(existing)
				continue
			removed_keys[existing_key] = true
			removed += 1
			continue
		kept.append(existing)

	if removed > 0:
		tags = kept
		var description_changed: bool = false
		for removed_key in removed_keys.keys():
			if tag_descriptions.has(removed_key):
				tag_descriptions.erase(removed_key)
				description_changed = true
		if description_changed:
			_notify_changed()
	return removed


func ensure_parent_tags(raw_tag: StringName = &"") -> bool:
	var changed: bool = false
	if raw_tag == &"":
		for tag in tags.duplicate():
			for parent in get_parent_tags(tag):
				changed = _add_tag_unchecked(parent) or changed
	else:
		for parent in get_parent_tags(raw_tag):
			changed = _add_tag_unchecked(parent) or changed

	return changed


func has_tag(raw_tag: StringName) -> bool:
	if _tag_set.size() != tags.size():
		_rebuild_cache()
	return _tag_set.has(String(normalize_tag(raw_tag)))


func get_tag(raw_tag: StringName) -> GameplayTag:
	var tag: StringName = normalize_tag(raw_tag)
	if not has_tag(tag):
		return null
	return GameplayTag.new(tag)


func get_all_tags() -> Array[StringName]:
	return tags.duplicate()


func get_children(raw_parent_tag: StringName, recursive: bool = false) -> Array[GameplayTag]:
	var parent: String = String(normalize_tag(raw_parent_tag))
	var children: Array[GameplayTag] = []
	if parent.is_empty():
		return children

	for tag in tags:
		var text: String = String(tag)
		if not text.begins_with(parent + "."):
			continue
		if not recursive:
			var rest: String = text.substr(parent.length() + 1)
			if rest.contains("."):
				continue
		children.append(GameplayTag.new(tag))
	return children


func find_tags(search_text: String = "") -> Array[StringName]:
	var needle: String = search_text.strip_edges().to_lower()
	if needle.is_empty():
		return get_all_tags()

	var found: Array[StringName] = []
	for tag in tags:
		if String(tag).to_lower().contains(needle):
			found.append(tag)
	return found


func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary[String, bool] = {}
	var missing_parent_errors: Dictionary[String, bool] = {}
	for tag in tags:
		var text: String = String(tag)
		if text.is_empty():
			errors.append("Empty gameplay tag")
		elif seen.has(text):
			errors.append("Duplicate gameplay tag: %s" % text)
		elif not is_valid_tag_name(tag):
			errors.append("Invalid gameplay tag: %s" % text)
		for parent in get_parent_tags(tag):
			var parent_text: String = String(parent)
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


func _has_children_not_in_remove_set(tag: StringName, remove_set: Dictionary[String, bool]) -> bool:
	var parent: String = String(tag)
	for existing in tags:
		var text: String = String(existing)
		if not text.begins_with(parent + "."):
			continue
		if not remove_set.has(text):
			return true
	return false


func _get_protected_parent_removals(
	remove_set: Dictionary[String, bool]
) -> Dictionary[String, bool]:
	var protected_tags: Dictionary[String, bool] = {}
	for existing in tags:
		var existing_key: String = String(existing)
		if remove_set.has(existing_key):
			continue
		for parent in get_parent_tags(existing):
			var parent_key: String = String(parent)
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
