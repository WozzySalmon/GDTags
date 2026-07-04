@tool
extends Node

const DATABASE_SETTING := "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const EXTENSION_PATH := "res://addons/gameplay_tags/gameplay_tags.gdextension"
const GameplayTagDatabaseScript := preload(
	"res://addons/gameplay_tags/resources/gameplay_tag_database.gd"
)

# Source-of-truth/editor database. This remains GDScript so the editor dock can
# keep saving a normal Godot resource that works even without a native build.
var database: GameplayTagDatabase

# Optional fast runtime mirror. These stay untyped so the script can still parse
# and run on machines where the GDExtension has not been built/loaded yet.
var _native_registry: Variant = null
var _native_database: Variant = null
var _native_runtime_enabled := false
var _native_load_error: int = OK


func _ready() -> void:
	reload()


func reload() -> GameplayTagDatabase:
	_ensure_project_settings()
	database = null
	var path := get_database_path()

	if ResourceLoader.exists(path):
		database = load(path) as GameplayTagDatabase

	if database == null:
		database = GameplayTagDatabaseScript.new()
		_seed_default_tags(database)
		save_database()

	_setup_native_runtime()
	return database


func get_database() -> GameplayTagDatabase:
	if database == null:
		reload()
	return database


func is_native_runtime_enabled() -> bool:
	return _native_runtime_enabled and _native_registry != null


func get_runtime_backend() -> String:
	return "native" if is_native_runtime_enabled() else "gdscript"


func get_native_registry() -> Variant:
	return _native_registry


func get_native_database() -> Variant:
	return _native_database


func get_native_load_error() -> int:
	return _native_load_error


func get_database_path() -> String:
	return String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))


func set_database_path(path: String) -> void:
	ProjectSettings.set_setting(DATABASE_SETTING, path)
	ProjectSettings.save()
	reload()


func save_database() -> Error:
	if database == null:
		return ERR_UNCONFIGURED
	return ResourceSaver.save(database, get_database_path())


func get_tag(name: Variant) -> Variant:
	if is_native_runtime_enabled():
		return _native_registry.get_tag(name)
	return get_database().get_tag(name)


func has_tag(name: Variant) -> bool:
	if is_native_runtime_enabled():
		return _native_registry.has_tag(name)
	return get_database().has_tag(name)


func add_tag(name: Variant, description: String = "") -> bool:
	var added := get_database().add_tag(name, description)
	if added:
		save_database()
		_sync_native_runtime()
	return added


func add_tags(names: Array) -> int:
	var added := get_database().add_tags(names)
	if added > 0:
		save_database()
		_sync_native_runtime()
	return added


func remove_tag(name: Variant, remove_children: bool = false) -> bool:
	var removed := get_database().remove_tag(name, remove_children)
	if removed:
		save_database()
		_sync_native_runtime()
	return removed


func remove_tags(names: Array, remove_children: bool = false) -> int:
	var removed := get_database().remove_tags(names, remove_children)
	if removed > 0:
		save_database()
		_sync_native_runtime()
	return removed


func ensure_parent_tags() -> bool:
	var changed := get_database().ensure_parent_tags()
	if changed:
		save_database()
		_sync_native_runtime()
	return changed


func get_child_tags(parent: Variant, recursive: bool = false) -> Array:
	if is_native_runtime_enabled():
		return _native_registry.get_child_tags(parent, recursive)
	return get_database().get_children(parent, recursive)


func get_parent_tag(tag: Variant) -> Variant:
	if is_native_runtime_enabled():
		return _native_registry.get_parent_tag(tag)
	return get_database().get_parent(tag)


func get_all_tags() -> Array:
	if is_native_runtime_enabled() and _native_database != null:
		return _native_database.get_all_tags()
	return get_database().get_all_tags()


func make_container(initial_tags: Array = []) -> Variant:
	if is_native_runtime_enabled():
		return _native_registry.make_container(initial_tags)

	var container := GameplayTagContainer.new()
	for tag in initial_tags:
		container.add(tag)
	return container


func make_query_all(tag_list: Array, exact: bool = false) -> Variant:
	if is_native_runtime_enabled():
		return _native_registry.make_query_all(tag_list, exact)
	return GameplayTagQuery.all(tag_list, exact)


func make_query_any(tag_list: Array, exact: bool = false) -> Variant:
	if is_native_runtime_enabled():
		return _native_registry.make_query_any(tag_list, exact)
	return GameplayTagQuery.any(tag_list, exact)


func make_query_none(tag_list: Array, exact: bool = false) -> Variant:
	if is_native_runtime_enabled():
		return _native_registry.make_query_none(tag_list, exact)
	return GameplayTagQuery.none(tag_list, exact)


func make_query_exact_all(tag_list: Array) -> Variant:
	return make_query_all(tag_list, true)


func _setup_native_runtime() -> void:
	_native_registry = null
	_native_database = null
	_native_runtime_enabled = false

	if not _load_native_extension():
		return

	_native_registry = ClassDB.instantiate("NativeGameplayTagRegistry")
	if _native_registry == null:
		return

	_sync_native_runtime()


func _load_native_extension() -> bool:
	if (
		ClassDB.class_exists("NativeGameplayTagRegistry")
		and ClassDB.class_exists("NativeGameplayTagDatabase")
	):
		_native_load_error = OK
		return true

	if not ResourceLoader.exists(EXTENSION_PATH):
		_native_load_error = ERR_FILE_NOT_FOUND
		return false

	_native_load_error = int(GDExtensionManager.load_extension(EXTENSION_PATH))
	return (
		_native_load_error == OK
		and ClassDB.class_exists("NativeGameplayTagRegistry")
		and ClassDB.class_exists("NativeGameplayTagDatabase")
	)


func _sync_native_runtime() -> void:
	_native_runtime_enabled = false
	_native_database = null

	if _native_registry == null or database == null:
		return

	_native_database = ClassDB.instantiate("NativeGameplayTagDatabase")
	if _native_database == null:
		return

	_native_database.set_tags(database.tags)
	_native_database.set_tag_descriptions(database.tag_descriptions)
	_native_registry.set_database(_native_database)
	_native_runtime_enabled = true


func _ensure_project_settings() -> void:
	if ProjectSettings.has_setting(DATABASE_SETTING):
		return

	# Register the default for this run without rewriting project.godot.
	# set_database_path() is the explicit path-changing API that saves this setting.
	ProjectSettings.set_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH)
	ProjectSettings.set_initial_value(DATABASE_SETTING, DEFAULT_DATABASE_PATH)


func _seed_default_tags(target: GameplayTagDatabase) -> void:
	if not target.tags.is_empty():
		return

	for tag in [
		"Ability",
		"Ability.Cooldown",
		"Damage",
		"Damage.Fire",
		"Damage.Ice",
		"State",
		"State.Invulnerable",
		"State.Stunned",
		"Team",
		"Team.Enemy",
		"Team.Player",
	]:
		target.add_tag(tag)
