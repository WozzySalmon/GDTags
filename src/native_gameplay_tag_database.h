#pragma once

#include "native_gameplay_tag.h"

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

class NativeGameplayTagDatabase : public Resource {
	GDCLASS(NativeGameplayTagDatabase, Resource);

private:
	Array tags;
	Dictionary tag_indices;
	Dictionary tag_descriptions;

	StringName _variant_to_tag_name(const Variant &p_value) const;
	void _swap_remove_at(int64_t p_index);

protected:
	static void _bind_methods();

public:
	NativeGameplayTagDatabase() = default;
	~NativeGameplayTagDatabase() = default;

	void set_tags(const Array &p_tags);
	Array get_tags() const;

	void set_tag_descriptions(const Dictionary &p_descriptions);
	Dictionary get_tag_descriptions() const;

	StringName normalize_tag_name(const Variant &p_raw_tag) const;
	bool add_tag(const Variant &p_raw_tag, const String &p_description = String());
	bool remove_tag(const Variant &p_raw_tag, bool p_remove_children = false);
	bool has_tag(const Variant &p_raw_tag) const;
	Ref<NativeGameplayTag> get_tag(const Variant &p_raw_tag) const;
	Ref<NativeGameplayTag> get_parent_tag(const Variant &p_raw_tag) const;
	TypedArray<NativeGameplayTag> get_child_tags(const Variant &p_raw_parent, bool p_recursive = false) const;
	TypedArray<NativeGameplayTag> get_all_tags() const;
	bool ensure_parent_tags();
	PackedStringArray validate() const;
	void clear();
};
