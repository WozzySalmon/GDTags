extends SceneTree

const AUTOLOAD_SETTING := "autoload/GameplayTags"
const TAG_IDS_SETTING := "gameplay_tags/generated_tag_ids_path"
const GameplayTagsScript := preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")
const PluginScript := preload("res://addons/gameplay_tags/plugin.gd")
const TagEditorDock := preload("res://addons/gameplay_tags/editor/tag_editor_dock.gd")

var _assertion_count := 0
var _failed := false


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	_test_autoload_collision_is_rejected()
	_test_csv_import_reports_id_generation_failure()
	if not _failed:
		print("GDSCRIPT_GAMEPLAY_TAGS_EDITOR_TEST passed (%d assertions)" % _assertion_count)
		quit(0)


func _test_autoload_collision_is_rejected() -> void:
	var original_value: Variant = ProjectSettings.get_setting(AUTOLOAD_SETTING)
	assert_true(
		PluginScript._get_autoload_conflict().is_empty(),
		"The addon's own autoload should not be reported as a conflict",
	)

	var conflicting_path := "*res://conflicting_gameplay_tags.gd"
	ProjectSettings.set_setting(AUTOLOAD_SETTING, conflicting_path)
	assert_true(
		PluginScript._get_autoload_conflict() == conflicting_path,
		"A different autoload using GameplayTags should be detected",
	)
	ProjectSettings.set_setting(AUTOLOAD_SETTING, original_value)


func _test_csv_import_reports_id_generation_failure() -> void:
	var registry := root.get_node_or_null("GameplayTags")
	var owns_registry := false
	if registry == null:
		registry = GameplayTagsScript.new()
		registry.name = "GameplayTags"
		root.add_child(registry)
		owns_registry = true

	var original_database_path: String = registry.get_database_path()
	var original_tag_ids_path := str(
		ProjectSettings.get_setting(TAG_IDS_SETTING, "res://gameplay_tag_ids.gd")
	)
	var original_database: GameplayTagDatabase = registry.get_database()
	var database_path := "user://gameplay_tags_editor_test_database.tres"
	var csv_path := "user://gameplay_tags_editor_test.csv"
	_remove_test_file(database_path)
	_remove_test_file(csv_path)

	registry.set_database_path(database_path)
	registry.set_database(GameplayTagDatabase.new())
	ProjectSettings.set_setting(TAG_IDS_SETTING, "")

	var csv_file := FileAccess.open(csv_path, FileAccess.WRITE)
	assert_true(csv_file != null, "Editor CSV fixture should be writable")
	if csv_file != null:
		csv_file.store_string("CSV.One\nCSV.Two\n")
		csv_file.close()

	var dock := TagEditorDock.new()
	root.add_child(dock)
	dock.call("_on_import_csv_selected", csv_path)
	var status_label: Label = dock.get("_status_label")
	var status := status_label.text
	assert_true(registry.get_database().has_tag(&"CSV.One"))
	assert_true(registry.get_database().has_tag(&"CSV.Two"))
	assert_true(status.contains("Imported 2 tags"), "Successful import count should be preserved")
	assert_true(
		status.contains("GameplayTagIds could not be regenerated"),
		"The generated-ID failure should be reported separately",
	)

	dock.free()
	registry.set_database_path(original_database_path)
	registry.set_database(original_database)
	ProjectSettings.set_setting(TAG_IDS_SETTING, original_tag_ids_path)
	if owns_registry:
		registry.free()
	_remove_test_file(database_path)
	_remove_test_file(csv_path)


func _remove_test_file(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func assert_true(condition: bool, message: String = "Expected condition to be true") -> void:
	_assertion_count += 1
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
