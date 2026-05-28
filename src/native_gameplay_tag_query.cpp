#include "native_gameplay_tag_query.h"

#include <godot_cpp/core/class_db.hpp>

namespace {
Ref<NativeGameplayTagQuery> make_query(NativeGameplayTagQuery::Mode p_mode, const Array &p_tags, bool p_exact) {
	Ref<NativeGameplayTagQuery> query;
	query.instantiate();
	query->set_mode(p_mode);
	query->set_exact(p_exact);
	for (int64_t i = 0; i < p_tags.size(); i++) {
		query->add(p_tags[i]);
	}
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
	ClassDB::bind_method(D_METHOD("remove", "raw_tag"), &NativeGameplayTagQuery::remove);
	ClassDB::bind_method(D_METHOD("clear"), &NativeGameplayTagQuery::clear);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "mode", PROPERTY_HINT_ENUM, "ALL,ANY,NONE"), "set_mode", "get_mode");
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "tags"), "set_tags", "get_tags");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "exact"), "set_exact", "get_exact");

	BIND_ENUM_CONSTANT(MODE_ALL);
	BIND_ENUM_CONSTANT(MODE_ANY);
	BIND_ENUM_CONSTANT(MODE_NONE);
}

StringName NativeGameplayTagQuery::_variant_to_tag_name(const Variant &p_value) const {
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

bool NativeGameplayTagQuery::_container_has(const NativeGameplayTagContainer *p_container, const StringName &p_tag) const {
	if (exact) {
		return p_container->has_exact(p_tag);
	}
	return p_container->has(p_tag);
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
		add(p_tags[i]);
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
	NativeGameplayTagContainer *container = Object::cast_to<NativeGameplayTagContainer>(object);
	if (container == nullptr) {
		return false;
	}

	switch (mode) {
		case MODE_ALL:
			for (int64_t i = 0; i < tags.size(); i++) {
				if (!_container_has(container, tags[i])) {
					return false;
				}
			}
			return true;
		case MODE_ANY:
			for (int64_t i = 0; i < tags.size(); i++) {
				if (_container_has(container, tags[i])) {
					return true;
				}
			}
			return false;
		case MODE_NONE:
			for (int64_t i = 0; i < tags.size(); i++) {
				if (_container_has(container, tags[i])) {
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

void NativeGameplayTagQuery::clear() {
	if (tags.is_empty()) {
		return;
	}
	tags.clear();
	emit_changed();
}
