#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

class NativeGameplayTag : public Resource {
	GDCLASS(NativeGameplayTag, Resource);

private:
	StringName tag_name;

protected:
	static void _bind_methods();

public:
	NativeGameplayTag() = default;
	~NativeGameplayTag() = default;

	void set_tag_name(const StringName &p_tag_name);
	StringName get_tag_name() const;

	bool is_empty() const;
	StringName parent_name() const;
	bool is_child_of(const Variant &p_parent_tag) const;
	bool matches(const Variant &p_requested_tag, bool p_exact = false) const;
	String _to_string() const;
};
