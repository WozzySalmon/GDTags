@tool
class_name GameplayTagDatabase
extends Resource
## The project's central catalog of every valid gameplay tag.
## Owns tag names, their parent hierarchy, and optional descriptions. Adding a child
## creates its missing parents automatically. Mutate it through its methods so the
## hierarchy and change signals stay correct.

signal tags_changed

const MAX_REDIRECT_DEPTH: int = 16

@export var tags: Array[StringName] = []:
	set(value):
		var canonical_tags: Array[StringName] = canonicalize_valid_tag_array(value)
		if tags == canonical_tags:
			return
		tags = canonical_tags
		_rebuild_cache()
		_notify_changed()

@export var tag_descriptions: Dictionary[String, String] = {}:
	set(value):
		if tag_descriptions == value:
			return
		tag_descriptions = value.duplicate()
		_notify_changed()

## Maps a retired tag name to the tag that replaced it. Recorded automatically by
## [method rename_tag] so data still referring to the old name keeps resolving.
## Chains are followed, so renaming A to B and then B to C leaves A resolving to C.
@export var tag_redirects: Dictionary[StringName, StringName] = {}:
	set(value):
		if tag_redirects == value:
			return
		tag_redirects = value.duplicate()
		# Load order between this and `tags` is not guaranteed, so enforce the
		# "a live tag is never a redirect source" invariant from both sides.
		_drop_redirects_for_live_tags()
		_notify_changed()

var _tag_set: Dictionary[StringName, bool] = {}
var _suppress_change_notifications: bool = false


## Returns [param raw_tag] in canonical form: trimmed, slash-separated paths
## converted to dots, spaces removed, and empty segments dropped.
static func normalize_tag(raw_tag: StringName) -> StringName:
	if raw_tag == &"":
		return &""

	var text: String = String(raw_tag)
	if _is_already_normalized(text):
		return raw_tag

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


# Normalization allocates several intermediate strings, and it runs on every tag of
# every container built during a target check. Tags are almost always already normal,
# so detect that in one pass and hand the original StringName straight back.
static func _is_already_normalized(text: String) -> bool:
	if text.is_empty():
		return false
	if text.begins_with(".") or text.ends_with("."):
		return false
	if text.contains("..") or text.contains("/") or text.contains("\\"):
		return false

	for index in range(text.length()):
		var code: int = text.unicode_at(index)
		if code != 46 and not _is_allowed_tag_character(code):
			return false
	return true


## Canonicalizes and drops tags whose characters no database could ever accept.
## Use this wherever tags are authored; plain canonicalization only normalizes shape.
static func canonicalize_valid_tag_array(raw_tags: Array[StringName]) -> Array[StringName]:
	var valid_tags: Array[StringName] = []
	for tag in canonicalize_tag_array(raw_tags):
		if is_canonical_tag_name(tag):
			valid_tags.append(tag)
		else:
			push_warning("Ignoring gameplay tag with unsupported characters: %s" % String(tag))
	return valid_tags


## Returns [param raw_tags] normalized, de-duplicated, and alphabetically sorted.
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


## Parses one tag per line, treating commas and slashes as hierarchy separators.
static func tags_from_csv_text(csv_text: String) -> Array[StringName]:
	var parsed_tags: Array[StringName] = []
	for line in csv_text.split("\n", false):
		var tag_text: String = String(line).strip_edges().replace(",", ".")
		var tag: StringName = normalize_tag(StringName(tag_text))
		if tag != &"":
			parsed_tags.append(tag)
	return canonicalize_tag_array(parsed_tags)


## Returns whether [param owned_tag] satisfies [param requested_tag].
## A parent request matches an owned child unless [param exact] is true.
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


## Returns whether [param raw_tag] normalizes to a usable tag name.
## Segments may contain only ASCII letters, digits, underscores, and hyphens.
static func is_valid_tag_name(raw_tag: StringName) -> bool:
	return is_canonical_tag_name(normalize_tag(raw_tag))


## Same check as [method is_valid_tag_name] for a tag that is already normalized.
## Skips the normalization pass, which allocates several intermediate strings.
static func is_canonical_tag_name(tag: StringName) -> bool:
	var tag_text: String = String(tag)
	if tag_text.is_empty():
		return false

	for segment in tag_text.split(".", false):
		if segment.is_empty():
			return false
		for index in range(segment.length()):
			if not _is_allowed_tag_character(segment.unicode_at(index)):
				return false

	return true


static func _is_allowed_tag_character(code: int) -> bool:
	if code >= 48 and code <= 57:
		return true
	if code >= 65 and code <= 90:
		return true
	if code >= 97 and code <= 122:
		return true
	return code == 95 or code == 45


## Returns every ancestor of [param raw_tag], from the root down to the immediate parent.
static func get_parent_tags(raw_tag: StringName) -> Array[StringName]:
	return get_canonical_parent_tags(normalize_tag(raw_tag))


## Same result as [method get_parent_tags] for a tag that is already normalized.
## Skips the normalization pass during container and component lookup-cache rebuilds.
static func get_canonical_parent_tags(tag_name: StringName) -> Array[StringName]:
	var tag: String = String(tag_name)
	var parents: Array[StringName] = []
	if tag.is_empty():
		return parents

	var parts: PackedStringArray = tag.split(".", false)
	var current: String = ""
	for index in range(parts.size() - 1):
		current = parts[index] if current.is_empty() else "%s.%s" % [current, parts[index]]
		parents.append(StringName(current))
	return parents


## Adds one tag plus any missing parents. Returns whether it was added.
func add_tag(raw_tag: StringName, description: String = "") -> bool:
	var tag: StringName = normalize_tag(raw_tag)
	if tag == &"" or not is_canonical_tag_name(tag) or has_tag(tag):
		return false

	var added: bool = add_tags([tag]) == 1
	if added and not description.strip_edges().is_empty():
		tag_descriptions[String(tag)] = description.strip_edges()
		_notify_changed()
	return added


## Sets or clears a registered tag's description. Returns whether anything changed.
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


## Renames or moves a tag and its whole branch, migrating descriptions.
## Rejects collisions with existing tags and moves of a branch beneath itself.
func rename_tag(raw_tag: StringName, raw_new_tag: StringName) -> bool:
	var tag: StringName = normalize_tag(raw_tag)
	var new_tag: StringName = normalize_tag(raw_new_tag)
	if not has_tag(tag) or new_tag == &"" or not is_canonical_tag_name(new_tag) or tag == new_tag:
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
	tags = updated_tags
	tag_descriptions = updated_descriptions
	# Must follow the tag assignment: while the retired names are still registered, the
	# "a live tag is never a redirect source" guard would drop each new entry on sight.
	_record_rename_redirects(renamed_tags)
	return true


# Every tag the rename retired gets a redirect to its replacement, so authored data
# still naming the old branch keeps resolving. Existing redirects that pointed at a
# retired name are re-pointed at the replacement rather than left dangling.
func _record_rename_redirects(renamed_tags: Dictionary[StringName, StringName]) -> void:
	var updated_redirects: Dictionary[StringName, StringName] = tag_redirects.duplicate()
	for retired_tag in renamed_tags:
		var replacement: StringName = renamed_tags[retired_tag]
		for existing_key in updated_redirects.keys():
			if normalize_tag(updated_redirects[existing_key]) == retired_tag:
				updated_redirects[existing_key] = replacement
		updated_redirects[retired_tag] = replacement
	# A tag can be renamed back to a name that used to redirect elsewhere; the live
	# tag must win over the stale entry.
	for renamed_tag in renamed_tags.values():
		updated_redirects.erase(renamed_tag)
	tag_redirects = updated_redirects


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


## Adds several tags plus any missing parents. Returns how many were new.
func add_tags(raw_tags: Array[StringName]) -> int:
	var existing: Dictionary[String, StringName] = {}
	for tag in tags:
		existing[String(tag)] = tag

	var added: int = 0
	var changed: bool = false
	for raw_tag in raw_tags:
		var tag: StringName = normalize_tag(raw_tag)
		var key: String = String(tag)
		if tag == &"" or not is_canonical_tag_name(tag) or existing.has(key):
			continue

		for parent in get_canonical_parent_tags(tag):
			var parent_key: String = String(parent)
			if not existing.has(parent_key):
				existing[parent_key] = parent
				changed = true

		existing[key] = tag
		added += 1
		changed = true

	if changed:
		var updated_tags: Array[StringName] = []
		updated_tags.assign(existing.values())
		tags = updated_tags
	return added


## Imports tags from CSV text and returns how many were new.
func add_tags_from_csv_text(csv_text: String) -> int:
	return add_tags(tags_from_csv_text(csv_text))


## Serializes every tag to newline-separated CSV text.
func to_csv_text() -> String:
	var lines: Array[String] = []
	for tag in tags:
		lines.append(String(tag))
	if lines.is_empty():
		return ""
	return "\n".join(lines) + "\n"


## Removes a tag. Fails when it still has children unless [param remove_children] is true.
func remove_tag(raw_tag: StringName, remove_children: bool = false) -> bool:
	var tag: StringName = normalize_tag(raw_tag)
	if tag == &"":
		return false
	if not remove_children and _has_children(tag):
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


## Removes several tags, keeping any parent that still has children. Returns the count removed.
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


## Creates missing parents for one tag, or for every tag when [param raw_tag] is empty.
func ensure_parent_tags(raw_tag: StringName = &"") -> bool:
	var existing: Dictionary[String, StringName] = {}
	for tag in tags:
		existing[String(tag)] = tag

	var source_tags: Array[StringName] = []
	if raw_tag == &"":
		source_tags = tags
	else:
		source_tags.append(normalize_tag(raw_tag))
	var changed: bool = false
	for source_tag in source_tags:
		for parent in get_canonical_parent_tags(source_tag):
			var parent_key: String = String(parent)
			if existing.has(parent_key):
				continue
			existing[parent_key] = parent
			changed = true

	if changed:
		var updated_tags: Array[StringName] = []
		updated_tags.assign(existing.values())
		tags = updated_tags
	return changed


## Replaces the whole database in a single pass, keeping parents and signals correct.
## Prefer this over per-tag mutation when applying a known end state, such as an
## editor undo/redo step: per-tag rebuilds recanonicalize the array once per tag.
## [param redirects] is intentionally required so callers cannot silently discard
## rename history while replacing the tag and description state.
func set_state(
	raw_tags: Array[StringName],
	descriptions: Dictionary[String, String],
	redirects: Dictionary[StringName, StringName],
) -> void:
	var with_parents: Array[StringName] = []
	for tag in canonicalize_valid_tag_array(raw_tags):
		with_parents.append(tag)
		with_parents.append_array(get_canonical_parent_tags(tag))

	_suppress_change_notifications = true
	tags = with_parents

	var kept_descriptions: Dictionary[String, String] = {}
	for description_key in descriptions:
		var description: String = descriptions[description_key].strip_edges()
		if description.is_empty():
			continue
		var tag_name: StringName = normalize_tag(StringName(description_key))
		var tag_key: String = String(tag_name)
		if _tag_set.has(tag_name):
			kept_descriptions[tag_key] = description
	tag_descriptions = kept_descriptions
	tag_redirects = redirects

	_suppress_change_notifications = false
	_notify_changed()


## Returns whether [param raw_tag] is registered.
## Resolves [param raw_tag] to the tag that replaced it, following redirect chains.
## Returns the normalized input unchanged when no redirect applies. A redirect to a
## tag that is not registered is still followed, so a broken chain stays visible to
## [method validate] rather than silently resolving to the retired name.
func resolve_tag(raw_tag: StringName) -> StringName:
	var tag: StringName = normalize_tag(raw_tag)
	if tag == &"" or tag_redirects.is_empty():
		return tag

	var seen: Dictionary[StringName, bool] = {}
	var depth: int = 0
	while tag_redirects.has(tag):
		if seen.has(tag) or depth >= MAX_REDIRECT_DEPTH:
			push_error("Gameplay tag redirect cycle starting at %s" % String(raw_tag))
			return normalize_tag(raw_tag)
		seen[tag] = true
		depth += 1
		tag = normalize_tag(tag_redirects[tag])
	return tag


## Records that [param raw_tag] has been replaced by [param raw_new_tag].
## Refuses self-redirects and any entry that would close a cycle.
func add_redirect(raw_tag: StringName, raw_new_tag: StringName) -> bool:
	var from_tag: StringName = normalize_tag(raw_tag)
	var to_tag: StringName = normalize_tag(raw_new_tag)
	if from_tag == &"" or to_tag == &"" or from_tag == to_tag:
		return false
	if has_tag(from_tag):
		return false
	if not is_canonical_tag_name(from_tag) or not is_canonical_tag_name(to_tag):
		return false
	if tag_redirects.get(from_tag, &"") == to_tag:
		return false
	if _redirect_would_cycle(from_tag, to_tag):
		return false

	tag_redirects[from_tag] = to_tag
	_notify_changed()
	return true


## Drops a redirect. Returns whether one was present.
func remove_redirect(raw_tag: StringName) -> bool:
	var from_tag: StringName = normalize_tag(raw_tag)
	if not tag_redirects.has(from_tag):
		return false
	tag_redirects.erase(from_tag)
	_notify_changed()
	return true


## Returns every retired tag name that currently redirects somewhere.
func get_redirected_tags() -> Array[StringName]:
	var retired: Array[StringName] = []
	retired.assign(tag_redirects.keys())
	retired.sort()
	return retired


## Returns whether the normalized name itself is currently registered.
## Retired names are not resolved; call [method resolve_tag] first when authored data
## should remain valid after a rename.
func has_tag(raw_tag: StringName) -> bool:
	if _tag_set.has(raw_tag):
		return true
	var normalized_tag: StringName = normalize_tag(raw_tag)
	return normalized_tag != &"" and _tag_set.has(normalized_tag)


## Returns a GameplayTag for a registered tag, or null when it is unknown.
func get_tag(raw_tag: StringName) -> GameplayTag:
	var tag: StringName = normalize_tag(raw_tag)
	if not has_tag(tag):
		return null
	return GameplayTag.new(tag)


## Returns a copy of every registered tag.
func get_all_tags() -> Array[StringName]:
	return tags.duplicate()


## Returns the children of [param raw_parent_tag], recursively when [param recursive] is true.
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


## Returns tags whose name or description contains [param search_text], case-insensitively.
func find_tags(search_text: String = "") -> Array[StringName]:
	var needle: String = search_text.strip_edges().to_lower()
	if needle.is_empty():
		return get_all_tags()

	var found: Array[StringName] = []
	for tag in tags:
		var tag_text: String = String(tag)
		var description: String = String(tag_descriptions.get(tag_text, ""))
		if tag_text.to_lower().contains(needle) or description.to_lower().contains(needle):
			found.append(tag)
	return found


## Returns a list of missing-parent and redirect problems.
## Empty, duplicate, and malformed names cannot survive the [member tags] setter.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var missing_parent_errors: Dictionary[String, bool] = {}
	for tag in tags:
		for parent in get_canonical_parent_tags(tag):
			var parent_text: String = String(parent)
			if not has_tag(parent) and not missing_parent_errors.has(parent_text):
				errors.append("Missing parent gameplay tag: %s" % parent_text)
				missing_parent_errors[parent_text] = true

	for retired_tag in tag_redirects:
		var retired_text: String = String(retired_tag)
		if has_tag(retired_tag):
			errors.append("Redirected gameplay tag is still registered: %s" % retired_text)
			continue
		var destination: StringName = resolve_tag(retired_tag)
		if destination == retired_tag:
			errors.append("Gameplay tag redirect cycle: %s" % retired_text)
		elif not has_tag(destination):
			errors.append(
				(
					"Gameplay tag redirect points at an unknown tag: %s -> %s"
					% [retired_text, String(destination)]
				)
			)
	return errors


func _has_children(tag: StringName) -> bool:
	var parent: String = String(tag)
	for existing in tags:
		if String(existing).begins_with(parent + "."):
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
		for parent in get_canonical_parent_tags(existing):
			var parent_key: String = String(parent)
			if remove_set.has(parent_key):
				protected_tags[parent_key] = true
	return protected_tags


# Walks the chain forward from the proposed destination; if it leads back to the tag
# being retired, the new entry would close a loop.
func _redirect_would_cycle(from_tag: StringName, to_tag: StringName) -> bool:
	var cursor: StringName = to_tag
	var depth: int = 0
	while tag_redirects.has(cursor):
		if depth >= MAX_REDIRECT_DEPTH:
			return true
		cursor = normalize_tag(tag_redirects[cursor])
		if cursor == from_tag:
			return true
		depth += 1
	return false


func _rebuild_cache() -> void:
	_tag_set.clear()
	for tag in tags:
		_tag_set[tag] = true
	_drop_redirects_for_live_tags()


# A registered tag must never also be a redirect source, or it would resolve away from
# itself. Enforced here rather than at each call site so restoring a renamed tag —
# through undo, set_state(), or a plain add — cleans up the redirect the rename left.
# Mutates the backing dictionary directly: the caller's change notification covers it.
func _drop_redirects_for_live_tags() -> void:
	if tag_redirects.is_empty():
		return
	for retired_tag in tag_redirects.keys():
		if _tag_set.has(retired_tag):
			tag_redirects.erase(retired_tag)


func _notify_changed() -> void:
	if _suppress_change_notifications:
		return
	emit_changed()
	tags_changed.emit()
