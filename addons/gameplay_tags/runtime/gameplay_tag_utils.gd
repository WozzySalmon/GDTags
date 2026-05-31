@tool
class_name GameplayTagUtils
extends RefCounted


static func normalize_tag_name(raw_tag: Variant) -> StringName:
	var has_object_tag_name := false
	var text := ""
	if raw_tag is Object:
		var object := raw_tag as Object
		for property in object.get_property_list():
			if String(property.get("name", "")) != "tag_name":
				continue
			var object_tag_name: Variant = object.get("tag_name")
			if object_tag_name is StringName or object_tag_name is String:
				has_object_tag_name = true
				text = String(object_tag_name)
			break

	if not has_object_tag_name:
		text = String(raw_tag)

	text = text.strip_edges()
	text = text.replace(" ", "")
	text = text.trim_prefix(".").trim_suffix(".")

	var clean_segments: Array[String] = []
	for segment in text.split(".", false):
		var clean := String(segment).strip_edges()
		if clean.is_empty():
			continue
		clean_segments.append(clean)

	if clean_segments.is_empty():
		return &""
	return StringName(".".join(clean_segments))
