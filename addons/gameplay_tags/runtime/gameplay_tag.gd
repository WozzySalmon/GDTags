@tool
class_name GameplayTag
extends Resource
## A single hierarchical gameplay tag such as [code]State.Stunned[/code].
## Names are normalized on assignment. Matching is hierarchical by default, so
## [code]State.Stunned[/code] satisfies a request for [code]State[/code].

@export var tag_name: StringName = &"":
	set(value):
		tag_name = GameplayTagDatabase.normalize_tag(value)
		emit_changed()


func _init(initial_name: StringName = &"") -> void:
	tag_name = GameplayTagDatabase.normalize_tag(initial_name)


## Returns whether this tag holds no name.
func is_empty() -> bool:
	return String(tag_name).is_empty()


## Returns the immediate parent tag name, or an empty StringName at the root.
func parent_name() -> StringName:
	var parents: Array[StringName] = GameplayTagDatabase.get_parent_tags(tag_name)
	if parents.is_empty():
		return &""
	return parents[parents.size() - 1]


## Returns whether this tag sits strictly beneath [param parent_tag] in the hierarchy.
func is_child_of(parent_tag: StringName) -> bool:
	var text: String = String(tag_name)
	var parent: String = String(GameplayTagDatabase.normalize_tag(parent_tag))
	return not parent.is_empty() and text.begins_with(parent + ".")


## Returns whether this tag satisfies [param requested_tag].
## Parent tags match their children unless [param exact] is true.
func matches(requested_tag: StringName, exact: bool = false) -> bool:
	return GameplayTagDatabase.tag_matches(tag_name, requested_tag, exact)


func _to_string() -> String:
	return String(tag_name)
