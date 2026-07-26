@tool
extends Node

const DATABASE_SETTING: String = "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH: String = "res://gameplay_tags_database.tres"
const COMPONENT_GROUP: StringName = &"gameplay_tag_components"
const NODE_TAGS_META_NAME: String = "gameplay_tags"
const NODE_TAG_GROUP: StringName = &"gameplay_tagged_nodes"
const TAG_PROPERTY_NAMES: Array[String] = ["owned_tags", "gameplay_tags", "tags"]

var _database: GameplayTagDatabase
var _warned_read_only_target: bool = false


func _ready() -> void:
	get_database()


func get_database() -> GameplayTagDatabase:
	if _database == null:
		_database = _load_or_create_database()
	return _database


func set_database(database: GameplayTagDatabase, save_now: bool = false) -> void:
	_database = database
	if _database == null:
		_database = GameplayTagDatabase.new()
	if save_now:
		save_database()


func get_database_path() -> String:
	return String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))


func set_database_path(path: String, save_project_settings: bool = false) -> void:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		clean_path = DEFAULT_DATABASE_PATH
	ProjectSettings.set_setting(DATABASE_SETTING, clean_path)
	ProjectSettings.set_initial_value(DATABASE_SETTING, DEFAULT_DATABASE_PATH)
	if save_project_settings:
		ProjectSettings.save()
	_database = null


func reload_database() -> GameplayTagDatabase:
	_database = _load_or_create_database(ResourceLoader.CACHE_MODE_REPLACE)
	return _database


func save_database() -> Error:
	var database: GameplayTagDatabase = get_database()
	var path: String = get_database_path()
	if not _can_write_to_path(path):
		_warn_read_only_target(path)
		return ERR_UNAVAILABLE
	if _database_path_has_incompatible_resource(path):
		push_error("Refusing to overwrite a non-GameplayTagDatabase resource at: %s" % path)
		return ERR_INVALID_DATA
	var directory_error: Error = _ensure_database_directory(path)
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


func normalize_tag(raw_tag: StringName) -> StringName:
	return GameplayTagDatabase.normalize_tag(raw_tag)


func is_valid_tag(raw_tag: StringName) -> bool:
	return get_database().has_tag(raw_tag)


func has_tag(raw_tag: StringName) -> bool:
	return is_valid_tag(raw_tag)


func request_tag(raw_tag: StringName) -> GameplayTag:
	return get_database().get_tag(raw_tag)


func add_tag(raw_tag: StringName, description: String = "", save_now: bool = true) -> bool:
	var added: bool = get_database().add_tag(raw_tag, description)
	if added and save_now:
		save_database()
	return added


func add_tags(raw_tags: Array[StringName], save_now: bool = true) -> int:
	var added: int = get_database().add_tags(raw_tags)
	if added > 0 and save_now:
		save_database()
	return added


func set_tag_description(
	raw_tag: StringName,
	description: String,
	save_now: bool = true,
) -> bool:
	var changed: bool = get_database().set_tag_description(raw_tag, description)
	if changed and save_now:
		save_database()
	return changed


func rename_tag(raw_tag: StringName, new_tag: StringName, save_now: bool = true) -> bool:
	var renamed: bool = get_database().rename_tag(raw_tag, new_tag)
	if renamed and save_now:
		save_database()
	return renamed


func remove_tag(raw_tag: StringName, remove_children: bool = false, save_now: bool = true) -> bool:
	var removed: bool = get_database().remove_tag(raw_tag, remove_children)
	if removed and save_now:
		save_database()
	return removed


func ensure_parent_tags(raw_tag: StringName = &"", save_now: bool = true) -> bool:
	var changed: bool = get_database().ensure_parent_tags(raw_tag)
	if changed and save_now:
		save_database()
	return changed


func get_all_tags() -> Array[StringName]:
	return get_database().get_all_tags()


func find_tags(search_text: String = "") -> Array[StringName]:
	return get_database().find_tags(search_text)


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


func export_tags_to_csv(path: String) -> Error:
	if not _can_write_to_path(path):
		_warn_read_only_target(path)
		return ERR_UNAVAILABLE
	var directory_error: Error = _ensure_database_directory(path)
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


func make_container(initial_tags: Array[StringName] = []) -> GameplayTagContainer:
	return GameplayTagContainer.new(initial_tags)


func make_query_all(tags: Array[StringName], exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.all(tags, exact)


func make_query_any(tags: Array[StringName], exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.any(tags, exact)


func make_query_none(tags: Array[StringName], exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.none(tags, exact)


func get_node_tags(node: Node) -> GameplayTagContainer:
	if node == null:
		return GameplayTagContainer.new()
	var node_tags: Array[StringName] = []
	_append_tags_from_dynamic_value(node.get_meta(NODE_TAGS_META_NAME, []), node_tags)
	return GameplayTagContainer.new(node_tags)


func set_node_tags(
	node: Node, raw_tags: Array[StringName], validate_with_database: bool = true
) -> bool:
	if node == null:
		return false

	var node_tags: Array[StringName] = GameplayTagDatabase.canonicalize_tag_array(raw_tags)
	if validate_with_database:
		node_tags = _filter_tags_to_database(node_tags, true).get_tags()
	node.set_meta(NODE_TAGS_META_NAME, node_tags)
	_update_node_tag_group(node, node_tags)
	return true


func add_tag_to_node(node: Node, raw_tag: StringName, validate_with_database: bool = true) -> bool:
	return add_tags_to_node(node, [raw_tag], validate_with_database) == 1


func add_tags_to_node(
	node: Node, raw_tags: Array[StringName], validate_with_database: bool = true
) -> int:
	if node == null:
		return 0

	var existing: GameplayTagContainer = get_node_tags(node)
	var candidates: Array[StringName] = GameplayTagDatabase.canonicalize_tag_array(raw_tags)
	if validate_with_database:
		candidates = _filter_tags_to_database(candidates, true).get_tags()
	var added: int = existing.add_tags(candidates)
	if added > 0:
		set_node_tags(node, existing.get_tags(), false)
	return added


func remove_tag_from_node(node: Node, raw_tag: StringName) -> bool:
	if node == null:
		return false

	var existing: GameplayTagContainer = get_node_tags(node)
	var removed: bool = existing.remove_tag(raw_tag)
	if removed:
		set_node_tags(node, existing.get_tags(), false)
	return removed


func clear_node_tags(node: Node) -> void:
	if node == null:
		return
	node.remove_meta(NODE_TAGS_META_NAME)
	if node.is_in_group(NODE_TAG_GROUP):
		node.remove_from_group(NODE_TAG_GROUP)


func get_tagged_nodes(root: Node = null) -> Array[Node]:
	return _get_tagged_node_candidates(root)


func get_nodes_with_tag(
	root: Node = null, tag: StringName = &"", exact: bool = false
) -> Array[Node]:
	var matches: Array[Node] = []
	for node in get_tagged_nodes(root):
		if target_has_tag(node, tag, exact):
			matches.append(node)
	return matches


# target is Object because it may be Node, Resource, or a custom RefCounted.
func get_owned_gameplay_tags(target: Object) -> GameplayTagContainer:
	if target is GameplayTagContainer:
		return target.duplicate_container()
	if target is GameplayTag:
		return GameplayTagContainer.new([target.tag_name])
	if target is GameplayTagDatabase or target is GameplayTagQuery:
		# Both expose a `tags` property, but it describes a catalog or a filter,
		# not tags the object owns. Treat them as untagged rather than matching everything.
		return GameplayTagContainer.new()
	if target is Object:
		return _get_owned_gameplay_tags_from_object(target)
	return GameplayTagContainer.new()


func target_has_tag(target: Object, tag: StringName, exact: bool = false) -> bool:
	return get_owned_gameplay_tags(target).has_tag(tag, exact)


func target_has_any(target: Object, tags: Array[StringName], exact: bool = false) -> bool:
	return get_owned_gameplay_tags(target).has_any(
		GameplayTagDatabase.canonicalize_tag_array(tags), exact
	)


func target_has_all(target: Object, tags: Array[StringName], exact: bool = false) -> bool:
	return get_owned_gameplay_tags(target).has_all(
		GameplayTagDatabase.canonicalize_tag_array(tags), exact
	)


func get_overlapping_bodies_with_tag(
	area: Area3D, tag: StringName, exact: bool = false
) -> Array[Node]:
	var matches: Array[Node] = []
	if area == null:
		return matches
	for body in area.get_overlapping_bodies():
		if body is Node and target_has_tag(body, tag, exact):
			matches.append(body)
	return matches


func get_overlapping_areas_with_tag(
	area: Area3D, tag: StringName, exact: bool = false
) -> Array[Area3D]:
	var matches: Array[Area3D] = []
	if area == null:
		return matches
	for overlap in area.get_overlapping_areas():
		if overlap is Area3D and target_has_tag(overlap, tag, exact):
			matches.append(overlap)
	return matches


func get_first_overlapping_target_with_tag(
	area: Area3D, tag: StringName, exact: bool = false
) -> Node:
	if area == null:
		return null
	for body in area.get_overlapping_bodies():
		if body is Node and target_has_tag(body, tag, exact):
			return body
	for overlap in area.get_overlapping_areas():
		if overlap is Area3D and target_has_tag(overlap, tag, exact):
			return overlap
	return null


# Collects into one plain array and builds a single container at the end. Merging
# container into container re-canonicalized and re-emitted change signals per source,
# which is wasted work on a throwaway result.
func _get_owned_gameplay_tags_from_object(object: Object) -> GameplayTagContainer:
	var collected: Array[StringName] = []
	var used_explicit_method: bool = false
	if object is GameplayTagComponent:
		collected.append_array(object.owned_tags)
		used_explicit_method = true
	elif object.has_method("get_owned_gameplay_tags") and object != self:
		used_explicit_method = _append_tags_from_dynamic_value(
			object.call("get_owned_gameplay_tags"), collected
		)
	elif object.has_method("get_gameplay_tags"):
		used_explicit_method = _append_tags_from_dynamic_value(
			object.call("get_gameplay_tags"), collected
		)

	if not used_explicit_method or object is Node:
		_append_known_property_tags(object, collected)
	if object is Node:
		_append_child_component_tags(object, collected)
	return GameplayTagContainer.new(collected)


func _filter_tags_to_database(
	raw_tags: Array[StringName], warn_on_invalid: bool = false
) -> GameplayTagContainer:
	var registered_tags: Array[StringName] = []
	var database: GameplayTagDatabase = get_database()
	for tag in GameplayTagDatabase.canonicalize_tag_array(raw_tags):
		if database.has_tag(tag):
			registered_tags.append(tag)
		elif warn_on_invalid:
			push_warning("Gameplay tag is not in the central database: %s" % String(tag))
	return GameplayTagContainer.new(registered_tags)


func _update_node_tag_group(node: Node, node_tags: Array[StringName]) -> void:
	if node_tags.is_empty():
		if node.has_meta(NODE_TAGS_META_NAME):
			node.remove_meta(NODE_TAGS_META_NAME)
		if node.is_in_group(NODE_TAG_GROUP):
			node.remove_from_group(NODE_TAG_GROUP)
	else:
		node.add_to_group(NODE_TAG_GROUP)


func _get_tagged_node_candidates(root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	var seen: Dictionary[int, bool] = {}
	var tree: SceneTree = _get_tree_for_tag_search(root)
	if tree == null:
		return nodes

	for candidate in tree.get_nodes_in_group(NODE_TAG_GROUP):
		if candidate is Node:
			_append_tagged_node_candidate(nodes, seen, candidate, root)

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


func _ensure_database_directory(path: String) -> Error:
	var directory: String = path.get_base_dir()
	if directory.is_empty() or directory == "res://" or directory == "user://":
		return OK
	return DirAccess.make_dir_recursive_absolute(directory)


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
	var directory_error: Error = _ensure_database_directory(path)
	if directory_error == OK:
		var save_error: Error = ResourceSaver.save(database, path)
		if save_error != OK:
			push_error("Could not save gameplay tag database: %s" % error_string(save_error))
	else:
		push_error(
			"Could not create gameplay tag database directory: %s" % error_string(directory_error)
		)
	return database


func _database_path_has_incompatible_resource(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var existing_resource: Resource = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	return not existing_resource is GameplayTagDatabase


# Accepts Variant because Object.call/get/metadata returns dynamic values.
# Safely validates each element as StringName/String/GameplayTag/GameplayTagContainer;
# rejects unsupported types instead of falling back to generic str(). Returns whether
# the value was a tag source at all, so callers can tell "no such property" apart from
# "an empty tag list".
func _append_tags_from_dynamic_value(value: Variant, out_tags: Array[StringName]) -> bool:
	if value == null:
		return false
	if value is GameplayTagContainer:
		out_tags.append_array(value.get_tags())
		return true
	if value is Array:
		for element in value:
			if element is StringName or element is String:
				out_tags.append(GameplayTagDatabase.normalize_tag(StringName(element)))
			elif element is GameplayTag:
				out_tags.append(element.tag_name)
		return true
	if value is GameplayTag:
		out_tags.append(value.tag_name)
		return true
	if value is StringName or value is String:
		out_tags.append(GameplayTagDatabase.normalize_tag(StringName(value)))
		return true
	return false


func _append_known_property_tags(object: Object, out_tags: Array[StringName]) -> void:
	for property_name in TAG_PROPERTY_NAMES:
		# Object.get() yields null for properties the object does not declare, so this
		# needs no property-list scan. Scanning cost dominated every target check.
		if _append_tags_from_dynamic_value(object.get(property_name), out_tags):
			return
	if object.has_meta(NODE_TAGS_META_NAME):
		_append_tags_from_dynamic_value(object.get_meta(NODE_TAGS_META_NAME), out_tags)


# Only direct children count. A recursive search made every ancestor of a tagged
# entity report that entity's tags, so container nodes matched their contents.
func _append_child_component_tags(node: Node, out_tags: Array[StringName]) -> void:
	for child in node.get_children():
		if child is GameplayTagComponent:
			out_tags.append_array(child.owned_tags)
