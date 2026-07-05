@tool
extends Node

const DATABASE_SETTING := "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const COMPONENT_GROUP := "gameplay_tag_components"

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


func make_container(initial_tags: Array = []) -> GameplayTagContainer:
	return GameplayTagContainer.new(initial_tags)


func make_query_all(tags: Array, exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.all(tags, exact)


func make_query_any(tags: Array, exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.any(tags, exact)


func make_query_none(tags: Array, exact: bool = false) -> GameplayTagQuery:
	return GameplayTagQuery.none(tags, exact)


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
		result = object.get_owned_gameplay_tags()
	elif object.has_method("get_owned_gameplay_tags") and object != self:
		var method_value: Variant = object.call("get_owned_gameplay_tags")
		result = _container_from_variant(method_value)
	elif object.has_method("get_gameplay_tags"):
		var tags_value: Variant = object.call("get_gameplay_tags")
		result = _container_from_variant(tags_value)

	if result != null and not result.is_empty():
		return result

	var property_container := _container_from_known_properties(object)
	if property_container != null:
		result = property_container
	elif object is Node:
		var component := _find_tag_component(object)
		if component != null:
			result = component.get_owned_gameplay_tags()

	if result == null:
		result = GameplayTagContainer.new()
	return result


func _filter_container_to_database(container: GameplayTagContainer) -> GameplayTagContainer:
	var registered_tags: Array[StringName] = []
	var database := get_database()
	for tag in container.get_tags():
		if database.has_tag(tag):
			registered_tags.append(tag)
	return GameplayTagContainer.new(registered_tags)


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
	if object.has_meta("gameplay_tags"):
		return _container_from_variant(object.get_meta("gameplay_tags"))
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
