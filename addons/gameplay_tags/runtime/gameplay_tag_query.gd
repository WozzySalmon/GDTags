@tool
class_name GameplayTagQuery
extends Resource

enum Mode {
	ALL,
	ANY,
	NONE,
}

@export var mode: Mode = Mode.ALL:
	set(value):
		if mode == value:
			return
		mode = value
		emit_changed()

@export var tags: Array[StringName] = []:
	set(value):
		tags = GameplayTagDatabase.canonicalize_tag_array(value)
		emit_changed()

@export var exact: bool = false:
	set(value):
		if exact == value:
			return
		exact = value
		emit_changed()


static func all(tag_list: Array[StringName], require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, require_exact)


static func any(tag_list: Array[StringName], require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ANY, tag_list, require_exact)


static func none(tag_list: Array[StringName], require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.NONE, tag_list, require_exact)


static func exact_all(tag_list: Array[StringName]) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, true)


func matches(target: Object) -> bool:
	var container: GameplayTagContainer = _container_from_target(target)
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


func add_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	if tag == &"" or tags.has(tag):
		return false
	tags.append(tag)
	tags = GameplayTagDatabase.canonicalize_tag_array(tags)
	emit_changed()
	return true


func add(raw_tag: StringName) -> bool:
	return add_tag(raw_tag)


func add_tags(raw_tags: Array[StringName]) -> int:
	var added: int = 0
	for raw_tag in raw_tags:
		if add_tag(raw_tag):
			added += 1
	return added


func remove_tag(raw_tag: StringName) -> bool:
	var tag: StringName = GameplayTagDatabase.normalize_tag(raw_tag)
	var index: int = tags.find(tag)
	if index < 0:
		return false
	tags.remove_at(index)
	emit_changed()
	return true


func remove(raw_tag: StringName) -> bool:
	return remove_tag(raw_tag)


func remove_tags(raw_tags: Array[StringName]) -> int:
	var removed: int = 0
	for raw_tag in raw_tags:
		if remove_tag(raw_tag):
			removed += 1
	return removed


func clear() -> void:
	if tags.is_empty():
		return
	tags.clear()
	emit_changed()


static func _make(
	query_mode: Mode, tag_list: Array[StringName], require_exact: bool
) -> GameplayTagQuery:
	var query: GameplayTagQuery = GameplayTagQuery.new()
	query.mode = query_mode
	query.exact = require_exact
	query.tags = GameplayTagDatabase.canonicalize_tag_array(tag_list)
	return query


func _container_from_target(target: Object) -> GameplayTagContainer:
	if target is GameplayTagContainer:
		return target
	if target is GameplayTagComponent:
		return target.get_owned_gameplay_tags()
	var registry: Node = GameplayTagUtils.get_registry()
	if registry != null and registry.has_method("get_owned_gameplay_tags"):
		return registry.get_owned_gameplay_tags(target) as GameplayTagContainer
	return null
