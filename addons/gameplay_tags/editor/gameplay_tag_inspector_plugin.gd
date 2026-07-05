@tool
extends EditorInspectorPlugin

const TagArrayProperty := preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_array_property.gd"
)


func _can_handle(object: Object) -> bool:
	return (
		object is GameplayTagComponent
		or object is GameplayTagTrigger3D
		or object is GameplayTagContainer
		or object is GameplayTagQuery
	)


func _parse_property(
	object: Object,
	type: int,
	name: String,
	_hint_type: int,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if type != TYPE_ARRAY:
		return false
	if not _is_supported_tag_property_name(object, name):
		return false

	var editor := TagArrayProperty.new()
	add_property_editor(name, editor)
	return true


func _is_supported_tag_property_name(object: Object, property_name: String) -> bool:
	if object is GameplayTagComponent:
		return property_name == "owned_tags"
	if object is GameplayTagTrigger3D:
		return property_name == "required_tags"
	if object is GameplayTagContainer or object is GameplayTagQuery:
		return property_name == "tags"
	return false
