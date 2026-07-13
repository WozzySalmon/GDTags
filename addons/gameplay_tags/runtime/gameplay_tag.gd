@tool
class_name GameplayTag
extends Resource

@export var tag_name: StringName = &"":
	set(value):
		tag_name = GameplayTagDatabase.normalize_tag(value)
		emit_changed()


func _init(initial_name: StringName = &"") -> void:
	tag_name = GameplayTagDatabase.normalize_tag(initial_name)


func is_empty() -> bool:
	return String(tag_name).is_empty()


func parent_name() -> StringName:
	var parents: Array[StringName] = GameplayTagDatabase.get_parent_tags(tag_name)
	if parents.is_empty():
		return &""
	return parents[parents.size() - 1]


func is_child_of(parent_tag: StringName) -> bool:
	var text: String = String(tag_name)
	var parent: String = String(GameplayTagDatabase.normalize_tag(parent_tag))
	return not parent.is_empty() and text.begins_with(parent + ".")


func matches(requested_tag: StringName, exact: bool = false) -> bool:
	return GameplayTagDatabase.tag_matches(tag_name, requested_tag, exact)


func _to_string() -> String:
	return String(tag_name)
