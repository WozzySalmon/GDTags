@tool
class_name GameplayTagQuery
extends Resource

enum Mode {
	ALL,
	ANY,
	NONE,
}

@export var mode: Mode = Mode.ALL
@export var tags: Array[StringName] = []:
	set(value):
		tags = GameplayTagDatabase.canonicalize_tag_array(value)
		emit_changed()

@export var exact: bool = false


static func all(tag_list: Array, require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, require_exact)


static func any(tag_list: Array, require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ANY, tag_list, require_exact)


static func none(tag_list: Array, require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.NONE, tag_list, require_exact)


static func exact_all(tag_list: Array) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, true)


func matches(target_or_container: Variant) -> bool:
	var container := _container_from_variant(target_or_container)
	if container == null:
		return false

	match mode:
		Mode.ALL:
			return container.has_all(tags, exact)
		Mode.ANY:
			return container.has_any(tags, exact)
		Mode.NONE:
			return not container.has_any(tags, exact)
	return false


func add_tag(raw_tag: Variant) -> bool:
	var tag := GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or tags.has(tag):
		return false
	tags.append(tag)
	tags = GameplayTagDatabase.canonicalize_tag_array(tags)
	emit_changed()
	return true


func add(raw_tag: Variant) -> bool:
	return add_tag(raw_tag)


func add_tags(raw_tags: Array) -> int:
	var added := 0
	for raw_tag in raw_tags:
		if add_tag(raw_tag):
			added += 1
	return added


func remove_tag(raw_tag: Variant) -> bool:
	var tag := GameplayTagDatabase.normalize_tag(raw_tag)
	var index := tags.find(tag)
	if index < 0:
		return false
	tags.remove_at(index)
	emit_changed()
	return true


func remove(raw_tag: Variant) -> bool:
	return remove_tag(raw_tag)


func remove_tags(raw_tags: Array) -> int:
	var removed := 0
	for raw_tag in raw_tags:
		if remove_tag(raw_tag):
			removed += 1
	return removed


func clear() -> void:
	if tags.is_empty():
		return
	tags.clear()
	emit_changed()


static func _make(query_mode: Mode, tag_list: Array, require_exact: bool) -> GameplayTagQuery:
	var query := GameplayTagQuery.new()
	query.mode = query_mode
	query.exact = require_exact
	query.tags = GameplayTagDatabase.canonicalize_tag_array(tag_list)
	return query


func _container_from_variant(value: Variant) -> GameplayTagContainer:
	if value is GameplayTagContainer:
		return value
	if value is GameplayTagComponent:
		return value.get_owned_gameplay_tags()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry := tree.root.get_node_or_null("GameplayTags")
	if registry != null and registry.has_method("get_owned_gameplay_tags"):
		return registry.get_owned_gameplay_tags(value)
	return null
