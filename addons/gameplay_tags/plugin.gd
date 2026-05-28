@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GameplayTags"
const AUTOLOAD_PATH := "res://addons/gameplay_tags/runtime/gameplay_tags.gd"
const DATABASE_SETTING := "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const TagEditorDock := preload("res://addons/gameplay_tags/editor/tag_editor_dock.gd")

var _dock: Control

func _enter_tree() -> void:
	_ensure_project_settings()
	_ensure_autoload()

	_dock = TagEditorDock.new()
	_dock.name = "Gameplay Tags"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

	_remove_own_autoload()

func _ensure_project_settings() -> void:
	if not ProjectSettings.has_setting(DATABASE_SETTING):
		ProjectSettings.set_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH)
		ProjectSettings.set_initial_value(DATABASE_SETTING, DEFAULT_DATABASE_PATH)
		ProjectSettings.save()

func _ensure_autoload() -> void:
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _remove_own_autoload() -> void:
	var setting_name := "autoload/%s" % AUTOLOAD_NAME
	if not ProjectSettings.has_setting(setting_name):
		return

	var value := String(ProjectSettings.get_setting(setting_name))
	if _autoload_points_to_own_script(value):
		remove_autoload_singleton(AUTOLOAD_NAME)

func _autoload_points_to_own_script(value: String) -> bool:
	var autoload_path := value.trim_prefix("*")
	if autoload_path == AUTOLOAD_PATH or autoload_path.contains(AUTOLOAD_PATH):
		return true

	if autoload_path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(autoload_path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid) == AUTOLOAD_PATH

	return false
