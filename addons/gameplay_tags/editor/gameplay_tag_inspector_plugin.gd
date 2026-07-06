@tool
extends EditorInspectorPlugin

const TagArrayProperty := preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_array_property.gd"
)
const TagProperty := preload("res://addons/gameplay_tags/editor/gameplay_tag_property.gd")


func _can_handle(object: Object) -> bool:
	if object is GameplayTag:
		return true
	for property in object.get_property_list():
		if _property_uses_gameplay_tag_editor(object, property):
			return true
	return false


func _parse_property(
	object: Object,
	type: int,
	name: String,
	hint_type: int,
	hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if _is_gameplay_tag_name_property(object, type, name):
		var tag_name_editor := TagProperty.new()
		tag_name_editor.value_mode = TagProperty.VALUE_STRING_NAME
		add_property_editor(name, tag_name_editor)
		return true

	if _is_gameplay_tag_resource_property(type, hint_type, hint_string):
		var tag_editor := TagProperty.new()
		tag_editor.value_mode = TagProperty.VALUE_RESOURCE
		add_property_editor(name, tag_editor)
		return true

	if type == TYPE_ARRAY and _is_supported_tag_property_name(object, name):
		var array_editor := TagArrayProperty.new()
		add_property_editor(name, array_editor)
		return true

	return false


func _property_uses_gameplay_tag_editor(object: Object, property: Dictionary) -> bool:
	var property_name := String(property.get("name", ""))
	var property_type := int(property.get("type", TYPE_NIL))
	var hint_type := int(property.get("hint", PROPERTY_HINT_NONE))
	var hint_string := String(property.get("hint_string", ""))
	return (
		_is_supported_tag_property_name(object, property_name)
		or _is_gameplay_tag_resource_property(property_type, hint_type, hint_string)
	)


func _is_gameplay_tag_name_property(object: Object, type: int, property_name: String) -> bool:
	return object is GameplayTag and type == TYPE_STRING_NAME and property_name == "tag_name"


func _is_gameplay_tag_resource_property(type: int, hint_type: int, hint_string: String) -> bool:
	return (
		type == TYPE_OBJECT
		and hint_type == PROPERTY_HINT_RESOURCE_TYPE
		and _hint_includes_gameplay_tag(hint_string)
	)


func _hint_includes_gameplay_tag(hint_string: String) -> bool:
	for hint in hint_string.split(",", false):
		if hint.strip_edges() == "GameplayTag":
			return true
	return false


func _is_supported_tag_property_name(object: Object, property_name: String) -> bool:
	if object is GameplayTagComponent:
		return property_name == "owned_tags"
	if object is GameplayTagTrigger3D:
		return property_name == "required_tags"
	if object is GameplayTagContainer or object is GameplayTagQuery:
		return property_name == "tags"
	return false
