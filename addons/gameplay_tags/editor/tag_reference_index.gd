@tool
class_name GameplayTagReferenceIndex
extends RefCounted
## Finds where each registered tag is actually used across the project.
## Scans script and resource text rather than loading scenes, so it never instantiates
## project content. Two things make this practical here and not in most tag systems:
## generated `GameplayTagIds` constants are greppable, and scenes/resources save as text.

## Directory names never worth scanning. Engine caches and build output only ever
## contain copies of what is already indexed from source.
const SKIPPED_DIRECTORIES: Array[String] = [".godot", ".git", "dist"]

## File types that can name a tag: scripts through constants or literals, scenes and
## resources through exported tag arrays.
const SCANNED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]

const TAG_LITERAL_PATTERN: String = '"([A-Za-z0-9_\\-.]+)"'
const CONSTANT_USE_PATTERN: String = "GameplayTagIds\\.([A-Z0-9_]+)"


## Scans [param root_path] and returns every registered tag mapped to the places it is
## used, each formatted as `res://path.gd:12`. A tag with an empty array is unused.
## The generated ID script and the database resource are always excluded: both name
## every tag by construction, which would make dead-tag detection meaningless.
static func scan(
	database: GameplayTagDatabase,
	root_path: String = "res://",
	extra_excluded_paths: PackedStringArray = PackedStringArray()
) -> Dictionary[StringName, PackedStringArray]:
	if database == null:
		return {}
	return scan_tags(database.get_all_tags(), root_path, extra_excluded_paths)


## Same scan for an explicit tag list rather than the database's. Lets retired names
## still be located after a rename, which is what makes reference migration possible.
static func scan_tags(
	scanned_tags: Array[StringName],
	root_path: String = "res://",
	extra_excluded_paths: PackedStringArray = PackedStringArray()
) -> Dictionary[StringName, PackedStringArray]:
	var index: Dictionary[StringName, PackedStringArray] = {}
	var tag_by_text: Dictionary[String, StringName] = {}
	var tag_by_constant: Dictionary[String, StringName] = {}
	for tag in scanned_tags:
		index[tag] = PackedStringArray()
		tag_by_text[String(tag)] = tag
		tag_by_constant[GameplayTagCodeGenerator.get_constant_name_for_tag(tag)] = tag

	var excluded: Dictionary[String, bool] = {}
	excluded[GameplayTagUtils.get_tag_ids_path()] = true
	excluded[GameplayTagUtils.get_database_path()] = true
	for path in extra_excluded_paths:
		excluded[path] = true

	var literal_regex: RegEx = RegEx.create_from_string(TAG_LITERAL_PATTERN)
	var constant_regex: RegEx = RegEx.create_from_string(CONSTANT_USE_PATTERN)

	for file_path in collect_scannable_files(root_path, excluded):
		_scan_file(file_path, tag_by_text, tag_by_constant, literal_regex, constant_regex, index)
	return index


## Returns every file under [param root_path] worth scanning, depth first.
static func collect_scannable_files(
	root_path: String, excluded: Dictionary[String, bool]
) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: Array[String] = [root_path]
	while not pending.is_empty():
		var directory_path: String = pending.pop_back()
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue

		directory.list_dir_begin()
		var entry: String = directory.get_next()
		while entry != "":
			var entry_path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				if not SKIPPED_DIRECTORIES.has(entry):
					pending.append(entry_path)
			elif SCANNED_EXTENSIONS.has(entry.get_extension().to_lower()):
				if not excluded.has(entry_path):
					found.append(entry_path)
			entry = directory.get_next()
		directory.list_dir_end()
	return found


## Returns the registered tags that nothing references, ignoring tags that exist only
## to hold up a referenced child.
##
## Parents are created implicitly, so almost none of them are named directly. Reporting
## those as dead would bury the handful of genuinely unused tags in noise, so a tag with
## a referenced descendant does not count as unused.
static func find_unused_tags(index: Dictionary[StringName, PackedStringArray]) -> Array[StringName]:
	var referenced_branches: Dictionary[String, bool] = {}
	for tag in index:
		if index[tag].is_empty():
			continue
		for parent in GameplayTagDatabase.get_canonical_parent_tags(tag):
			referenced_branches[String(parent)] = true

	var unused: Array[StringName] = []
	for tag in index:
		if index[tag].is_empty() and not referenced_branches.has(String(tag)):
			unused.append(tag)
	unused.sort()
	return unused


## Rewrites every reference to [param old_tag] in [param file_paths] so it names
## [param new_tag], covering both quoted literals and generated constants.
## Returns each changed file mapped to how many replacements it received.
##
## Only whole quoted tokens and whole constant names are replaced, so renaming `State`
## never corrupts `StateMachine` or `"State.Other"`. Files are rewritten in place and
## only when something actually changed.
static func migrate_tag(
	old_tag: StringName, new_tag: StringName, file_paths: PackedStringArray
) -> Dictionary[String, int]:
	var changes: Dictionary[String, int] = {}
	var old_text: String = String(old_tag)
	var new_text: String = String(new_tag)
	if old_text.is_empty() or new_text.is_empty() or old_text == new_text:
		return changes

	var old_constant: String = GameplayTagCodeGenerator.get_constant_name_for_tag(old_tag)
	var new_constant: String = GameplayTagCodeGenerator.get_constant_name_for_tag(new_tag)
	# Anchored so OLD_TAG does not match inside OLD_TAG_HEAVY.
	var constant_regex: RegEx = RegEx.create_from_string(
		"GameplayTagIds\\.%s(?![A-Z0-9_])" % old_constant
	)

	for file_path in file_paths:
		var source: String = _read_text(file_path)
		if source.is_empty():
			continue

		var replacements: int = source.count('"%s"' % old_text)
		var updated: String = source.replace('"%s"' % old_text, '"%s"' % new_text)
		if old_constant != new_constant:
			replacements += constant_regex.search_all(updated).size()
			updated = constant_regex.sub(updated, "GameplayTagIds.%s" % new_constant, true)

		if replacements == 0 or updated == source:
			continue
		if _write_text(file_path, updated) != OK:
			push_error("Could not rewrite gameplay tag references in %s" % file_path)
			continue
		changes[file_path] = replacements
	return changes


## Rewrites every reference to a retired tag so it names the tag that replaced it,
## using the database's redirect table as the work list. Returns each rewritten file
## mapped to how many replacements it received.
##
## This is the step Unreal's redirects never take: a redirect keeps old data working
## forever, whereas migrating lets the redirect be retired once nothing names it.
static func migrate_redirected_tags(
	database: GameplayTagDatabase, root_path: String = "res://"
) -> Dictionary[String, int]:
	var changes: Dictionary[String, int] = {}
	if database == null:
		return changes

	var retired_tags: Array[StringName] = database.get_redirected_tags()
	if retired_tags.is_empty():
		return changes

	var index: Dictionary[StringName, PackedStringArray] = scan_tags(retired_tags, root_path)
	for retired_tag in retired_tags:
		var locations: PackedStringArray = index.get(retired_tag, PackedStringArray())
		if locations.is_empty():
			continue

		var file_paths: PackedStringArray = PackedStringArray()
		for location in locations:
			var file_path: String = location.substr(0, location.rfind(":"))
			if not file_paths.has(file_path):
				file_paths.append(file_path)

		var destination: StringName = database.resolve_tag(retired_tag)
		for path in migrate_tag(retired_tag, destination, file_paths):
			changes[path] = changes.get(path, 0) + 1
	return changes


static func _scan_file(
	file_path: String,
	tag_by_text: Dictionary[String, StringName],
	tag_by_constant: Dictionary[String, StringName],
	literal_regex: RegEx,
	constant_regex: RegEx,
	index: Dictionary[StringName, PackedStringArray]
) -> void:
	var source: String = _read_text(file_path)
	if source.is_empty():
		return

	var line_number: int = 0
	for line in source.split("\n"):
		line_number += 1
		var line_text: String = String(line)
		# Cheap rejection first: most lines in a scene file mention no tag at all.
		if not line_text.contains('"') and not line_text.contains("GameplayTagIds."):
			continue

		var seen_on_line: Dictionary[StringName, bool] = {}
		for literal_match in literal_regex.search_all(line_text):
			var literal: String = literal_match.get_string(1)
			if tag_by_text.has(literal):
				seen_on_line[tag_by_text[literal]] = true
		for constant_match in constant_regex.search_all(line_text):
			var constant_name: String = constant_match.get_string(1)
			if tag_by_constant.has(constant_name):
				seen_on_line[tag_by_constant[constant_name]] = true

		for tag in seen_on_line:
			index[tag].append("%s:%d" % [file_path, line_number])


static func _read_text(file_path: String) -> String:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _write_text(file_path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
