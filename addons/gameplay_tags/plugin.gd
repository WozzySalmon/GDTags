@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GameplayTags"
const AUTOLOAD_PATH := "res://addons/gameplay_tags/runtime/gameplay_tags.gd"
const DATABASE_SETTING := "gameplay_tags/database_path"
const TAG_IDS_SETTING := "gameplay_tags/generated_tag_ids_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const DEFAULT_TAG_IDS_PATH := "res://gameplay_tag_ids.gd"
# Keep the tag manager out of Godot's Inspector tab stack. DOCK_SLOT_RIGHT_UL
# is where Inspector/Node/History live by default, and adding a plugin dock there
# can steal focus/collapse the visible Inspector area when the addon loads.
const TAG_DOCK_SLOT := DOCK_SLOT_RIGHT_BL
const TAG_DOCK_MINIMUM_SIZE := Vector2(320, 240)
const TagEditorDock := preload("res://addons/gameplay_tags/editor/tag_editor_dock.gd")
const TagCodeGenerator := preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_code_generator.gd"
)
const TagInspectorPlugin := preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_inspector_plugin.gd"
)

var _dock: Control
var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	_ensure_project_settings()
	_ensure_autoload()
	_ensure_database_resource()
	_ensure_tag_ids_script()

	_inspector_plugin = TagInspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)

	_dock = TagEditorDock.new()
	_dock.name = "Gameplay Tags"
	_dock.set("undo_redo_manager", get_undo_redo())
	_dock.custom_minimum_size = TAG_DOCK_MINIMUM_SIZE
	add_control_to_dock(TAG_DOCK_SLOT, _dock)


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _enable_plugin() -> void:
	_ensure_project_settings()
	_ensure_autoload()
	_ensure_database_resource()
	_ensure_tag_ids_script()


func _disable_plugin() -> void:
	_remove_own_autoload()


func _ensure_project_settings() -> void:
	if not ProjectSettings.has_setting(DATABASE_SETTING):
		ProjectSettings.set_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH)
	ProjectSettings.set_initial_value(DATABASE_SETTING, DEFAULT_DATABASE_PATH)

	if not ProjectSettings.has_setting(TAG_IDS_SETTING):
		ProjectSettings.set_setting(TAG_IDS_SETTING, DEFAULT_TAG_IDS_PATH)
	ProjectSettings.set_initial_value(TAG_IDS_SETTING, DEFAULT_TAG_IDS_PATH)


func _ensure_autoload() -> void:
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _ensure_database_resource() -> void:
	var path := String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))
	if ResourceLoader.exists(path):
		if not load(path) is GameplayTagDatabase:
			push_error("Refusing to overwrite a non-GameplayTagDatabase resource at: %s" % path)
		return
	var directory_error := _ensure_database_directory(path)
	if directory_error != OK:
		push_error(
			"Could not create gameplay tag database directory: %s" % error_string(directory_error)
		)
		return
	var database := GameplayTagDatabase.new()
	database.resource_path = path
	var save_error := ResourceSaver.save(database, path)
	if save_error != OK:
		push_error("Could not create gameplay tag database: %s" % error_string(save_error))


func _ensure_tag_ids_script() -> void:
	var database := _load_database_for_generation()
	if database == null:
		return
	var output_path := String(ProjectSettings.get_setting(TAG_IDS_SETTING, DEFAULT_TAG_IDS_PATH))
	var save_error := TagCodeGenerator.save_tag_ids(database, output_path)
	if save_error != OK:
		push_error("Could not generate gameplay tag IDs: %s" % error_string(save_error))


func _load_database_for_generation() -> GameplayTagDatabase:
	var database_path := String(
		ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH)
	)
	if ResourceLoader.exists(database_path):
		var existing_resource := load(database_path)
		if existing_resource is GameplayTagDatabase:
			return existing_resource
		push_error(
			"Expected a GameplayTagDatabase but found another resource at: %s" % database_path
		)
		return null
	return GameplayTagDatabase.new()


func _ensure_database_directory(path: String) -> Error:
	var directory := path.get_base_dir()
	if directory.is_empty() or directory == "res://" or directory == "user://":
		return OK
	return DirAccess.make_dir_recursive_absolute(directory)


func _remove_own_autoload() -> void:
	var setting_name := "autoload/%s" % AUTOLOAD_NAME
	if not ProjectSettings.has_setting(setting_name):
		return

	var value := String(ProjectSettings.get_setting(setting_name))
	if _autoload_points_to_own_script(value):
		remove_autoload_singleton(AUTOLOAD_NAME)


func _autoload_points_to_own_script(value: String) -> bool:
	var autoload_path := value.trim_prefix("*").strip_edges()
	if autoload_path == AUTOLOAD_PATH:
		return true

	if autoload_path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(autoload_path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid) == AUTOLOAD_PATH

	return false
