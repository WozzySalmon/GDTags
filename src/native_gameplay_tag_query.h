#pragma once

#include "native_gameplay_tag.h"
#include "native_gameplay_tag_container.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

class NativeGameplayTagQuery : public Resource {
	GDCLASS(NativeGameplayTagQuery, Resource);

public:
	enum Mode {
		MODE_ALL = 0,
		MODE_ANY = 1,
		MODE_NONE = 2,
	};

private:
	Mode mode = MODE_ALL;
	Array tags;
	bool exact = false;

	StringName _variant_to_tag_name(const Variant &p_value) const;
	bool _container_has(Object *p_container, const StringName &p_tag) const;

protected:
	static void _bind_methods();

public:
	NativeGameplayTagQuery() = default;
	~NativeGameplayTagQuery() = default;

	void set_mode(Mode p_mode);
	Mode get_mode() const;
	void set_tags(const Array &p_tags);
	Array get_tags() const;
	void set_exact(bool p_exact);
	bool get_exact() const;

	static Ref<NativeGameplayTagQuery> all(const Array &p_tags, bool p_require_exact = false);
	static Ref<NativeGameplayTagQuery> any(const Array &p_tags, bool p_require_exact = false);
	static Ref<NativeGameplayTagQuery> none(const Array &p_tags, bool p_require_exact = false);
	static Ref<NativeGameplayTagQuery> exact_all(const Array &p_tags);

	bool matches(const Variant &p_container) const;
	bool add(const Variant &p_raw_tag);
	int64_t add_tags(const Array &p_raw_tags);
	bool remove(const Variant &p_raw_tag);
	int64_t remove_tags(const Array &p_raw_tags);
	void clear();
};

VARIANT_ENUM_CAST(NativeGameplayTagQuery::Mode);
