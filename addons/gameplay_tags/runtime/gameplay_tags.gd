@tool
extends Node

const DATABASE_SETTING := "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const COMPONENT_GROUP := "gameplay_tag_components"
const NODE_TAGS_META_NAME := "gameplay_tags"
const NODE_TAG_GROUP := "gameplay_tagged_nodes"

var _database: GameplayTagDatabase


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
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		clean_path = DEFAULT_DATABASE_PATH
	ProjectSettings.set_setting(DATABASE_SETTING, clean_path)
	ProjectSettings.set_initial_value(DATABASE_SETTING, DEFAULT_DATABASE_PATH)
	if save_project_settings:
		ProjectSettings.save()
	_database = null


func reload_database() -> GameplayTagDatabase:
	_database = _load_or_create_database()
	return _database


func save_database() -> Error:
	var database := get_database()
	var path := get_database_path()
	var directory_error := _ensure_database_directory(path)
	if directory_error != OK:
		push_error(
			"Could not create gameplay tag database directory: %s" % error_string(directory_error)
		)
		return directory_error
	if database.resource_path.is_empty() or database.resource_path != path:
		database.resource_path = path
	var save_error := ResourceSaver.save(database, path)
	if save_error != OK:
		push_error("Could not save gameplay tag database: %s" % error_string(save_error))
	return save_error


func normalize_tag(raw_tag: Variant) -> StringName:
	return GameplayTagDatabase.normalize_tag(raw_tag)


func is_valid_tag(raw_tag: Variant) -> bool:
	return get_database().has_tag(raw_tag)


func has_tag(raw_tag: Variant) -> bool:
	return is_valid_tag(raw_tag)


func request_tag(raw_tag: Variant) -> GameplayTag:
	return get_database().get_tag(raw_tag)


func add_tag(raw_tag: Variant, description: String = "", save_now: bool = true) -> bool:
	var added := get_database().add_tag(raw_tag, description)
	if added and save_now and save_database() != OK:
		return false
	return added


func remove_tag(raw_tag: Variant, remove_children: bool = false, save_now: bool = true) -> bool:
	var removed := get_database().remove_tag(raw_tag, remove_children)
	if removed and save_now and save_database() != OK:
		return false
	return removed


func ensure_parent_tags(raw_tag: Variant = &"", save_now: bool = true) -> bool:
	var changed := get_database().ensure_parent_tags(raw_tag)
	if changed and save_now and save_database() != OK:
		return false
	return changed


func get_all_tags() -> Array[StringName]:
	return get_database().get_all_tags()


func find_tags(search_text: String = "") -> Array[StringName]:
	return get_database().find_tags(search_text)


func import_tags_from_csv(path: String, save_now: bool = true) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open gameplay tags CSV: %s" % path)
		return 0

	var added := get_database().add_tags_from_csv_text(file.get_as_text())
	file.close()
	if added > 0 and save_now and save_database() != OK:
		return 0
	return added


func export_tags_to_csv(path: String) -> Error:
	var directory_error := _ensure_database_directory(path)
	if directory_error != OK:
		push_error(
			"Could not create gameplay tags CSV directory: %s" % error_string(directory_error)
		)
		return directory_error

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write gameplay tags CSV: %s" % path)
		return ERR_CANT_OPEN

	file.store_string(get_database().to_csv_text())
	file.close()
	return OK


func make_container(initial_tags: Array = []) -> GameplayTagContainer:
	return GameplayTagContainer.new(initial_tags)


func make_query_all(tags: Array, exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.all(tags, exact)


func make_query_any(tags: Array, exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.any(tags, exact)


func make_query_none(tags: Array, exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.none(tags, exact)


func get_node_tags(node: Node) -> GameplayTagContainer:
	if node == null:
		return GameplayTagContainer.new()
	var node_tags := _container_from_variant(node.get_meta(NODE_TAGS_META_NAME, []))
	if node_tags == null:
		return GameplayTagContainer.new()
	return node_tags


func set_node_tags(node: Node, raw_tags: Array, validate_with_database: bool = true) -> bool:
	if node == null:
		return false

	var node_tags := GameplayTagDatabase.canonicalize_tag_array(raw_tags)
	if validate_with_database:
		node_tags = _filter_tags_to_database(node_tags, true).get_tags()
	node.set_meta(NODE_TAGS_META_NAME, node_tags)
	_update_node_tag_group(node, node_tags)
	return true


func add_tag_to_node(node: Node, raw_tag: Variant, validate_with_database: bool = true) -> bool:
	return add_tags_to_node(node, [raw_tag], validate_with_database) == 1


func add_tags_to_node(node: Node, raw_tags: Array, validate_with_database: bool = true) -> int:
	if node == null:
		return 0

	var existing := get_node_tags(node)
	var candidates := GameplayTagDatabase.canonicalize_tag_array(raw_tags)
	if validate_with_database:
		candidates = _filter_tags_to_database(candidates, true).get_tags()
	var added := existing.add_tags(candidates)
	if added > 0:
		set_node_tags(node, existing.get_tags(), false)
	return added


func remove_tag_from_node(node: Node, raw_tag: Variant) -> bool:
	if node == null:
		return false

	var existing := get_node_tags(node)
	var removed := existing.remove_tag(raw_tag)
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


func get_nodes_with_tag(root: Node = null, tag: Variant = &"", exact: bool = false) -> Array[Node]:
	var matches: Array[Node] = []
	for node in get_tagged_nodes(root):
		if target_has_tag(node, tag, exact):
			matches.append(node)
	return matches


func get_owned_gameplay_tags(target: Variant) -> GameplayTagContainer:
	var result := GameplayTagContainer.new()
	if target is GameplayTagContainer:
		result = target.duplicate_container()
	elif target is Array:
		result = GameplayTagContainer.new(target)
	elif target is GameplayTag:
		result = GameplayTagContainer.new([target.tag_name])
	elif target is Object:
		result = _get_owned_gameplay_tags_from_object(target)
	return _filter_container_to_database(result)


func target_has_tag(target: Variant, tag: Variant, exact: bool = false) -> bool:
	return get_owned_gameplay_tags(target).has_tag(tag, exact)


func target_has_any(target: Variant, tags: Variant, exact: bool = false) -> bool:
	return get_owned_gameplay_tags(target).has_any(tags, exact)


func target_has_all(target: Variant, tags: Variant, exact: bool = false) -> bool:
	return get_owned_gameplay_tags(target).has_all(tags, exact)


func get_overlapping_bodies_with_tag(
	area: Area3D, tag: Variant, exact: bool = false
) -> Array[Node]:
	var matches: Array[Node] = []
	if area == null:
		return matches
	for body in area.get_overlapping_bodies():
		if body is Node and target_has_tag(body, tag, exact):
			matches.append(body)
	return matches


func get_overlapping_areas_with_tag(
	area: Area3D, tag: Variant, exact: bool = false
) -> Array[Area3D]:
	var matches: Array[Area3D] = []
	if area == null:
		return matches
	for overlap in area.get_overlapping_areas():
		if overlap is Area3D and target_has_tag(overlap, tag, exact):
			matches.append(overlap)
	return matches


func get_first_overlapping_target_with_tag(area: Area3D, tag: Variant, exact: bool = false) -> Node:
	if area == null:
		return null
	for body in area.get_overlapping_bodies():
		if body is Node and target_has_tag(body, tag, exact):
			return body
	for overlap in area.get_overlapping_areas():
		if overlap is Area3D and target_has_tag(overlap, tag, exact):
			return overlap
	return null


func _get_owned_gameplay_tags_from_object(object: Object) -> GameplayTagContainer:
	var result := GameplayTagContainer.new()
	if object is GameplayTagComponent:
		_add_container_tags(result, object.get_owned_gameplay_tags())
	elif object.has_method("get_owned_gameplay_tags") and object != self:
		var method_value: Variant = object.call("get_owned_gameplay_tags")
		_add_container_tags(result, _container_from_variant(method_value))
	elif object.has_method("get_gameplay_tags"):
		var tags_value: Variant = object.call("get_gameplay_tags")
		_add_container_tags(result, _container_from_variant(tags_value))

	_add_container_tags(result, _container_from_known_properties(object))
	if object is Node:
		var component := _find_tag_component(object)
		if component != null:
			_add_container_tags(result, component.get_owned_gameplay_tags())
	return result


func _filter_container_to_database(container: GameplayTagContainer) -> GameplayTagContainer:
	return _filter_tags_to_database(container.get_tags())


func _filter_tags_to_database(
	raw_tags: Array, warn_on_invalid: bool = false
) -> GameplayTagContainer:
	var registered_tags: Array[StringName] = []
	var database := get_database()
	for tag in GameplayTagDatabase.canonicalize_tag_array(raw_tags):
		if database.has_tag(tag):
			registered_tags.append(tag)
		elif warn_on_invalid:
			push_warning("Gameplay tag is not in the central database: %s" % String(tag))
	return GameplayTagContainer.new(registered_tags)


func _add_container_tags(target: GameplayTagContainer, source: GameplayTagContainer) -> void:
	if source != null:
		target.add_tags(source.get_tags())


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
	var seen := {}
	var tree := _get_tree_for_tag_search(root)
	if tree == null:
		return nodes

	for candidate in tree.get_nodes_in_group(NODE_TAG_GROUP):
		if candidate is Node:
			_append_tagged_node_candidate(nodes, seen, candidate, root)

	for candidate in tree.get_nodes_in_group(COMPONENT_GROUP):
		if candidate is GameplayTagComponent:
			var target := candidate.get_parent()
			if target == null:
				target = candidate
			_append_tagged_node_candidate(nodes, seen, target, root)
	return nodes


func _append_tagged_node_candidate(
	nodes: Array[Node], seen: Dictionary, node: Node, root: Node
) -> void:
	if node == null or not _is_node_under_root(node, root):
		return
	var instance_id := node.get_instance_id()
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


func _ensure_database_directory(path: String) -> Error:
	var directory := path.get_base_dir()
	if directory.is_empty() or directory == "res://" or directory == "user://":
		return OK
	return DirAccess.make_dir_recursive_absolute(directory)


func _load_or_create_database() -> GameplayTagDatabase:
	var path := get_database_path()
	var database: GameplayTagDatabase
	if ResourceLoader.exists(path):
		database = load(path) as GameplayTagDatabase
	if database == null:
		database = GameplayTagDatabase.new()
		database.resource_path = path
		var directory_error := _ensure_database_directory(path)
		if directory_error == OK:
			var save_error := ResourceSaver.save(database, path)
			if save_error != OK:
				push_error("Could not save gameplay tag database: %s" % error_string(save_error))
		else:
			push_error(
				(
					"Could not create gameplay tag database directory: %s"
					% error_string(directory_error)
				)
			)
	return database


func _container_from_variant(value: Variant) -> GameplayTagContainer:
	if value == null:
		return null
	if value is GameplayTagContainer:
		return value.duplicate_container()
	if value is Array:
		return GameplayTagContainer.new(value)
	if value is GameplayTag:
		return GameplayTagContainer.new([value.tag_name])
	if value is StringName or value is String:
		return GameplayTagContainer.new([value])
	return null


func _container_from_known_properties(object: Object) -> GameplayTagContainer:
	for property_name in ["owned_tags", "gameplay_tags", "tags"]:
		if not _object_has_property(object, property_name):
			continue
		var value: Variant = object.get(property_name)
		var container := _container_from_variant(value)
		if container != null:
			return container
	if object.has_meta(NODE_TAGS_META_NAME):
		return _container_from_variant(object.get_meta(NODE_TAGS_META_NAME))
	return null


func _object_has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _find_tag_component(node: Node) -> GameplayTagComponent:
	for child in node.get_children():
		if child is GameplayTagComponent:
			return child
	for child in node.get_children():
		var found := _find_tag_component(child)
		if found != null:
			return found
	return null
