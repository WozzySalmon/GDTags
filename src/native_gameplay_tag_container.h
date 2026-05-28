#pragma once

#include "native_gameplay_tag.h"

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

class NativeGameplayTagContainer : public Resource {
	GDCLASS(NativeGameplayTagContainer, Resource);

private:
	Array tags;
	Dictionary tag_indices;

	StringName _variant_to_tag_name(const Variant &p_value) const;
	Array _extract_tag_names(const Variant &p_value) const;
	void _swap_remove_at(int64_t p_index);

protected:
	static void _bind_methods();

public:
	NativeGameplayTagContainer() = default;
	~NativeGameplayTagContainer() = default;

	void set_tags(const Array &p_tags);
	Array get_tags() const;

	bool add(const Variant &p_raw_tag);
	bool add_tag(const Variant &p_raw_tag);
	bool remove(const Variant &p_raw_tag);
	bool remove_tag(const Variant &p_raw_tag);
	bool has_exact(const Variant &p_raw_tag) const;
	bool has_tag_exact(const Variant &p_raw_tag) const;
	bool has(const Variant &p_raw_tag) const;
	bool has_tag(const Variant &p_raw_tag) const;
	bool has_any(const Variant &p_other) const;
	bool has_all(const Variant &p_other) const;
	bool matches_query(const Variant &p_query) const;
	void clear();
	Array to_array() const;
	Ref<NativeGameplayTagContainer> duplicate_container() const;
};
