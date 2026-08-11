extends "res://tests/tag_test_case.gd"

const AUTOLOAD_SETTING: String = "autoload/GameplayTags"
const LocalGameplayTagsScript: Script = preload(
	"res://addons/gameplay_tags/runtime/gameplay_tags.gd"
)
const PluginScript: Script = preload("res://addons/gameplay_tags/plugin.gd")
const TagEditorDock: Script = preload("res://addons/gameplay_tags/editor/tag_editor_dock.gd")
const TagDockIo: Script = preload("res://addons/gameplay_tags/editor/tag_dock_io.gd")


func _suite_name() -> String:
	return "GDSCRIPT_GAMEPLAY_TAGS_EDITOR_TEST"


func _run_tests() -> void:
	run_test("autoload_collision_is_rejected", _test_autoload_collision_is_rejected)
	run_test(
		"csv_import_reports_id_generation_failure",
		_test_csv_import_reports_id_generation_failure,
	)
	run_test("cache_only_resource_is_not_a_conflict", _test_cache_only_resource_is_not_a_conflict)
	run_test("undo_targets_its_own_database", _test_undo_targets_its_own_database)


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


func _test_cache_only_resource_is_not_a_conflict() -> void:
	# Assigning resource_path registers the resource in the cache, which makes
	# ResourceLoader.exists() report true even though nothing was written. A
	# CACHE_MODE_IGNORE load cannot read it back, so without a file check the dock
	# mistook a brand new database for a foreign resource and refused to save it.
	var path: String = "res://test_cache_only_database.tres"
	assert_false(FileAccess.file_exists(path), "Test precondition: the path must not exist on disk")

	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.resource_path = path
	assert_true(
		ResourceLoader.exists(path), "Test precondition: the cache entry should be registered"
	)
	assert_false(
		TagDockIo.database_path_conflicts(path),
		"A cache-only resource has no file to overwrite and must not count as a conflict",
	)


func _test_undo_targets_its_own_database() -> void:
	# An undo action outlives the database it was recorded against. Applying its snapshot
	# to whatever database happens to be bound would silently overwrite the new one.
	var dock: Node = TagEditorDock.new()
	root.add_child(dock)

	var recorded: GameplayTagDatabase = GameplayTagDatabase.new()
	recorded.add_tag(&"Recorded.Tag")
	var current: GameplayTagDatabase = GameplayTagDatabase.new()
	current.add_tag(&"Current.Tag")
	dock.set("_database", current)

	var snapshot: Array[StringName] = [&"Snapshot.Tag"]
	var descriptions: Dictionary[String, String] = {}
	var redirects: Dictionary[StringName, StringName] = {}
	dock.call("_apply_database_state", recorded, snapshot, descriptions, redirects, "restored", &"")

	assert_true(
		recorded.has_tag(&"Snapshot.Tag"),
		"The snapshot should be applied to the database the action recorded",
	)
	assert_false(
		current.has_tag(&"Snapshot.Tag"),
		"The snapshot must not leak into the database the dock currently shows",
	)
	assert_true(current.has_tag(&"Current.Tag"), "The currently bound database should be untouched")

	dock.free()


func _test_csv_import_reports_id_generation_failure() -> void:
	var registry: Node = root.get_node_or_null("GameplayTags")
	var ownsregistry: bool = false
	if registry == null:
		registry = LocalGameplayTagsScript.new()
		registry.name = "GameplayTags"
		root.add_child(registry)
		ownsregistry = true

	var original_database_path: String = registry.get_database_path()
	var original_tag_ids_path: String = str(
		ProjectSettings.get_setting(GameplayTagUtils.TAG_IDS_SETTING, "res://gameplay_tag_ids.gd")
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
	ProjectSettings.set_setting(GameplayTagUtils.TAG_IDS_SETTING, "")

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

	ProjectSettings.set_setting(GameplayTagUtils.TAG_IDS_SETTING, tag_ids_path)
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
	assert_false(
		add_child_button.disabled,
		"Adding a tag should leave it selected so the next action needs no reselection",
	)
	assert_eq(
		String(dock.get("_selected_tag")),
		"CSV.Three",
		"Adding a tag should select the tag that was just created",
	)

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

	paste_input.text = "Ability_jump"
	dock.call("_on_paste_tags_confirmed")
	assert_false(
		registry.get_database().has_tag(&"Ability_jump"),
		"Bulk paste should reject generated constant-name collisions",
	)
	assert_true(
		status_label.text.contains("GameplayTagIds constants would collide"),
		"Bulk paste should explain generated constant-name collisions",
	)
	tag_input.text = "Ability_jump"
	dock.call("_on_add_pressed")
	assert_false(
		registry.get_database().has_tag(&"Ability_jump"),
		"Add should reject generated constant-name collisions",
	)
	assert_true(
		status_label.text.contains("GameplayTagIds constants would collide"),
		"Add should explain generated constant-name collisions",
	)

	dock.call("_rename_tag_with_undo", &"CSV", "Imported.CSV")
	assert_true(registry.get_database().has_tag(&"Imported.CSV.One"))
	assert_false(registry.get_database().has_tag(&"CSV.One"))
	assert_eq(
		registry.get_database().resolve_tag(&"CSV.One"),
		&"Imported.CSV.One",
		"Dock rename should preserve redirects from every retired child tag",
	)
	assert_true(
		registry.get_database().get_redirected_tags().has(&"CSV.One"),
		"Dock rename should expose retired names to the migration workflow",
	)
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
	assert_eq(
		reloaded_database.resolve_tag(&"CSV.One"),
		&"Imported.CSV.One",
		"Dock rename redirects should remain present after reloading from disk",
	)

	var conflicting_database_path: String = "user://gameplay_tags_import_conflict.tres"
	_remove_test_file(conflicting_database_path)
	assert_eq(ResourceSaver.save(Resource.new(), conflicting_database_path), OK)
	var database_failure_csv: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	assert_true(database_failure_csv != null)
	if database_failure_csv != null:
		database_failure_csv.store_string("Database.SaveFailure\n")
		database_failure_csv.close()
	registry.set_database_path(conflicting_database_path)
	registry.set_database(reloaded_database)
	dock.call("_on_import_csv_selected", csv_path)
	assert_true(
		status_label.text.contains("Refusing to overwrite another resource"),
		"A database-resource save failure should keep its accurate status",
	)
	assert_false(
		status_label.text.contains("GameplayTagIds could not be regenerated"),
		"Database save failures must not be mislabeled as generated-ID failures",
	)
	registry.set_database_path(database_path)
	registry.set_database(reloaded_database)
	_remove_test_file(conflicting_database_path)

	var missing_csv_path: String = "user://gameplay_tags_missing_import.csv"
	_remove_test_file(missing_csv_path)
	dock.call("_on_import_csv_selected", missing_csv_path)
	assert_true(
		status_label.text.contains("Could not open CSV"),
		"CSV open failures should not be misreported as an empty import",
	)

	dock.free()
	registry.set_database_path(original_database_path)
	registry.set_database(original_database)
	ProjectSettings.set_setting(GameplayTagUtils.TAG_IDS_SETTING, original_tag_ids_path)
	if ownsregistry:
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
