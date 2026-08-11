extends "res://tests/tag_test_case.gd"

const TagProperty: Script = preload("res://addons/gameplay_tags/editor/gameplay_tag_property.gd")
const TagArrayProperty: Script = preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_array_property.gd"
)
const TagEditorDock: Script = preload("res://addons/gameplay_tags/editor/tag_editor_dock.gd")
const TagInspectorPlugin: Script = preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_inspector_plugin.gd"
)


class TagSelectionTarget:
	extends RefCounted

	var tag: StringName = &""
	var tag_resource: GameplayTag
	var tags: Array[StringName] = []


var _picker_change_count: int = 0
var _picker_changed_property: StringName = &""
# EditorProperty.property_changed carries different property value types.
var _picker_changed_value: Variant
var _picker_target: Object
var _active_picker: EditorProperty


func _suite_name() -> String:
	return "GDSCRIPT_GAMEPLAY_TAGS_PICKER_TEST"


func _make_test_database() -> GameplayTagDatabase:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tag(&"State.Stunned")
	return database


func _run_tests() -> void:
	run_test("tag_creation_undo_redo", _test_tag_creation_undo_redo)
	run_test("single_picker_selection", _test_single_picker_selection)
	run_test("resource_picker_selection", _test_resource_picker_selection)
	run_test("array_picker_selection", _test_array_picker_selection)
	run_test("inspector_plugin_detects_tag_properties", _test_inspector_plugin_detection)


func _test_single_picker_selection() -> void:
	var target: TagSelectionTarget = TagSelectionTarget.new()
	var picker: EditorProperty = TagProperty.new()
	root.add_child(picker)
	picker.set_object_and_property(target, &"tag")
	_reset_picker_change(target, picker)
	picker.property_changed.connect(_on_picker_property_changed)
	picker.call("_update_property")

	var tree: Tree = picker.get("_tag_tree")
	var original_root: TreeItem = tree.get_root()
	var item: TreeItem = _find_tree_item(original_root, &"State.Stunned")
	assert_true(item != null, "Single-tag picker should contain the test tag")
	if item != null:
		tree.set_block_signals(true)
		item.select(0)
		tree.set_block_signals(false)
		picker.call("_on_tree_item_selected")
		assert_eq(_picker_change_count, 1, "Single-tag picker should emit one property change")
		assert_eq(_picker_changed_property, &"tag")
		assert_eq(
			_picker_changed_value,
			&"State.Stunned",
			"Single-tag picker should emit the selected tag",
		)
		assert_eq(
			target.tag,
			&"State.Stunned",
			"Inspector-style write-back should update the edited object",
		)
		assert_true(
			tree.get_root() == original_root,
			"Synchronous Inspector write-back must not rebuild the Tree re-entrantly",
		)

	picker.call("_on_clear_pressed")
	assert_eq(target.tag, &"", "Clear should write an empty tag to the edited object")
	assert_eq(_picker_change_count, 2, "Clear should emit one additional property change")
	picker.call("_set_read_only", true)
	if item != null:
		item.select(0)
		picker.call("_on_tree_item_selected")
	assert_eq(_picker_change_count, 2, "Read-only pickers must ignore selections")
	var summary_button: Button = picker.get("_summary_button")
	var clear_button: Button = picker.get("_clear_button")
	assert_true(summary_button.disabled and clear_button.disabled)
	picker.free()


func _test_resource_picker_selection() -> void:
	var target: TagSelectionTarget = TagSelectionTarget.new()
	var picker: EditorProperty = TagProperty.new()
	picker.set("value_mode", TagProperty.VALUE_RESOURCE)
	root.add_child(picker)
	picker.set_object_and_property(target, &"tag_resource")
	_reset_picker_change(target, picker)
	picker.property_changed.connect(_on_picker_property_changed)
	picker.call("_update_property")

	var tree: Tree = picker.get("_tag_tree")
	var item: TreeItem = _find_tree_item(tree.get_root(), &"State.Stunned")
	assert_true(item != null, "Resource picker should contain the test tag")
	if item != null:
		tree.set_block_signals(true)
		item.select(0)
		tree.set_block_signals(false)
		picker.call("_on_tree_item_selected")
	assert_true(_picker_changed_value is GameplayTag)
	assert_true(target.tag_resource != null)
	if target.tag_resource != null:
		assert_eq(target.tag_resource.tag_name, &"State.Stunned")
	picker.call("_on_clear_pressed")
	assert_true(target.tag_resource == null, "Clear should write null in resource mode")
	picker.free()


func _test_array_picker_selection() -> void:
	var target: TagSelectionTarget = TagSelectionTarget.new()
	var picker: EditorProperty = TagArrayProperty.new()
	root.add_child(picker)
	picker.set_object_and_property(target, &"tags")
	_reset_picker_change(target, picker)
	picker.property_changed.connect(_on_picker_property_changed)
	picker.call("_update_property")

	var tree: Tree = picker.get("_tag_tree")
	var original_root: TreeItem = tree.get_root()
	var item: TreeItem = _find_tree_item(original_root, &"State.Stunned")
	assert_true(item != null, "Array-tag picker should contain the test tag")
	if item != null:
		picker.call("_on_tag_multi_selected", item, 0, true)
		assert_eq(_picker_change_count, 1, "Array picker should emit one selection change")
		assert_eq(_picker_changed_property, &"tags")
		assert_eq(
			_picker_changed_value,
			[&"State.Stunned"],
			"Array picker should emit the selected tag array",
		)
		assert_eq(
			target.tags,
			[&"State.Stunned"],
			"Inspector-style array write-back should update the edited object",
		)
		picker.call("_on_tag_multi_selected", item, 0, false)
		assert_eq(_picker_change_count, 2, "Array picker should emit deselection changes")
		assert_eq(
			_picker_changed_value,
			[],
			"Array picker should emit an empty array after deselection",
		)
		assert_true(
			tree.get_root() == original_root,
			"Synchronous array write-back must not rebuild its Tree re-entrantly",
		)
	picker.free()


func _test_inspector_plugin_detection() -> void:
	var inspector_plugin: EditorInspectorPlugin = TagInspectorPlugin.new()
	var component: GameplayTagComponent = GameplayTagComponent.new()
	var container: GameplayTagContainer = GameplayTagContainer.new()
	var query: GameplayTagQuery = GameplayTagQuery.new()
	var tag: GameplayTag = GameplayTag.new(&"State.Stunned")
	var unrelated: RefCounted = RefCounted.new()

	assert_true(inspector_plugin.call("_can_handle", component))
	assert_true(inspector_plugin.call("_can_handle", container))
	assert_true(inspector_plugin.call("_can_handle", query))
	assert_true(inspector_plugin.call("_can_handle", tag))
	assert_false(inspector_plugin.call("_can_handle", unrelated))
	assert_true(
		inspector_plugin.call("_is_supported_tag_property_name", component, "owned_tags"),
		"Components should use the array gameplay-tag picker for owned_tags",
	)
	assert_false(
		inspector_plugin.call("_is_supported_tag_property_name", component, "tags"),
		"Components should not claim unrelated property names",
	)
	assert_true(
		inspector_plugin.call("_hint_includes_gameplay_tag", "Resource, GameplayTag"),
		"Resource hints containing GameplayTag should use the single-tag picker",
	)
	assert_false(inspector_plugin.call("_hint_includes_gameplay_tag", "Resource, Texture2D"))

	var name_editor: EditorProperty = (
		inspector_plugin
		. call(
			"_create_property_editor",
			tag,
			TYPE_STRING_NAME,
			"tag_name",
			PROPERTY_HINT_NONE,
			"",
		)
	)
	assert_true(name_editor != null, "GameplayTag.tag_name should create a picker")
	assert_eq(name_editor.get("value_mode"), TagProperty.VALUE_STRING_NAME)
	var resource_editor: EditorProperty = (
		inspector_plugin
		. call(
			"_create_property_editor",
			unrelated,
			TYPE_OBJECT,
			"tag_resource",
			PROPERTY_HINT_RESOURCE_TYPE,
			"GameplayTag",
		)
	)
	assert_true(resource_editor != null, "GameplayTag resources should create a picker")
	assert_eq(resource_editor.get("value_mode"), TagProperty.VALUE_RESOURCE)
	var array_editor: EditorProperty = (
		inspector_plugin
		. call(
			"_create_property_editor",
			component,
			TYPE_ARRAY,
			"owned_tags",
			PROPERTY_HINT_NONE,
			"",
		)
	)
	assert_true(array_editor != null, "Component owned_tags should create an array picker")
	assert_true(
		(
			(
				inspector_plugin
				. call(
					"_create_property_editor",
					unrelated,
					TYPE_STRING,
					"name",
					PROPERTY_HINT_NONE,
					"",
				)
			)
			== null
		),
		"Unrelated properties should keep the default Inspector editor",
	)
	name_editor.free()
	resource_editor.free()
	array_editor.free()
	component.free()


func _reset_picker_change(target: Object, picker: EditorProperty) -> void:
	_picker_change_count = 0
	_picker_changed_property = &""
	_picker_changed_value = null
	_picker_target = target
	_active_picker = picker


func _on_picker_property_changed(
	property: StringName,
	value: Variant,
	_field_name: StringName,
	_changing: bool,
) -> void:
	_picker_change_count += 1
	_picker_changed_property = property
	_picker_changed_value = value
	if _picker_target != null:
		_picker_target.set(property, value)
	if _active_picker != null:
		# Real EditorInspector write-back requests an update immediately. Calling it
		# synchronously proves the picker's _updating guard prevents re-entrancy.
		_active_picker.call("_update_property")


func _test_tag_creation_undo_redo() -> void:
	var original_database_path: Variant = ProjectSettings.get_setting(
		GameplayTagUtils.DATABASE_SETTING
	)
	var original_tag_ids_path: Variant = ProjectSettings.get_setting(
		GameplayTagUtils.TAG_IDS_SETTING
	)
	var original_database: GameplayTagDatabase = registry.get_database()
	var database_path: String = "user://gameplay_tags_undo_test_database.tres"
	var tag_ids_path: String = "user://gameplay_tags_undo_test_ids.gd"
	var csv_path: String = "user://gameplay_tags_undo_test.csv"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(database_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tag_ids_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path))
	ProjectSettings.set_setting(GameplayTagUtils.DATABASE_SETTING, database_path)
	ProjectSettings.set_setting(GameplayTagUtils.TAG_IDS_SETTING, tag_ids_path)

	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tag(&"State.Stunned")
	registry.set_database(database)
	var undo_redo_manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	assert_true(undo_redo_manager != null, "Editor undo manager should be available")
	if undo_redo_manager == null:
		return
	undo_redo_manager.clear_history()

	var dock: Control = TagEditorDock.new()
	dock.set("undo_redo_manager", undo_redo_manager)
	root.add_child(dock)
	var tag_input: LineEdit = dock.get("_tag_input")
	var description_input: LineEdit = dock.get("_description_input")
	tag_input.text = "Editor.Undoable"
	description_input.text = "Undoable editor tag"
	dock.call("_on_add_pressed")

	assert_true(database.has_tag(&"Editor.Undoable"), "Dock add should apply its do action")
	var history_id: int = undo_redo_manager.get_object_history_id(database)
	var history: UndoRedo = undo_redo_manager.get_history_undo_redo(history_id)
	assert_true(history != null and history.has_undo(), "Dock add should create an undo action")
	if history != null:
		assert_true(history.undo(), "Dock add action should be undoable")
		assert_true(
			not database.has_tag(&"Editor.Undoable"),
			"Undo should remove the newly added tag and parent",
		)
		assert_true(history.redo(), "Dock add action should be redoable")
		assert_true(database.has_tag(&"Editor.Undoable"), "Redo should restore the added tag")
		assert_eq(
			database.tag_descriptions.get("Editor.Undoable", ""),
			"Undoable editor tag",
			"Redo should restore the added tag description",
		)

		dock.call("_rename_tag_with_undo", &"Editor.Undoable", "Editor.Renamed")
		assert_eq(
			database.resolve_tag(&"Editor.Undoable"),
			&"Editor.Renamed",
			"Dock rename should apply its redirect through the undo state",
		)
		assert_true(history.undo(), "Dock rename action should be undoable")
		assert_true(database.has_tag(&"Editor.Undoable"))
		assert_eq(
			database.resolve_tag(&"Editor.Undoable"),
			&"Editor.Undoable",
			"Undoing a dock rename should restore the previous redirect state",
		)
		assert_true(history.redo(), "Dock rename action should be redoable")
		assert_eq(database.resolve_tag(&"Editor.Undoable"), &"Editor.Renamed")

	undo_redo_manager.clear_history(history_id)
	var paste_input: TextEdit = dock.get("_paste_input")
	paste_input.text = "Bulk.Pasted\nBulk.Other"
	dock.call("_on_paste_tags_confirmed")
	assert_true(database.has_tag(&"Bulk.Pasted"))
	history = undo_redo_manager.get_history_undo_redo(history_id)
	assert_true(history != null and history.undo(), "Bulk paste should be undoable")
	assert_false(database.has_tag(&"Bulk.Pasted"))

	undo_redo_manager.clear_history(history_id)
	var csv_file: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	assert_true(csv_file != null, "Undoable CSV fixture should be writable")
	if csv_file != null:
		csv_file.store_string("Imported.Undoable\n")
		csv_file.close()
		dock.call("_on_import_csv_selected", csv_path)
		assert_true(database.has_tag(&"Imported.Undoable"))
		history = undo_redo_manager.get_history_undo_redo(history_id)
		assert_true(history != null and history.undo(), "CSV import should be undoable")
		assert_false(database.has_tag(&"Imported.Undoable"))

	undo_redo_manager.clear_history(history_id)
	dock.free()
	registry.set_database(original_database)
	ProjectSettings.set_setting(GameplayTagUtils.DATABASE_SETTING, original_database_path)
	ProjectSettings.set_setting(GameplayTagUtils.TAG_IDS_SETTING, original_tag_ids_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(database_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tag_ids_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path))


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
