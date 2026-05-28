#include "register_types.h"

#include "native_gameplay_tag.h"
#include "native_gameplay_tag_container.h"
#include "native_gameplay_tag_database.h"
#include "native_gameplay_tag_query.h"
#include "native_gameplay_tag_registry.h"

#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_gameplay_tags_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	GDREGISTER_CLASS(NativeGameplayTag);
	GDREGISTER_CLASS(NativeGameplayTagDatabase);
	GDREGISTER_CLASS(NativeGameplayTagContainer);
	GDREGISTER_CLASS(NativeGameplayTagQuery);
	GDREGISTER_CLASS(NativeGameplayTagRegistry);
}

void uninitialize_gameplay_tags_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT gameplay_tags_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_gameplay_tags_module);
	init_obj.register_terminator(uninitialize_gameplay_tags_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
