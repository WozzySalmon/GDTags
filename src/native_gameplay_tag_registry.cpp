#include "native_gameplay_tag_registry.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/core/class_db.hpp>

void NativeGameplayTagRegistry::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_database", "database"), &NativeGameplayTagRegistry::set_database);
	ClassDB::bind_method(D_METHOD("get_database"), &NativeGameplayTagRegistry::get_database);
	ClassDB::bind_method(D_METHOD("load_database", "path"), &NativeGameplayTagRegistry::load_database);
	ClassDB::bind_method(D_METHOD("save_database", "path"), &NativeGameplayTagRegistry::save_database);
	ClassDB::bind_method(D_METHOD("get_tag", "name"), &NativeGameplayTagRegistry::get_tag);
	ClassDB::bind_method(D_METHOD("has_tag", "name"), &NativeGameplayTagRegistry::has_tag);
	ClassDB::bind_method(D_METHOD("add_tag", "name", "description"), &NativeGameplayTagRegistry::add_tag, DEFVAL(String()));
	ClassDB::bind_method(D_METHOD("add_tags", "names"), &NativeGameplayTagRegistry::add_tags);
	ClassDB::bind_method(D_METHOD("remove_tag", "name", "remove_children"), &NativeGameplayTagRegistry::remove_tag, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("remove_tags", "names", "remove_children"), &NativeGameplayTagRegistry::remove_tags, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("get_child_tags", "parent", "recursive"), &NativeGameplayTagRegistry::get_child_tags, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("get_parent_tag", "tag"), &NativeGameplayTagRegistry::get_parent_tag);
	ClassDB::bind_method(D_METHOD("make_container", "initial_tags"), &NativeGameplayTagRegistry::make_container, DEFVAL(Array()));
	ClassDB::bind_method(D_METHOD("make_query_all", "tag_list", "exact"), &NativeGameplayTagRegistry::make_query_all, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("make_query_any", "tag_list", "exact"), &NativeGameplayTagRegistry::make_query_any, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("make_query_none", "tag_list", "exact"), &NativeGameplayTagRegistry::make_query_none, DEFVAL(false));
}

NativeGameplayTagRegistry::NativeGameplayTagRegistry() {
	database.instantiate();
}

void NativeGameplayTagRegistry::set_database(const Ref<NativeGameplayTagDatabase> &p_database) {
	database = p_database;
	if (database.is_null()) {
		database.instantiate();
	}
}

Ref<NativeGameplayTagDatabase> NativeGameplayTagRegistry::get_database() const {
	return database;
}

Error NativeGameplayTagRegistry::load_database(const String &p_path) {
	Ref<Resource> loaded = ResourceLoader::get_singleton()->load(p_path);
	Ref<NativeGameplayTagDatabase> loaded_database = loaded;
	if (loaded_database.is_null()) {
		return ERR_CANT_OPEN;
	}
	database = loaded_database;
	return OK;
}

Error NativeGameplayTagRegistry::save_database(const String &p_path) const {
	if (database.is_null()) {
		return ERR_UNCONFIGURED;
	}
	return ResourceSaver::get_singleton()->save(database, p_path);
}

Ref<NativeGameplayTag> NativeGameplayTagRegistry::get_tag(const Variant &p_name) const {
	return database->get_tag(p_name);
}

bool NativeGameplayTagRegistry::has_tag(const Variant &p_name) const {
	return database->has_tag(p_name);
}

bool NativeGameplayTagRegistry::add_tag(const Variant &p_name, const String &p_description) {
	return database->add_tag(p_name, p_description);
}

int64_t NativeGameplayTagRegistry::add_tags(const Array &p_names) {
	return database->add_tags(p_names);
}

bool NativeGameplayTagRegistry::remove_tag(const Variant &p_name, bool p_remove_children) {
	return database->remove_tag(p_name, p_remove_children);
}

int64_t NativeGameplayTagRegistry::remove_tags(const Array &p_names, bool p_remove_children) {
	return database->remove_tags(p_names, p_remove_children);
}

TypedArray<NativeGameplayTag> NativeGameplayTagRegistry::get_child_tags(const Variant &p_parent, bool p_recursive) const {
	return database->get_child_tags(p_parent, p_recursive);
}

Ref<NativeGameplayTag> NativeGameplayTagRegistry::get_parent_tag(const Variant &p_tag) const {
	return database->get_parent_tag(p_tag);
}

Ref<NativeGameplayTagContainer> NativeGameplayTagRegistry::make_container(const Array &p_initial_tags) const {
	Ref<NativeGameplayTagContainer> container;
	container.instantiate();
	container->add_tags(p_initial_tags);
	return container;
}

Ref<NativeGameplayTagQuery> NativeGameplayTagRegistry::make_query_all(const Array &p_tag_list, bool p_exact) const {
	return NativeGameplayTagQuery::all(p_tag_list, p_exact);
}

Ref<NativeGameplayTagQuery> NativeGameplayTagRegistry::make_query_any(const Array &p_tag_list, bool p_exact) const {
	return NativeGameplayTagQuery::any(p_tag_list, p_exact);
}

Ref<NativeGameplayTagQuery> NativeGameplayTagRegistry::make_query_none(const Array &p_tag_list, bool p_exact) const {
	return NativeGameplayTagQuery::none(p_tag_list, p_exact);
}
