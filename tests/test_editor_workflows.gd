extends SceneTree

const AUTOLOAD_SETTING: String = "autoload/GameplayTags"
const TAG_IDS_SETTING: String = "gameplay_tags/generated_tag_ids_path"
const GameplayTagsScript: Script = preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")
const PluginScript: Script = preload("res://addons/gameplay_tags/plugin.gd")
const TagEditorDock: Script = preload("res://addons/gameplay_tags/editor/tag_editor_dock.gd")

var _assertion_count: int = 0
var _failed: bool = false


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

	var conflicting_path: String = "*res://conflicting_gameplay_tags.gd"
	ProjectSettings.set_setting(AUTOLOAD_SETTING, conflicting_path)
	assert_true(
		PluginScript._get_autoload_conflict() == conflicting_path,
		"A different autoload using GameplayTags should be detected",
	)
	ProjectSettings.set_setting(AUTOLOAD_SETTING, original_value)


func _test_csv_import_reports_id_generation_failure() -> void:
	var registry: Node = root.get_node_or_null("GameplayTags")
	var owns_registry: bool = false
	if registry == null:
		registry = GameplayTagsScript.new()
		registry.name = "GameplayTags"
		root.add_child(registry)
		owns_registry = true

	var original_database_path: String = registry.get_database_path()
	var original_tag_ids_path: String = str(
		ProjectSettings.get_setting(TAG_IDS_SETTING, "res://gameplay_tag_ids.gd")
	)
	var original_database: GameplayTagDatabase = registry.get_database()
	var database_path: String = "user://gameplay_tags_editor_test_database.tres"
	var csv_path: String = "user://gameplay_tags_editor_test.csv"
	var tag_ids_path: String = "user://gameplay_tags_editor_test_ids.gd"
	_remove_test_file(database_path)
	_remove_test_file(csv_path)
	_remove_test_file(tag_ids_path)

	registry.set_database_path(database_path)
	registry.set_database(GameplayTagDatabase.new())
	ProjectSettings.set_setting(TAG_IDS_SETTING, "")

	var csv_file: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	assert_true(csv_file != null, "Editor CSV fixture should be writable")
	if csv_file != null:
		csv_file.store_string("CSV.One\nCSV.Two\n")
		csv_file.close()

	var dock: Control = TagEditorDock.new()
	root.add_child(dock)
	var status_label: Label = dock.get("_status_label")
	var add_child_button: Button = dock.get("_add_child_button")
	assert_true(add_child_button.disabled, "Add Child should require a selected parent")
	dock.call("_on_add_child_pressed")
	assert_true(
		status_label.text.contains("Select a parent tag first"),
		"Add Child should explain that a parent selection is required",
	)

	dock.call("_on_import_csv_selected", csv_path)
	var status: String = status_label.text
	assert_true(registry.get_database().has_tag(&"CSV.One"))
	assert_true(registry.get_database().has_tag(&"CSV.Two"))
	var tag_tree: Tree = dock.get("_tag_tree")
	var csv_item: TreeItem = _find_tree_item(tag_tree.get_root(), &"CSV")
	var csv_one_item: TreeItem = _find_tree_item(tag_tree.get_root(), &"CSV.One")
	assert_true(csv_item != null, "Parent tags should appear in the dock tree")
	assert_true(
		csv_one_item != null and StringName(csv_one_item.get_parent().get_metadata(0)) == &"CSV",
		"Child tags should be nested beneath their parent tag",
	)
	assert_true(status.contains("Imported 2 tags"), "Successful import count should be preserved")
	assert_true(
		status.contains("GameplayTagIds could not be regenerated"),
		"The generated-ID failure should be reported separately",
	)

	ProjectSettings.set_setting(TAG_IDS_SETTING, tag_ids_path)
	csv_item.select(0)
	dock.call("_on_tree_item_selected")
	assert_false(add_child_button.disabled, "Selecting a tag should enable Add Child")
	dock.call("_on_add_child_pressed")
	var tag_input: LineEdit = dock.get("_tag_input")
	assert_eq(
		tag_input.text,
		"CSV.",
		"Add Child should prefill the selected parent's full path",
	)
	assert_eq(
		tag_input.caret_column,
		tag_input.text.length(),
		"Add Child should place the caret after the parent prefix",
	)
	tag_input.text += "Three"
	var description_input: LineEdit = dock.get("_description_input")
	description_input.text = "Third CSV tag"
	dock.call("_on_add_pressed")
	assert_true(
		registry.get_database().has_tag(&"CSV.Three"),
		"Add Child should create a child beneath the selected parent",
	)
	assert_eq(
		registry.get_database().tag_descriptions.get("CSV.Three", ""),
		"Third CSV tag",
		"Add Child should preserve the normal description workflow",
	)
	assert_true(add_child_button.disabled, "Refreshing after add should clear the parent selection")

	csv_one_item = _find_tree_item(tag_tree.get_root(), &"CSV.One")
	csv_one_item.select(0)
	dock.call("_on_tree_item_selected")
	var edit_description_input: LineEdit = dock.get("_edit_description_input")
	edit_description_input.text = "First CSV tag"
	dock.call("_on_update_description_pressed")
	assert_eq(
		registry.get_database().tag_descriptions.get("CSV.One", ""),
		"First CSV tag",
		"The dock should save edited tag descriptions",
	)
	assert_true(
		status_label.text.contains("Updated description for CSV.One"),
		"The dock should report a successful description update",
	)

	var paste_input: TextEdit = dock.get("_paste_input")
	paste_input.text = "Ability.Jump\nAbility.Run\nCSV.One"
	dock.call("_on_paste_tags_confirmed")
	assert_true(registry.get_database().has_tag(&"Ability.Jump"))
	assert_true(registry.get_database().has_tag(&"Ability.Run"))
	assert_true(
		status_label.text.contains("Added 2 pasted tag(s); 1 already existed"),
		"Bulk paste should report added and existing tags",
	)

	dock.call("_rename_tag_with_undo", &"CSV", "Imported.CSV")
	assert_true(registry.get_database().has_tag(&"Imported.CSV.One"))
	assert_false(registry.get_database().has_tag(&"CSV.One"))
	assert_eq(
		registry.get_database().tag_descriptions.get("Imported.CSV.One", ""),
		"First CSV tag",
		"Dock rename should migrate child descriptions",
	)
	assert_true(
		status_label.text.contains("Renamed CSV to Imported.CSV"),
		"Dock rename should report success",
	)
	var reloaded_database: GameplayTagDatabase = registry.reload_database()
	assert_false(
		reloaded_database.has_tag(&"CSV.One"),
		"The old renamed tag should remain absent after reloading from disk",
	)
	assert_true(
		reloaded_database.has_tag(&"Imported.CSV.One"),
		"The renamed tag should remain present after reloading from disk",
	)

	dock.free()
	registry.set_database_path(original_database_path)
	registry.set_database(original_database)
	ProjectSettings.set_setting(TAG_IDS_SETTING, original_tag_ids_path)
	if owns_registry:
		registry.free()
	_remove_test_file(database_path)
	_remove_test_file(csv_path)
	_remove_test_file(tag_ids_path)


func _remove_test_file(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _find_tree_item(parent: TreeItem, tag: StringName) -> TreeItem:
	var item: TreeItem = parent.get_first_child()
	while item != null:
		if StringName(item.get_metadata(0)) == tag:
			return item
		var nested_item: TreeItem = _find_tree_item(item, tag)
		if nested_item != null:
			return nested_item
		item = item.get_next()
	return null


func assert_true(condition: bool, message: String = "Expected condition to be true") -> void:
	_assertion_count += 1
	if not condition:
		_fail(message)


func assert_false(condition: bool, message: String = "Expected condition to be false") -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String = "Values should match") -> void:
	_assertion_count += 1
	if actual != expected:
		_fail("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
