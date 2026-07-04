#include "native_gameplay_tag_query.h"

#include "native_gameplay_tag_utils.h"

#include <godot_cpp/core/class_db.hpp>

namespace {
Ref<NativeGameplayTagQuery> make_query(NativeGameplayTagQuery::Mode p_mode, const Array &p_tags, bool p_exact) {
	Ref<NativeGameplayTagQuery> query;
	query.instantiate();
	query->set_mode(p_mode);
	query->set_exact(p_exact);
	query->add_tags(p_tags);
	return query;
}
} // namespace

void NativeGameplayTagQuery::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_mode", "mode"), &NativeGameplayTagQuery::set_mode);
	ClassDB::bind_method(D_METHOD("get_mode"), &NativeGameplayTagQuery::get_mode);
	ClassDB::bind_method(D_METHOD("set_tags", "tags"), &NativeGameplayTagQuery::set_tags);
	ClassDB::bind_method(D_METHOD("get_tags"), &NativeGameplayTagQuery::get_tags);
	ClassDB::bind_method(D_METHOD("set_exact", "exact"), &NativeGameplayTagQuery::set_exact);
	ClassDB::bind_method(D_METHOD("get_exact"), &NativeGameplayTagQuery::get_exact);

	ClassDB::bind_static_method("NativeGameplayTagQuery", D_METHOD("all", "tag_list", "require_exact"), &NativeGameplayTagQuery::all, DEFVAL(false));
	ClassDB::bind_static_method("NativeGameplayTagQuery", D_METHOD("any", "tag_list", "require_exact"), &NativeGameplayTagQuery::any, DEFVAL(false));
	ClassDB::bind_static_method("NativeGameplayTagQuery", D_METHOD("none", "tag_list", "require_exact"), &NativeGameplayTagQuery::none, DEFVAL(false));
	ClassDB::bind_static_method("NativeGameplayTagQuery", D_METHOD("exact_all", "tag_list"), &NativeGameplayTagQuery::exact_all);

	ClassDB::bind_method(D_METHOD("matches", "container"), &NativeGameplayTagQuery::matches);
	ClassDB::bind_method(D_METHOD("add", "raw_tag"), &NativeGameplayTagQuery::add);
	ClassDB::bind_method(D_METHOD("add_tags", "raw_tags"), &NativeGameplayTagQuery::add_tags);
	ClassDB::bind_method(D_METHOD("remove", "raw_tag"), &NativeGameplayTagQuery::remove);
	ClassDB::bind_method(D_METHOD("remove_tags", "raw_tags"), &NativeGameplayTagQuery::remove_tags);
	ClassDB::bind_method(D_METHOD("clear"), &NativeGameplayTagQuery::clear);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "mode", PROPERTY_HINT_ENUM, "ALL,ANY,NONE"), "set_mode", "get_mode");
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "tags"), "set_tags", "get_tags");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "exact"), "set_exact", "get_exact");

	BIND_ENUM_CONSTANT(MODE_ALL);
	BIND_ENUM_CONSTANT(MODE_ANY);
	BIND_ENUM_CONSTANT(MODE_NONE);
}

StringName NativeGameplayTagQuery::_variant_to_tag_name(const Variant &p_value) const {
	return gameplay_tags::normalize_tag_name(p_value);
}

bool NativeGameplayTagQuery::_container_has(Object *p_container, const StringName &p_tag) const {
	NativeGameplayTagContainer *native_container = Object::cast_to<NativeGameplayTagContainer>(p_container);
	if (native_container != nullptr) {
		return exact ? native_container->has_exact(p_tag) : native_container->has(p_tag);
	}

	StringName method = exact ? StringName("has_exact") : StringName("has");
	if (p_container == nullptr || !p_container->has_method(method)) {
		return false;
	}

	Array args;
	args.append(p_tag);
	return (bool)p_container->callv(method, args);
}

void NativeGameplayTagQuery::set_mode(Mode p_mode) {
	mode = p_mode;
	emit_changed();
}

NativeGameplayTagQuery::Mode NativeGameplayTagQuery::get_mode() const {
	return mode;
}

void NativeGameplayTagQuery::set_tags(const Array &p_tags) {
	tags.clear();
	for (int64_t i = 0; i < p_tags.size(); i++) {
		StringName tag = _variant_to_tag_name(p_tags[i]);
		if (String(tag).is_empty() || tags.has(tag)) {
			continue;
		}
		tags.append(tag);
	}
	emit_changed();
}

Array NativeGameplayTagQuery::get_tags() const {
	return tags.duplicate();
}

void NativeGameplayTagQuery::set_exact(bool p_exact) {
	exact = p_exact;
	emit_changed();
}

bool NativeGameplayTagQuery::get_exact() const {
	return exact;
}

Ref<NativeGameplayTagQuery> NativeGameplayTagQuery::all(const Array &p_tags, bool p_require_exact) {
	return make_query(MODE_ALL, p_tags, p_require_exact);
}

Ref<NativeGameplayTagQuery> NativeGameplayTagQuery::any(const Array &p_tags, bool p_require_exact) {
	return make_query(MODE_ANY, p_tags, p_require_exact);
}

Ref<NativeGameplayTagQuery> NativeGameplayTagQuery::none(const Array &p_tags, bool p_require_exact) {
	return make_query(MODE_NONE, p_tags, p_require_exact);
}

Ref<NativeGameplayTagQuery> NativeGameplayTagQuery::exact_all(const Array &p_tags) {
	return make_query(MODE_ALL, p_tags, true);
}

bool NativeGameplayTagQuery::matches(const Variant &p_container) const {
	if (p_container.get_type() != Variant::OBJECT) {
		return false;
	}
	Object *object = p_container;
	if (!object->has_method("has") || !object->has_method("has_exact")) {
		return false;
	}

	switch (mode) {
		case MODE_ALL:
			for (int64_t i = 0; i < tags.size(); i++) {
				if (!_container_has(object, tags[i])) {
					return false;
				}
			}
			return true;
		case MODE_ANY:
			for (int64_t i = 0; i < tags.size(); i++) {
				if (_container_has(object, tags[i])) {
					return true;
				}
			}
			return false;
		case MODE_NONE:
			for (int64_t i = 0; i < tags.size(); i++) {
				if (_container_has(object, tags[i])) {
					return false;
				}
			}
			return true;
	}
	return false;
}

bool NativeGameplayTagQuery::add(const Variant &p_raw_tag) {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	if (String(tag).is_empty() || tags.has(tag)) {
		return false;
	}
	tags.append(tag);
	emit_changed();
	return true;
}

int64_t NativeGameplayTagQuery::add_tags(const Array &p_raw_tags) {
	int64_t added = 0;
	for (int64_t i = 0; i < p_raw_tags.size(); i++) {
		StringName tag = _variant_to_tag_name(p_raw_tags[i]);
		if (String(tag).is_empty() || tags.has(tag)) {
			continue;
		}
		tags.append(tag);
		added++;
	}
	if (added > 0) {
		emit_changed();
	}
	return added;
}

bool NativeGameplayTagQuery::remove(const Variant &p_raw_tag) {
	StringName tag = _variant_to_tag_name(p_raw_tag);
	int64_t index = tags.find(tag);
	if (index < 0) {
		return false;
	}
	tags.remove_at(index);
	emit_changed();
	return true;
}

int64_t NativeGameplayTagQuery::remove_tags(const Array &p_raw_tags) {
	int64_t removed = 0;
	for (int64_t i = 0; i < p_raw_tags.size(); i++) {
		StringName tag = _variant_to_tag_name(p_raw_tags[i]);
		int64_t index = tags.find(tag);
		if (index < 0) {
			continue;
		}
		tags.remove_at(index);
		removed++;
	}
	if (removed > 0) {
		emit_changed();
	}
	return removed;
}

void NativeGameplayTagQuery::clear() {
	if (tags.is_empty()) {
		return;
	}
	tags.clear();
	emit_changed();
}
