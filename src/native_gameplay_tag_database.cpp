#include "native_gameplay_tag_database.h"

#include <godot_cpp/core/class_db.hpp>

namespace {
Ref<NativeGameplayTag> make_native_tag(const StringName &p_name) {
	Ref<NativeGameplayTag> tag;
	tag.instantiate();
	tag->set_tag_name(p_name);
	return tag;
}
} // namespace

void NativeGameplayTagDatabase::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_tags", "tags"), &NativeGameplayTagDatabase::set_tags);
	ClassDB::bind_method(D_METHOD("get_tags"), &NativeGameplayTagDatabase::get_tags);
	ClassDB::bind_method(D_METHOD("set_tag_descriptions", "tag_descriptions"), &NativeGameplayTagDatabase::set_tag_descriptions);
	ClassDB::bind_method(D_METHOD("get_tag_descriptions"), &NativeGameplayTagDatabase::get_tag_descriptions);

	ClassDB::bind_method(D_METHOD("normalize_tag_name", "raw_tag"), &NativeGameplayTagDatabase::normalize_tag_name);
	ClassDB::bind_method(D_METHOD("add_tag", "raw_tag", "description"), &NativeGameplayTagDatabase::add_tag, DEFVAL(String()));
	ClassDB::bind_method(D_METHOD("remove_tag", "raw_tag", "remove_children"), &NativeGameplayTagDatabase::remove_tag, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("has_tag", "raw_tag"), &NativeGameplayTagDatabase::has_tag);
	ClassDB::bind_method(D_METHOD("get_tag", "raw_tag"), &NativeGameplayTagDatabase::get_tag);
	ClassDB::bind_method(D_METHOD("get_parent_tag", "raw_tag"), &NativeGameplayTagDatabase::get_parent_tag);
	ClassDB::bind_method(D_METHOD("get_child_tags", "raw_parent", "recursive"), &NativeGameplayTagDatabase::get_child_tags, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("get_all_tags"), &NativeGameplayTagDatabase::get_all_tags);
	ClassDB::bind_method(D_METHOD("ensure_parent_tags"), &NativeGameplayTagDatabase::ensure_parent_tags);
	ClassDB::bind_method(D_METHOD("validate"), &NativeGameplayTagDatabase::validate);
	ClassDB::bind_method(D_METHOD("clear"), &NativeGameplayTagDatabase::clear);

	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "tags"), "set_tags", "get_tags");
	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "tag_descriptions"), "set_tag_descriptions", "get_tag_descriptions");
}

StringName NativeGameplayTagDatabase::_variant_to_tag_name(const Variant &p_value) const {
	if (p_value.get_type() == Variant::OBJECT) {
		Object *object = p_value;
		NativeGameplayTag *tag = Object::cast_to<NativeGameplayTag>(object);
		if (tag != nullptr) {
			return tag->get_tag_name();
		}
	}
	return normalize_tag_name(p_value);
}

void NativeGameplayTagDatabase::_swap_remove_at(int64_t p_index) {
	const int64_t last_index = tags.size() - 1;
	StringName removed = tags[p_index];
	if (p_index != last_index) {
		StringName moved = tags[last_index];
		tags[p_index] = moved;
		tag_indices[moved] = p_index;
	}
	tags.remove_at(last_index);
	tag_indices.erase(removed);
	tag_descriptions.erase(String(removed));
}

void NativeGameplayTagDatabase::set_tags(const Array &p_tags) {
	tags.clear();
	tag_indices.clear();
	for (int64_t i = 0; i < p_tags.size(); i++) {
		add_tag(p_tags[i]);
	}
	emit_changed();
}

Array NativeGameplayTagDatabase::get_tags() const {
	return tags.duplicate();
}

void NativeGameplayTagDatabase::set_tag_descriptions(const Dictionary &p_descriptions) {
	tag_descriptions = p_descriptions.duplicate(true);
	emit_changed();
}

Dictionary NativeGameplayTagDatabase::get_tag_descriptions() const {
	return tag_descriptions.duplicate(true);
}

StringName NativeGameplayTagDatabase::normalize_tag_name(const Variant &p_raw_tag) const {
	String text = String(p_raw_tag).strip_edges();
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

bool NativeGameplayTagDatabase::add_tag(const Variant &p_raw_tag, const String &p_description) {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	if (String(tag).is_empty() || tag_indices.has(tag)) {
		return false;
	}

	tag_indices[tag] = tags.size();
	tags.append(tag);
	if (!p_description.is_empty()) {
		tag_descriptions[String(tag)] = p_description;
	}
	emit_changed();
	return true;
}

bool NativeGameplayTagDatabase::remove_tag(const Variant &p_raw_tag, bool p_remove_children) {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	if (String(tag).is_empty()) {
		return false;
	}

	if (!p_remove_children) {
		if (!tag_indices.has(tag)) {
			return false;
		}
		_swap_remove_at((int64_t)tag_indices[tag]);
		emit_changed();
		return true;
	}

	String tag_text = String(tag);
	bool removed = false;
	for (int64_t i = tags.size() - 1; i >= 0; i--) {
		StringName existing = tags[i];
		String existing_text = String(existing);
		if (existing == tag || existing_text.begins_with(tag_text + ".")) {
			_swap_remove_at(i);
			removed = true;
		}
	}
	if (removed) {
		emit_changed();
	}
	return removed;
}

bool NativeGameplayTagDatabase::has_tag(const Variant &p_raw_tag) const {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	return tag_indices.has(tag);
}

Ref<NativeGameplayTag> NativeGameplayTagDatabase::get_tag(const Variant &p_raw_tag) const {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	if (String(tag).is_empty() || !tag_indices.has(tag)) {
		return Ref<NativeGameplayTag>();
	}
	return make_native_tag(tag);
}

Ref<NativeGameplayTag> NativeGameplayTagDatabase::get_parent_tag(const Variant &p_raw_tag) const {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	String text = String(tag);
	int64_t dot = text.rfind(".");
	if (dot <= 0) {
		return Ref<NativeGameplayTag>();
	}
	StringName parent = StringName(text.substr(0, dot));
	if (!tag_indices.has(parent)) {
		return Ref<NativeGameplayTag>();
	}
	return make_native_tag(parent);
}

TypedArray<NativeGameplayTag> NativeGameplayTagDatabase::get_child_tags(const Variant &p_raw_parent, bool p_recursive) const {
	TypedArray<NativeGameplayTag> children;
	StringName parent = _variant_to_tag_name(p_raw_parent);
	String parent_text = String(parent);
	if (parent_text.is_empty()) {
		return children;
	}

	String prefix = parent_text + ".";
	for (int64_t i = 0; i < tags.size(); i++) {
		StringName tag = tags[i];
		String text = String(tag);
		if (!text.begins_with(prefix)) {
			continue;
		}
		String rest = text.substr(prefix.length());
		if (p_recursive || !rest.contains(".")) {
			children.append(make_native_tag(tag));
		}
	}
	return children;
}

TypedArray<NativeGameplayTag> NativeGameplayTagDatabase::get_all_tags() const {
	TypedArray<NativeGameplayTag> result;
	for (int64_t i = 0; i < tags.size(); i++) {
		result.append(make_native_tag(tags[i]));
	}
	return result;
}

bool NativeGameplayTagDatabase::ensure_parent_tags() {
	Array missing;
	for (int64_t i = 0; i < tags.size(); i++) {
		String text = String(tags[i]);
		while (text.contains(".")) {
			text = text.substr(0, text.rfind("."));
			StringName parent = StringName(text);
			if (!tag_indices.has(parent) && !missing.has(parent)) {
				missing.append(parent);
			}
		}
	}

	for (int64_t i = 0; i < missing.size(); i++) {
		add_tag(missing[i]);
	}
	return !missing.is_empty();
}

PackedStringArray NativeGameplayTagDatabase::validate() const {
	PackedStringArray errors;
	Dictionary seen;
	for (int64_t i = 0; i < tags.size(); i++) {
		String text = String(tags[i]);
		if (text.is_empty()) {
			errors.append("Empty tag name");
		}
		if (seen.has(text)) {
			errors.append("Duplicate tag: " + text);
		}
		seen[text] = true;
		if (text.begins_with(".") || text.ends_with(".") || text.contains("..")) {
			errors.append("Invalid hierarchy path: " + text);
		}
	}
	return errors;
}

void NativeGameplayTagDatabase::clear() {
	if (tags.is_empty()) {
		return;
	}
	tags.clear();
	tag_indices.clear();
	tag_descriptions.clear();
	emit_changed();
}
