@tool
class_name GameplayTagRegistry
extends Node
## Concrete class for the [code]GameplayTags[/code] autoload singleton.
## Gameplay code should call the singleton; this class name supports typed references to it.

const COMPONENT_GROUP: StringName = &"gameplay_tag_components"
const TAG_INDEX_GROUP_PREFIX: String = "gameplay_tag:"

var _database: GameplayTagDatabase
var _warned_read_only_target: bool = false


func _ready() -> void:
	get_database()


## Returns the central tag database, loading or creating it on first use.
func get_database() -> GameplayTagDatabase:
	if _database == null:
		_database = _load_or_create_database()
	return _database


## Swaps in a different database. Pass [param save_now] to persist it immediately.
func set_database(database: GameplayTagDatabase, save_now: bool = false) -> void:
	_database = database
	if _database == null:
		_database = GameplayTagDatabase.new()
	if save_now:
		save_database()


## Returns the configured database path from ProjectSettings.
func get_database_path() -> String:
	return GameplayTagUtils.get_database_path()


## Points the addon at a different database path and drops the cached database.
func set_database_path(path: String, save_project_settings: bool = false) -> void:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		clean_path = GameplayTagUtils.DEFAULT_DATABASE_PATH
	ProjectSettings.set_setting(GameplayTagUtils.DATABASE_SETTING, clean_path)
	ProjectSettings.set_initial_value(
		GameplayTagUtils.DATABASE_SETTING, GameplayTagUtils.DEFAULT_DATABASE_PATH
	)
	if save_project_settings:
		ProjectSettings.save()
	_database = null


## Re-reads the database from disk, bypassing the ResourceLoader reuse cache.
func reload_database() -> GameplayTagDatabase:
	_database = _load_or_create_database(ResourceLoader.CACHE_MODE_REPLACE)
	return _database


## Writes the database to its configured path.
## Returns ERR_UNAVAILABLE in an exported build, where res:// is read-only.
func save_database() -> Error:
	var database: GameplayTagDatabase = get_database()
	var path: String = get_database_path()
	if not _can_write_to_path(path):
		_warn_read_only_target(path)
		return ERR_UNAVAILABLE
	if GameplayTagUtils.database_path_conflicts(path):
		push_error("Refusing to overwrite a non-GameplayTagDatabase resource at: %s" % path)
		return ERR_INVALID_DATA
	var directory_error: Error = GameplayTagUtils.ensure_parent_directory(path)
	if directory_error != OK:
		push_error(
			"Could not create gameplay tag database directory: %s" % error_string(directory_error)
		)
		return directory_error
	if database.resource_path.is_empty() or database.resource_path != path:
		database.resource_path = path
	var save_error: Error = ResourceSaver.save(database, path)
	if save_error != OK:
		push_error("Could not save gameplay tag database: %s" % error_string(save_error))
	return save_error


## Returns [param raw_tag] in canonical form.
func normalize_tag(raw_tag: StringName) -> StringName:
	return GameplayTagDatabase.normalize_tag(raw_tag)


## Resolves a retired tag name to whatever replaced it, following redirect chains.
## Returns the normalized input when no redirect applies.
func resolve_tag(raw_tag: StringName) -> StringName:
	return get_database().resolve_tag(raw_tag)


## Returns whether [param raw_tag] is registered in the central database.
## Retired names are resolved first, so a redirected tag still reports as valid.
func is_valid_tag(raw_tag: StringName) -> bool:
	var database: GameplayTagDatabase = get_database()
	return database.has_tag(database.resolve_tag(raw_tag))


## Returns a GameplayTag for a registered tag, or null when it is unknown.
func request_tag(raw_tag: StringName) -> GameplayTag:
	return get_database().get_tag(raw_tag)


## Registers a tag plus any missing parents. Returns whether it was added.
func add_tag(raw_tag: StringName, description: String = "", save_now: bool = true) -> bool:
	var added: bool = get_database().add_tag(raw_tag, description)
	if added and save_now:
		save_database()
	return added


## Registers several tags in one batch. Returns how many were new.
func add_tags(raw_tags: Array[StringName], save_now: bool = true) -> int:
	var added: int = get_database().add_tags(raw_tags)
	if added > 0 and save_now:
		save_database()
	return added


## Sets or clears a registered tag's description.
func set_tag_description(
	raw_tag: StringName,
	description: String,
	save_now: bool = true,
) -> bool:
	var changed: bool = get_database().set_tag_description(raw_tag, description)
	if changed and save_now:
		save_database()
	return changed


## Renames or moves a tag and its whole branch.
func rename_tag(raw_tag: StringName, new_tag: StringName, save_now: bool = true) -> bool:
	var renamed: bool = get_database().rename_tag(raw_tag, new_tag)
	if renamed and save_now:
		save_database()
	return renamed


## Unregisters a tag, optionally with its children.
func remove_tag(raw_tag: StringName, remove_children: bool = false, save_now: bool = true) -> bool:
	var removed: bool = get_database().remove_tag(raw_tag, remove_children)
	if removed and save_now:
		save_database()
	return removed


## Creates missing parents for one tag, or for every tag when [param raw_tag] is empty.
func ensure_parent_tags(raw_tag: StringName = &"", save_now: bool = true) -> bool:
	var changed: bool = get_database().ensure_parent_tags(raw_tag)
	if changed and save_now:
		save_database()
	return changed


## Returns every registered tag.
func get_all_tags() -> Array[StringName]:
	return get_database().get_all_tags()


## Returns tags whose name or description contains [param search_text].
func find_tags(search_text: String = "") -> Array[StringName]:
	return get_database().find_tags(search_text)


## Imports tags from a CSV file and returns how many were new.
func import_tags_from_csv(path: String, save_now: bool = true) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open gameplay tags CSV: %s" % path)
		return 0

	var added: int = get_database().add_tags_from_csv_text(file.get_as_text())
	file.close()
	if added > 0 and save_now:
		save_database()
	return added


## Writes every registered tag to a CSV file.
func export_tags_to_csv(path: String) -> Error:
	if not _can_write_to_path(path):
		_warn_read_only_target(path)
		return ERR_UNAVAILABLE
	var directory_error: Error = GameplayTagUtils.ensure_parent_directory(path)
	if directory_error != OK:
		push_error(
			"Could not create gameplay tags CSV directory: %s" % error_string(directory_error)
		)
		return directory_error

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write gameplay tags CSV: %s" % path)
		return ERR_CANT_OPEN

	file.store_string(get_database().to_csv_text())
	file.close()
	return OK


## Creates a tag container, optionally seeded with [param initial_tags].
func make_container(initial_tags: Array[StringName] = []) -> GameplayTagContainer:
	return GameplayTagContainer.new(initial_tags)


## Creates a query requiring every tag in [param tags].
func make_query_all(tags: Array[StringName], exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.all(tags, exact)


## Creates a query requiring at least one tag in [param tags].
func make_query_any(tags: Array[StringName], exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.any(tags, exact)


## Creates a query rejecting any target owning one of [param tags].
func make_query_none(tags: Array[StringName], exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.none(tags, exact)


## Returns every node under [param root] carrying a tag component.
func get_tagged_nodes(root: Node = null) -> Array[Node]:
	return _get_tagged_node_candidates(root)


## Returns tagged nodes under [param root] that own [param tag].
## Backed by a per-tag group index, so this is a group lookup over the matching nodes
## rather than a resolve-every-tagged-node scan.
func get_nodes_with_tag(
	root: Node = null, tag: StringName = &"", exact: bool = false
) -> Array[Node]:
	var matches: Array[Node] = []
	var normalized_tag: StringName = GameplayTagDatabase.normalize_tag(tag)
	if normalized_tag == &"":
		return matches

	var tree: SceneTree = _get_tree_for_tag_search(root)
	if tree == null:
		return matches

	for candidate in tree.get_nodes_in_group(_tag_index_group_name(normalized_tag)):
		if not candidate is Node or not _is_node_under_root(candidate, root):
			continue
		# The index narrows the candidate set; it is not the source of truth. Verifying
		# each candidate keeps a stale entry from producing a false positive, which is
		# how component removal can refresh the index on the next idle frame.
		if not target_has_tag(candidate, normalized_tag, exact):
			continue
		matches.append(candidate)
	return matches


## Rebuilds the per-tag index entries for [param node] from its direct tag components.
## GameplayTagComponent calls this automatically when its owned tags change.
func refresh_node_tag_index(node: Node) -> void:
	if node == null:
		return

	var indexed_tags: Dictionary[String, bool] = {}
	for child_index in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		if not child is GameplayTagComponent:
			continue
		for tag in child.owned_tags:
			indexed_tags[String(tag)] = true
			for parent in GameplayTagDatabase.get_canonical_parent_tags(tag):
				indexed_tags[String(parent)] = true

	for group in node.get_groups():
		var group_text: String = String(group)
		if not group_text.begins_with(TAG_INDEX_GROUP_PREFIX):
			continue
		if not indexed_tags.has(group_text.substr(TAG_INDEX_GROUP_PREFIX.length())):
			node.remove_from_group(group)

	for tag_key in indexed_tags:
		var group_name: StringName = StringName(TAG_INDEX_GROUP_PREFIX + tag_key)
		if not node.is_in_group(group_name):
			node.add_to_group(group_name)


# Deferred-safe form of refresh_node_tag_index(). Takes an instance ID rather than a
# reference because the node may be freed before a deferred call runs.
func _refresh_node_tag_index_by_id(node_instance_id: int) -> void:
	if not is_instance_id_valid(node_instance_id):
		return
	var node: Node = instance_from_id(node_instance_id) as Node
	if node == null:
		return
	refresh_node_tag_index(node)


func _tag_index_group_name(tag: StringName) -> StringName:
	return StringName(TAG_INDEX_GROUP_PREFIX + String(tag))


# target is Object because containers, components, and nodes share no narrower base type.
## Resolves every tag [param target] owns into a container.
## Nodes own tags only through direct [GameplayTagComponent] children.
func get_owned_gameplay_tags(target: Object) -> GameplayTagContainer:
	if target is GameplayTagContainer:
		return target.duplicate_container()
	if target is GameplayTagComponent:
		return target.get_owned_gameplay_tags()
	if target is Node:
		return _get_node_owned_gameplay_tags(target)
	return GameplayTagContainer.new()


## Returns whether [param target] owns [param tag], matching parents unless [param exact].
## Direct checks avoid constructing a throwaway [GameplayTagContainer].
func target_has_tag(target: Object, tag: StringName, exact: bool = false) -> bool:
	if target is GameplayTagContainer:
		return target.has_tag(tag, exact)
	if target is GameplayTagComponent:
		return target.has_tag(tag, exact)
	if target is Node:
		return _node_has_tag(target, tag, exact)
	return false


## Returns whether [param target] owns at least one of [param tags].
## Entries that normalize to an empty name do not match.
func target_has_any(target: Object, tags: Array[StringName], exact: bool = false) -> bool:
	if target is GameplayTagContainer:
		return target.has_any(tags, exact)
	if target is GameplayTagComponent:
		return target.has_any(tags, exact)
	if target is Node:
		for child_index in range(target.get_child_count()):
			var child: Node = target.get_child(child_index)
			if child is GameplayTagComponent and child.has_any(tags, exact):
				return true
		return false
	for raw_tag in tags:
		var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		if tag != &"" and target_has_tag(target, tag, exact):
			return true
	return false


## Returns whether [param target] owns every one of [param tags].
## An empty list matches, and entries that normalize to an empty name are ignored.
func target_has_all(target: Object, tags: Array[StringName], exact: bool = false) -> bool:
	if target is GameplayTagContainer:
		return target.has_all(tags, exact)
	if target is GameplayTagComponent:
		return target.has_all(tags, exact)
	if target is Node:
		return _node_has_all(target, tags, exact)
	for raw_tag in tags:
		var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		if tag != &"" and not target_has_tag(target, tag, exact):
			return false
	return true


func _node_has_tag(node: Node, required_tag: StringName, exact: bool) -> bool:
	for child_index in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		if child is GameplayTagComponent and child.has_tag(required_tag, exact):
			return true
	return false


func _node_has_all(node: Node, tags: Array[StringName], exact: bool) -> bool:
	for child_index in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		if child is GameplayTagComponent and child.has_all(tags, exact):
			return true
	for raw_tag in tags:
		var required_tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
		if required_tag == &"":
			continue
		if not _node_has_tag(node, required_tag, exact):
			return false
	return true


# Merges every direct component into one result for APIs that need the full owned set.
func _get_node_owned_gameplay_tags(node: Node) -> GameplayTagContainer:
	var collected: Array[StringName] = []
	var counts: Dictionary[String, int] = {}
	for child_index in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		if child is GameplayTagComponent:
			collected.append_array(child.owned_tags)
			_merge_stack_counts(child, counts)

	var container: GameplayTagContainer = GameplayTagContainer.new(collected)
	for tag_key in counts:
		container.set_tag_count(StringName(tag_key), counts[tag_key])
	return container


# Records the deepest stack each component reports for the tags it owns.
func _merge_stack_counts(component: GameplayTagComponent, counts: Dictionary[String, int]) -> void:
	for tag in component.owned_tags:
		var depth: int = component.get_tag_count(tag)
		if depth <= 1:
			continue
		var key: String = String(tag)
		if depth > counts.get(key, 1):
			counts[key] = depth


func _get_tagged_node_candidates(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	var seen: Dictionary[int, bool] = {}
	var tree: SceneTree = _get_tree_for_tag_search(root)
	if tree == null:
		return nodes

	for candidate in tree.get_nodes_in_group(COMPONENT_GROUP):
		if candidate is GameplayTagComponent:
			var target: Node = candidate.get_parent()
			if target == null:
				target = candidate
			_append_tagged_node_candidate(nodes, seen, target, root)
	return nodes


func _append_tagged_node_candidate(
	nodes: Array[Node], seen: Dictionary[int, bool], node: Node, root: Node
) -> void:
	if node == null or not _is_node_under_root(node, root):
		return
	var instance_id: int = node.get_instance_id()
	if seen.has(instance_id):
		return
	seen[instance_id] = true
	nodes.append(node)


func _get_tree_for_tag_search(root: Node) -> SceneTree:
	if root != null and root.is_inside_tree():
		return root.get_tree()
	return get_tree()


func _is_node_under_root(node: Node, root: Node) -> bool:
	return root == null or node == root or root.is_ancestor_of(node)


# res:// is packed and read-only in an exported build, so the save_now defaults on the
# mutation helpers would fail on every call. Report it once instead of per-call error spam.
func _can_write_to_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return true
	return OS.has_feature("editor")


func _warn_read_only_target(path: String) -> void:
	if _warned_read_only_target:
		return
	_warned_read_only_target = true
	push_warning(
		(
			(
				"Gameplay tag writes to %s are skipped because res:// is read-only in exported builds. "
				+ "Pass save_now = false at runtime, or write to user:// instead."
			)
			% path
		)
	)


func _load_or_create_database(
	cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_REUSE,
) -> GameplayTagDatabase:
	var path: String = get_database_path()
	if ResourceLoader.exists(path):
		var existing_resource: Resource = ResourceLoader.load(path, "", cache_mode)
		if existing_resource is GameplayTagDatabase:
			return existing_resource
		push_error("Expected a GameplayTagDatabase but found another resource at: %s" % path)
		return GameplayTagDatabase.new()

	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.resource_path = path
	if not _can_write_to_path(path):
		_warn_read_only_target(path)
		return database
	var directory_error: Error = GameplayTagUtils.ensure_parent_directory(path)
	if directory_error == OK:
		var save_error: Error = ResourceSaver.save(database, path)
		if save_error != OK:
			push_error("Could not save gameplay tag database: %s" % error_string(save_error))
	else:
		push_error(
			"Could not create gameplay tag database directory: %s" % error_string(directory_error)
		)
	return database
