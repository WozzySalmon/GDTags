#include "native_gameplay_tag_container.h"

#include <godot_cpp/core/class_db.hpp>

void NativeGameplayTagContainer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_tags", "tags"), &NativeGameplayTagContainer::set_tags);
	ClassDB::bind_method(D_METHOD("get_tags"), &NativeGameplayTagContainer::get_tags);
	ClassDB::bind_method(D_METHOD("add", "raw_tag"), &NativeGameplayTagContainer::add);
	ClassDB::bind_method(D_METHOD("add_tag", "raw_tag"), &NativeGameplayTagContainer::add_tag);
	ClassDB::bind_method(D_METHOD("remove", "raw_tag"), &NativeGameplayTagContainer::remove);
	ClassDB::bind_method(D_METHOD("remove_tag", "raw_tag"), &NativeGameplayTagContainer::remove_tag);
	ClassDB::bind_method(D_METHOD("has_exact", "raw_tag"), &NativeGameplayTagContainer::has_exact);
	ClassDB::bind_method(D_METHOD("has_tag_exact", "raw_tag"), &NativeGameplayTagContainer::has_tag_exact);
	ClassDB::bind_method(D_METHOD("has", "raw_tag"), &NativeGameplayTagContainer::has);
	ClassDB::bind_method(D_METHOD("has_tag", "raw_tag"), &NativeGameplayTagContainer::has_tag);
	ClassDB::bind_method(D_METHOD("has_any", "other"), &NativeGameplayTagContainer::has_any);
	ClassDB::bind_method(D_METHOD("has_all", "other"), &NativeGameplayTagContainer::has_all);
	ClassDB::bind_method(D_METHOD("matches_query", "query"), &NativeGameplayTagContainer::matches_query);
	ClassDB::bind_method(D_METHOD("clear"), &NativeGameplayTagContainer::clear);
	ClassDB::bind_method(D_METHOD("to_array"), &NativeGameplayTagContainer::to_array);
	ClassDB::bind_method(D_METHOD("duplicate_container"), &NativeGameplayTagContainer::duplicate_container);

	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "tags"), "set_tags", "get_tags");
}

StringName NativeGameplayTagContainer::_variant_to_tag_name(const Variant &p_value) const {
	if (p_value.get_type() == Variant::OBJECT) {
		Object *object = p_value;
		NativeGameplayTag *tag = Object::cast_to<NativeGameplayTag>(object);
		if (tag != nullptr) {
			return tag->get_tag_name();
		}
	}
	String text = String(p_value).strip_edges().trim_prefix(".").trim_suffix(".");
	if (text.is_empty()) {
		return StringName();
	}
	return StringName(text);
}

Array NativeGameplayTagContainer::_extract_tag_names(const Variant &p_value) const {
	Array result;
	if (p_value.get_type() == Variant::OBJECT) {
		Object *object = p_value;
		NativeGameplayTagContainer *container = Object::cast_to<NativeGameplayTagContainer>(object);
		if (container != nullptr) {
			return container->to_array();
		}
		NativeGameplayTag *tag = Object::cast_to<NativeGameplayTag>(object);
		if (tag != nullptr) {
			result.append(tag->get_tag_name());
			return result;
		}
	}
	if (p_value.get_type() == Variant::ARRAY) {
		Array input = p_value;
		for (int64_t i = 0; i < input.size(); i++) {
			StringName tag = _variant_to_tag_name(input[i]);
			if (!String(tag).is_empty()) {
				result.append(tag);
			}
		}
		return result;
	}
	StringName single = _variant_to_tag_name(p_value);
	if (!String(single).is_empty()) {
		result.append(single);
	}
	return result;
}

void NativeGameplayTagContainer::_swap_remove_at(int64_t p_index) {
	const int64_t last_index = tags.size() - 1;
	StringName removed = tags[p_index];
	if (p_index != last_index) {
		StringName moved = tags[last_index];
		tags[p_index] = moved;
		tag_indices[moved] = p_index;
	}
	tags.remove_at(last_index);
	tag_indices.erase(removed);
}

void NativeGameplayTagContainer::set_tags(const Array &p_tags) {
	tags.clear();
	tag_indices.clear();
	for (int64_t i = 0; i < p_tags.size(); i++) {
		add(p_tags[i]);
	}
	emit_changed();
}

Array NativeGameplayTagContainer::get_tags() const {
	return tags.duplicate();
}

bool NativeGameplayTagContainer::add(const Variant &p_raw_tag) {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	if (String(tag).is_empty() || tag_indices.has(tag)) {
		return false;
	}
	tag_indices[tag] = tags.size();
	tags.append(tag);
	emit_changed();
	return true;
}

bool NativeGameplayTagContainer::add_tag(const Variant &p_raw_tag) {
	return add(p_raw_tag);
}

bool NativeGameplayTagContainer::remove(const Variant &p_raw_tag) {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	if (!tag_indices.has(tag)) {
		return false;
	}
	_swap_remove_at((int64_t)tag_indices[tag]);
	emit_changed();
	return true;
}

bool NativeGameplayTagContainer::remove_tag(const Variant &p_raw_tag) {
	return remove(p_raw_tag);
}

bool NativeGameplayTagContainer::has_exact(const Variant &p_raw_tag) const {
	return tag_indices.has(_variant_to_tag_name(p_raw_tag));
}

bool NativeGameplayTagContainer::has_tag_exact(const Variant &p_raw_tag) const {
	return has_exact(p_raw_tag);
}

bool NativeGameplayTagContainer::has(const Variant &p_raw_tag) const {
	String requested = String(_variant_to_tag_name(p_raw_tag));
	if (requested.is_empty()) {
		return false;
	}
	if (tag_indices.has(StringName(requested))) {
		return true;
	}
	String prefix = requested + ".";
	for (int64_t i = 0; i < tags.size(); i++) {
		String owned = String(tags[i]);
		if (owned.begins_with(prefix)) {
			return true;
		}
	}
	return false;
}

bool NativeGameplayTagContainer::has_tag(const Variant &p_raw_tag) const {
	return has(p_raw_tag);
}

bool NativeGameplayTagContainer::has_any(const Variant &p_other) const {
	Array other_tags = _extract_tag_names(p_other);
	for (int64_t i = 0; i < other_tags.size(); i++) {
		if (has(other_tags[i])) {
			return true;
		}
	}
	return false;
}

bool NativeGameplayTagContainer::has_all(const Variant &p_other) const {
	Array other_tags = _extract_tag_names(p_other);
	for (int64_t i = 0; i < other_tags.size(); i++) {
		if (!has(other_tags[i])) {
			return false;
		}
	}
	return true;
}

bool NativeGameplayTagContainer::matches_query(const Variant &p_query) const {
	if (p_query.get_type() != Variant::OBJECT) {
		return false;
	}
	Object *object = p_query;
	if (object == nullptr || !object->has_method("matches")) {
		return false;
	}
	Array args;
	args.append(const_cast<NativeGameplayTagContainer *>(this));
	return (bool)object->callv("matches", args);
}

void NativeGameplayTagContainer::clear() {
	if (tags.is_empty()) {
		return;
	}
	tags.clear();
	tag_indices.clear();
	emit_changed();
}

Array NativeGameplayTagContainer::to_array() const {
	return tags.duplicate();
}

Ref<NativeGameplayTagContainer> NativeGameplayTagContainer::duplicate_container() const {
	Ref<NativeGameplayTagContainer> copy;
	copy.instantiate();
	copy->set_tags(tags);
	return copy;
}
