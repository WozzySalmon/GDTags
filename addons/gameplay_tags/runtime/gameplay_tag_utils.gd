@tool
class_name GameplayTagUtils
extends RefCounted


static func normalize_tag_name(raw_tag: Variant) -> StringName:
	return GameplayTagDatabase.normalize_tag(raw_tag)


static func tag_matches(owned_tag: Variant, requested_tag: Variant, exact: bool = false) -> bool:
	return GameplayTagDatabase.tag_matches(owned_tag, requested_tag, exact)


static func canonicalize_tag_array(raw_tags: Array) -> Array[StringName]:
	return GameplayTagDatabase.canonicalize_tag_array(raw_tags)
