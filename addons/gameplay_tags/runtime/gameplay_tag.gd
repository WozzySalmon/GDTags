extends Resource
class_name GameplayTag

@export var tag_name: StringName = &""

func _init(initial_name: StringName = &"") -> void:
	tag_name = initial_name

func is_empty() -> bool:
	return String(tag_name).is_empty()

func parent_name() -> StringName:
	var text := String(tag_name)
	var dot := text.rfind(".")
	if dot <= 0:
		return &""
	return StringName(text.substr(0, dot))

func is_child_of(parent_tag: Variant) -> bool:
	var parent := String(parent_tag)
	if parent.is_empty():
		return false
	var text := String(tag_name)
	return text.begins_with(parent + ".")

func matches(requested_tag: Variant, exact: bool = false) -> bool:
	var requested := String(requested_tag)
	var text := String(tag_name)
	if exact:
		return text == requested
	return text == requested or text.begins_with(requested + ".")

func _to_string() -> String:
	return String(tag_name)
