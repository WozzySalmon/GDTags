extends Resource
class_name GameplayTagQuery

enum Mode {
	ALL,
	ANY,
	NONE,
}

@export var mode: Mode = Mode.ALL
@export var tags: Array[StringName] = []
@export var exact: bool = false

static func all(tag_list: Array, require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, require_exact)

static func any(tag_list: Array, require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.ANY, tag_list, require_exact)

static func none(tag_list: Array, require_exact: bool = false) -> GameplayTagQuery:
	return _make(Mode.NONE, tag_list, require_exact)

static func exact_all(tag_list: Array) -> GameplayTagQuery:
	return _make(Mode.ALL, tag_list, true)

func matches(container: Variant) -> bool:
	if container == null or not container.has_method("has") or not container.has_method("has_exact"):
		return false

	match mode:
		Mode.ALL:
			for tag in tags:
				if not _container_has(container, tag):
					return false
			return true
		Mode.ANY:
			for tag in tags:
				if _container_has(container, tag):
					return true
			return false
		Mode.NONE:
			for tag in tags:
				if _container_has(container, tag):
					return false
			return true

	return false

func add(raw_tag: Variant) -> bool:
	var tag := _normalize(raw_tag)
	if tag == &"" or tags.has(tag):
		return false
	tags.append(tag)
	tags.sort_custom(Callable(self, "_sort_string_names"))
	emit_changed()
	return true

func remove(raw_tag: Variant) -> bool:
	var tag := _normalize(raw_tag)
	var index := tags.find(tag)
	if index < 0:
		return false
	tags.remove_at(index)
	emit_changed()
	return true

func clear() -> void:
	if tags.is_empty():
		return
	tags.clear()
	emit_changed()

static func _make(query_mode: Mode, tag_list: Array, require_exact: bool) -> GameplayTagQuery:
	var query := GameplayTagQuery.new()
	query.mode = query_mode
	query.exact = require_exact
	for item in tag_list:
		query.add(item)
	return query

func _container_has(container: Variant, tag: StringName) -> bool:
	if exact:
		return container.has_exact(tag)
	return container.has(tag)

func _normalize(raw_tag: Variant) -> StringName:
	if raw_tag is GameplayTag:
		return raw_tag.tag_name
	var text := String(raw_tag).strip_edges().trim_prefix(".").trim_suffix(".")
	if text.is_empty():
		return &""
	return StringName(text)

func _sort_string_names(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
