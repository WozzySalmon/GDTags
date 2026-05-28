#include "native_gameplay_tag.h"

#include "native_gameplay_tag_utils.h"

#include <godot_cpp/core/class_db.hpp>

void NativeGameplayTag::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_tag_name", "tag_name"), &NativeGameplayTag::set_tag_name);
	ClassDB::bind_method(D_METHOD("get_tag_name"), &NativeGameplayTag::get_tag_name);
	ClassDB::bind_method(D_METHOD("is_empty"), &NativeGameplayTag::is_empty);
	ClassDB::bind_method(D_METHOD("parent_name"), &NativeGameplayTag::parent_name);
	ClassDB::bind_method(D_METHOD("is_child_of", "parent_tag"), &NativeGameplayTag::is_child_of);
	ClassDB::bind_method(D_METHOD("matches", "requested_tag", "exact"), &NativeGameplayTag::matches, DEFVAL(false));

	ADD_PROPERTY(PropertyInfo(Variant::STRING_NAME, "tag_name"), "set_tag_name", "get_tag_name");
}

void NativeGameplayTag::set_tag_name(const StringName &p_tag_name) {
	tag_name = p_tag_name;
}

StringName NativeGameplayTag::get_tag_name() const {
	return tag_name;
}

bool NativeGameplayTag::is_empty() const {
	return String(tag_name).is_empty();
}

StringName NativeGameplayTag::parent_name() const {
	String text = String(tag_name);
	int64_t dot = text.rfind(".");
	if (dot <= 0) {
		return StringName();
	}
	return StringName(text.substr(0, dot));
}

bool NativeGameplayTag::is_child_of(const Variant &p_parent_tag) const {
	String parent = gameplay_tags::normalized_tag_text(p_parent_tag);
	if (parent.is_empty()) {
		return false;
	}
	String text = String(tag_name);
	return text.begins_with(parent + ".");
}

bool NativeGameplayTag::matches(const Variant &p_requested_tag, bool p_exact) const {
	String requested = gameplay_tags::normalized_tag_text(p_requested_tag);
	String text = String(tag_name);
	if (p_exact) {
		return text == requested;
	}
	return text == requested || text.begins_with(requested + ".");
}

String NativeGameplayTag::_to_string() const {
	return String(tag_name);
}
