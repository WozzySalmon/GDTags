#include "native_gameplay_tag_utils.h"

#include "native_gameplay_tag.h"

#include <godot_cpp/variant/packed_string_array.hpp>

namespace gameplay_tags {

namespace {
StringName normalize_tag_text(String p_text) {
	String text = p_text.strip_edges();
	text = text.replace(" ", "");
	text = text.trim_prefix(".").trim_suffix(".");

	PackedStringArray segments = text.split(".", false);
	String clean_text;
	for (int64_t i = 0; i < segments.size(); i++) {
		String clean = String(segments[i]).strip_edges();
		if (clean.is_empty()) {
			continue;
		}
		if (!clean_text.is_empty()) {
			clean_text += ".";
		}
		clean_text += clean;
	}

	if (clean_text.is_empty()) {
		return StringName();
	}
	return StringName(clean_text);
}
} // namespace

StringName normalize_tag_name(const Variant &p_raw_tag) {
	if (p_raw_tag.get_type() == Variant::OBJECT) {
		Object *object = p_raw_tag;
		NativeGameplayTag *tag = Object::cast_to<NativeGameplayTag>(object);
		if (tag != nullptr) {
			return normalize_tag_text(String(tag->get_tag_name()));
		}
	}

	return normalize_tag_text(String(p_raw_tag));
}

String normalized_tag_text(const Variant &p_raw_tag) {
	return String(normalize_tag_name(p_raw_tag));
}

} // namespace gameplay_tags
