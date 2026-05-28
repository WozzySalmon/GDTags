#pragma once

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

namespace gameplay_tags {

StringName normalize_tag_name(const Variant &p_raw_tag);
String normalized_tag_text(const Variant &p_raw_tag);

} // namespace gameplay_tags
