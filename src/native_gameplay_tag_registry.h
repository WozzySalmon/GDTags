#pragma once

#include "native_gameplay_tag_container.h"
#include "native_gameplay_tag_database.h"
#include "native_gameplay_tag_query.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

class NativeGameplayTagRegistry : public RefCounted {
	GDCLASS(NativeGameplayTagRegistry, RefCounted);

private:
	Ref<NativeGameplayTagDatabase> database;

protected:
	static void _bind_methods();

public:
	NativeGameplayTagRegistry();
	~NativeGameplayTagRegistry() = default;

	void set_database(const Ref<NativeGameplayTagDatabase> &p_database);
	Ref<NativeGameplayTagDatabase> get_database() const;
	Error load_database(const String &p_path);
	Error save_database(const String &p_path) const;

	Ref<NativeGameplayTag> get_tag(const Variant &p_name) const;
	bool has_tag(const Variant &p_name) const;
	bool add_tag(const Variant &p_name, const String &p_description = String());
	int64_t add_tags(const Array &p_names);
	bool remove_tag(const Variant &p_name, bool p_remove_children = false);
	int64_t remove_tags(const Array &p_names, bool p_remove_children = false);
	TypedArray<NativeGameplayTag> get_child_tags(const Variant &p_parent, bool p_recursive = false) const;
	Ref<NativeGameplayTag> get_parent_tag(const Variant &p_tag) const;

	Ref<NativeGameplayTagContainer> make_container(const Array &p_initial_tags = Array()) const;
	Ref<NativeGameplayTagQuery> make_query_all(const Array &p_tag_list, bool p_exact = false) const;
	Ref<NativeGameplayTagQuery> make_query_any(const Array &p_tag_list, bool p_exact = false) const;
	Ref<NativeGameplayTagQuery> make_query_none(const Array &p_tag_list, bool p_exact = false) const;
};
