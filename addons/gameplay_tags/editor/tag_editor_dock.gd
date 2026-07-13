@tool
extends VBoxContainer

enum ToolsAction {
	REFRESH,
	REGENERATE_IDS,
	PASTE_TAGS,
	IMPORT_CSV,
	EXPORT_CSV,
}

const DATABASE_SETTING: String = "gameplay_tags/database_path"
const TAG_IDS_SETTING: String = "gameplay_tags/generated_tag_ids_path"
const DEFAULT_DATABASE_PATH: String = "res://gameplay_tags_database.tres"
const DEFAULT_TAG_IDS_PATH: String = "res://gameplay_tag_ids.gd"
const TagCodeGenerator: Script = preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_code_generator.gd"
)

var undo_redo_manager: EditorUndoRedoManager

var _database: GameplayTagDatabase
var _tag_tree: Tree
var _search_input: LineEdit
var _tag_input: LineEdit
var _description_input: LineEdit
var _details_container: VBoxContainer
var _selected_tag_label: Label
var _edit_description_input: LineEdit
var _update_description_button: Button
var _status_label: Label
var _rename_button: Button
var _remove_button: Button
var _rename_dialog: ConfirmationDialog
var _rename_input: LineEdit
var _paste_dialog: ConfirmationDialog
var _paste_input: TextEdit
var _import_dialog: FileDialog
var _export_dialog: FileDialog
var _remove_confirmation: ConfirmationDialog
var _selected_tag: StringName = &""
var _pending_remove_tag: StringName = &""
var _tree_items_by_tag: Dictionary[StringName, TreeItem] = {}


func _ready() -> void:
	_build_ui()
	_load_database()
	_refresh()


func _build_ui() -> void:
	add_theme_constant_override("separation", 8)

	var title: Label = Label.new()
	title.text = "Gameplay Tags"
	if has_theme_font("bold", "EditorFonts"):
		title.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))
	if has_theme_font_size("title_size", "EditorFonts"):
		(
			title
			. add_theme_font_size_override(
				"font_size",
				get_theme_font_size("title_size", "EditorFonts"),
			)
		)
	add_child(title)

	var path_label: Label = Label.new()
	path_label.text = _get_database_path()
	path_label.tooltip_text = (
		"Gameplay Tags database: %s\nGenerated code constants: %s"
		% [_get_database_path(), _get_tag_ids_path()]
	)
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_label.modulate.a = 0.7
	add_child(path_label)

	var tags_heading: Label = Label.new()
	tags_heading.text = "Tags"
	add_child(tags_heading)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search tags"
	_search_input.clear_button_enabled = true
	_search_input.tooltip_text = "Filter tags by name or description"
	_search_input.text_changed.connect(_on_search_changed)
	add_child(_search_input)

	_tag_tree = Tree.new()
	_tag_tree.hide_root = true
	_tag_tree.columns = 1
	_tag_tree.select_mode = Tree.SELECT_SINGLE
	_tag_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tag_tree.tooltip_text = "Select a tag to view its description or remove it"
	_tag_tree.item_selected.connect(_on_tree_item_selected)
	add_child(_tag_tree)

	_details_container = VBoxContainer.new()
	_details_container.add_theme_constant_override("separation", 6)
	_details_container.visible = false
	add_child(_details_container)

	_details_container.add_child(HSeparator.new())

	var details_heading: Label = Label.new()
	details_heading.text = "Selected tag"
	_details_container.add_child(details_heading)

	_selected_tag_label = Label.new()
	_selected_tag_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_selected_tag_label.modulate.a = 0.75
	_details_container.add_child(_selected_tag_label)

	_edit_description_input = LineEdit.new()
	_edit_description_input.placeholder_text = "Optional description"
	_edit_description_input.clear_button_enabled = true
	_edit_description_input.text_changed.connect(_on_edit_description_changed)
	_edit_description_input.text_submitted.connect(_on_description_submitted)
	_details_container.add_child(_edit_description_input)

	var details_buttons: HBoxContainer = HBoxContainer.new()
	details_buttons.add_theme_constant_override("separation", 6)
	_details_container.add_child(details_buttons)

	_update_description_button = Button.new()
	_update_description_button.text = "Update Description"
	_update_description_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_description_button.tooltip_text = "Save the selected tag's description"
	_update_description_button.pressed.connect(_on_update_description_pressed)
	details_buttons.add_child(_update_description_button)

	_rename_button = Button.new()
	_rename_button.text = "Rename"
	_rename_button.disabled = true
	_rename_button.tooltip_text = "Rename or move the selected tag and its child tags"
	_apply_editor_icon(_rename_button, &"Rename")
	_rename_button.pressed.connect(_on_rename_pressed)
	details_buttons.add_child(_rename_button)

	_remove_button = Button.new()
	_remove_button.text = "Remove"
	_remove_button.disabled = true
	_remove_button.tooltip_text = "Remove the selected tag and its child tags"
	_apply_editor_icon(_remove_button, &"Remove")
	_remove_button.pressed.connect(_on_remove_pressed)
	details_buttons.add_child(_remove_button)

	add_child(HSeparator.new())

	var add_heading: Label = Label.new()
	add_heading.text = "Add a tag"
	add_child(add_heading)

	_tag_input = LineEdit.new()
	_tag_input.placeholder_text = "Tag name, for example State.Stunned"
	_tag_input.clear_button_enabled = true
	_tag_input.tooltip_text = "Use dots to create a tag hierarchy"
	_tag_input.text_submitted.connect(_on_tag_submitted)
	add_child(_tag_input)

	_description_input = LineEdit.new()
	_description_input.placeholder_text = "Optional description"
	_description_input.clear_button_enabled = true
	_description_input.text_submitted.connect(_on_tag_submitted)
	add_child(_description_input)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	add_child(buttons)

	var add_button: Button = Button.new()
	add_button.text = "Add Tag"
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.tooltip_text = "Add the tag and any missing parent tags"
	_apply_editor_icon(add_button, &"Add")
	add_button.pressed.connect(_on_add_pressed)
	buttons.add_child(add_button)

	var tools_button: MenuButton = MenuButton.new()
	tools_button.text = "Tools"
	tools_button.tooltip_text = "Database maintenance, import, and export actions"
	_apply_editor_icon(tools_button, &"Tools")
	buttons.add_child(tools_button)

	var tools_menu: PopupMenu = tools_button.get_popup()
	tools_menu.add_item("Refresh", ToolsAction.REFRESH)
	tools_menu.add_item("Regenerate IDs", ToolsAction.REGENERATE_IDS)
	tools_menu.add_separator()
	tools_menu.add_item("Paste Tags…", ToolsAction.PASTE_TAGS)
	tools_menu.add_item("Import CSV", ToolsAction.IMPORT_CSV)
	tools_menu.add_item("Export CSV", ToolsAction.EXPORT_CSV)
	tools_menu.id_pressed.connect(_on_tools_menu_id_pressed)

	_build_file_dialogs()

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate.a = 0.85
	add_child(_status_label)


func _build_file_dialogs() -> void:
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename Gameplay Tag"
	_rename_dialog.get_ok_button().text = "Rename Tag"
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)

	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "New tag path"
	_rename_input.clear_button_enabled = true
	_rename_input.custom_minimum_size = Vector2(460.0, 0.0)
	_rename_dialog.add_child(_rename_input)

	_paste_dialog = ConfirmationDialog.new()
	_paste_dialog.title = "Paste Gameplay Tags"
	_paste_dialog.dialog_text = (
		"Enter one tag per line. " + "Commas and slashes create hierarchy segments."
	)
	_paste_dialog.get_ok_button().text = "Add Tags"
	_paste_dialog.confirmed.connect(_on_paste_tags_confirmed)
	add_child(_paste_dialog)

	_paste_input = TextEdit.new()
	_paste_input.custom_minimum_size = Vector2(560.0, 280.0)
	_paste_input.placeholder_text = "Ability.Jump\nState,Stunned\nDamage/Fire"
	_paste_dialog.add_child(_paste_input)

	_import_dialog = FileDialog.new()
	_import_dialog.access = FileDialog.ACCESS_RESOURCES
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.filters = PackedStringArray(["*.csv ; CSV files"])
	_import_dialog.title = "Import Gameplay Tags CSV"
	_import_dialog.file_selected.connect(_on_import_csv_selected)
	add_child(_import_dialog)

	_export_dialog = FileDialog.new()
	_export_dialog.access = FileDialog.ACCESS_RESOURCES
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.filters = PackedStringArray(["*.csv ; CSV files"])
	_export_dialog.title = "Export Gameplay Tags CSV"
	_export_dialog.file_selected.connect(_on_export_csv_selected)
	add_child(_export_dialog)

	_remove_confirmation = ConfirmationDialog.new()
	_remove_confirmation.title = "Remove Gameplay Tags"
	_remove_confirmation.confirmed.connect(_on_remove_confirmed)
	add_child(_remove_confirmation)


func _load_database() -> void:
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("get_database"):
		_database = registry.get_database()
		return

	var path: String = _get_database_path()
	if ResourceLoader.exists(path):
		var existing_resource: Resource = load(path)
		if existing_resource is GameplayTagDatabase:
			_database = existing_resource
			return
		_database = null
		_set_status("Database path contains another resource type: %s" % path)
		return

	_database = GameplayTagDatabase.new()
	_database.resource_path = path
	_save_database()


func _refresh() -> void:
	if _tag_tree == null:
		return

	_tag_tree.clear()
	_tree_items_by_tag.clear()
	_selected_tag = &""
	_details_container.visible = false
	_update_description_button.disabled = true
	_rename_button.disabled = true
	_remove_button.disabled = true

	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return

	var search_text: String = _search_input.text if _search_input != null else ""
	var matched_tags: Array[StringName] = _database.find_tags(search_text)
	var tree_tags: Array[StringName] = _include_ancestor_tags(matched_tags)
	var root: TreeItem = _tag_tree.create_item()
	for tag in tree_tags:
		var tag_text: String = String(tag)
		var parent_item: TreeItem = root
		var separator_index: int = tag_text.rfind(".")
		if separator_index >= 0:
			var parent_tag: StringName = StringName(tag_text.left(separator_index))
			parent_item = _tree_items_by_tag.get(parent_tag, root)

		var item: TreeItem = _tag_tree.create_item(parent_item)
		item.set_text(0, tag_text.get_slice(".", tag_text.get_slice_count(".") - 1))
		item.set_metadata(0, tag)
		var description: String = String(_database.tag_descriptions.get(tag_text, ""))
		var tooltip: String = tag_text
		if not description.is_empty():
			tooltip += "\n%s" % description
		item.set_tooltip_text(0, tooltip)
		_tree_items_by_tag[tag] = item

	_set_status("%d visible / %d total tags." % [matched_tags.size(), _database.tags.size()])


func _include_ancestor_tags(matched_tags: Array[StringName]) -> Array[StringName]:
	var tree_tags: Array[StringName] = matched_tags.duplicate()
	for tag in matched_tags:
		var parent_text: String = String(tag)
		while parent_text.contains("."):
			parent_text = parent_text.left(parent_text.rfind("."))
			var parent_tag: StringName = StringName(parent_text)
			if _database.has_tag(parent_tag) and not tree_tags.has(parent_tag):
				tree_tags.append(parent_tag)
	return GameplayTagDatabase.canonicalize_tag_array(tree_tags)


func _on_add_pressed() -> void:
	if _database == null:
		_load_database()

	var tag_text: String = _tag_input.text.strip_edges()
	if tag_text.is_empty():
		_set_status("Enter a tag name first.")
		return

	var added: bool = false
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("add_tag"):
		added = bool(registry.add_tag(StringName(tag_text), _description_input.text.strip_edges()))
		_database = registry.get_database()
		if added and not _save_tag_ids_script():
			return
	else:
		added = _database.add_tag(StringName(tag_text), _description_input.text.strip_edges())
		if added and not _save_database():
			return

	if not added:
		_set_status("Tag already exists or is invalid: %s" % tag_text)
		return

	_tag_input.clear()
	_description_input.clear()
	_refresh()
	_set_status("Added %s" % String(GameplayTagDatabase.normalize_tag(StringName(tag_text))))


func _on_update_description_pressed() -> void:
	if _database == null or _selected_tag == &"":
		return

	var tag: StringName = _selected_tag
	var current_description: String = String(_database.tag_descriptions.get(String(tag), ""))
	var new_description: String = _edit_description_input.text.strip_edges()
	if current_description == new_description:
		_set_status("Description is unchanged for %s." % String(tag))
		return

	var update_status: String = "Updated description for %s." % String(tag)
	if new_description.is_empty():
		update_status = "Cleared description for %s." % String(tag)
	if undo_redo_manager == null:
		_apply_tag_description(tag, new_description, update_status)
		return

	(
		undo_redo_manager
		. create_action(
			"Edit Gameplay Tag Description %s" % String(tag),
			UndoRedo.MERGE_DISABLE,
			_database,
		)
	)
	(
		undo_redo_manager
		. add_do_method(
			self,
			"_apply_tag_description",
			tag,
			new_description,
			update_status,
		)
	)
	(
		undo_redo_manager
		. add_undo_method(
			self,
			"_apply_tag_description",
			tag,
			current_description,
			"Restored description for %s." % String(tag),
		)
	)
	undo_redo_manager.commit_action()


func _apply_tag_description(
	tag: StringName,
	description: String,
	status_message: String,
) -> void:
	if _database == null:
		_load_database()
	if _database == null:
		return

	var changed: bool = false
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("set_tag_description"):
		changed = bool(registry.set_tag_description(tag, description, false))
		_database = registry.get_database()
	else:
		changed = _database.set_tag_description(tag, description)
	if not changed:
		_set_status("Could not update description for %s." % String(tag))
		return
	if not _save_database_resource():
		return

	_refresh()
	_select_tag_in_tree(tag)
	_set_status(status_message)


func _on_rename_pressed() -> void:
	if _database == null or _selected_tag == &"":
		return
	var child_count: int = _database.get_children(_selected_tag, true).size()
	_rename_dialog.dialog_text = (
		(
			"Rename %s and %d child tag(s).\n\n"
			+ "Generated constants will change. Existing scene and script references are not rewritten."
		)
		% [String(_selected_tag), child_count]
	)
	_rename_input.text = String(_selected_tag)
	_rename_dialog.popup_centered(Vector2i(560, 230))
	_rename_input.grab_focus()
	_rename_input.select_all()


func _on_rename_confirmed() -> void:
	if _database == null or _selected_tag == &"":
		return
	_rename_tag_with_undo(_selected_tag, _rename_input.text)


func _rename_tag_with_undo(tag: StringName, raw_new_tag_text: String) -> void:
	var new_tag: StringName = GameplayTagDatabase.normalize_tag(StringName(raw_new_tag_text))
	var before_tags: Array[StringName] = _database.get_all_tags()
	var before_descriptions: Dictionary[String, String] = _database.tag_descriptions.duplicate(true)
	var preview: GameplayTagDatabase = GameplayTagDatabase.new()
	preview.tags = before_tags
	preview.tag_descriptions = before_descriptions
	if not preview.rename_tag(tag, new_tag):
		_set_status(
			(
				"Could not rename %s. The new tag is invalid, unchanged, or conflicts with an existing tag."
				% String(tag)
			)
		)
		return

	if not TagCodeGenerator.get_constant_name_collisions(preview).is_empty():
		_set_status(
			(
				"Could not rename %s because the generated GameplayTagIds constants would collide."
				% String(tag)
			)
		)
		return

	var status_message: String = "Renamed %s to %s." % [String(tag), String(new_tag)]
	if undo_redo_manager == null:
		_apply_database_state(
			preview.get_all_tags(),
			preview.tag_descriptions.duplicate(true),
			status_message,
			new_tag,
		)
		return

	(
		undo_redo_manager
		. create_action(
			"Rename Gameplay Tag %s" % String(tag),
			UndoRedo.MERGE_DISABLE,
			_database,
		)
	)
	(
		undo_redo_manager
		. add_do_method(
			self,
			"_apply_database_state",
			preview.get_all_tags(),
			preview.tag_descriptions.duplicate(true),
			status_message,
			new_tag,
		)
	)
	(
		undo_redo_manager
		. add_undo_method(
			self,
			"_apply_database_state",
			before_tags,
			before_descriptions,
			"Restored %s and its child tags." % String(tag),
			tag,
		)
	)
	undo_redo_manager.commit_action()


func _on_remove_pressed() -> void:
	if _database == null or _selected_tag == &"":
		return

	_pending_remove_tag = _selected_tag
	var child_count: int = _database.get_children(_pending_remove_tag, true).size()
	var affected_count: int = child_count + 1
	_remove_confirmation.dialog_text = (
		"Remove %s and %d child tag(s)?\n\nThis operation can be undone from the editor."
		% [String(_pending_remove_tag), child_count]
	)
	_remove_confirmation.get_ok_button().text = "Remove %d Tags" % affected_count
	_remove_confirmation.popup_centered(Vector2i(520, 200))


func _on_remove_confirmed() -> void:
	var tag: StringName = _pending_remove_tag
	_pending_remove_tag = &""
	if tag == &"" or _database == null:
		return
	_remove_tag_with_undo(tag)


func _remove_tag_with_undo(tag: StringName) -> void:
	if undo_redo_manager == null:
		_remove_tag_immediately(tag)
		return

	var before_tags: Array[StringName] = _database.get_all_tags()
	var before_descriptions: Dictionary[String, String] = _database.tag_descriptions.duplicate(true)
	var preview: GameplayTagDatabase = GameplayTagDatabase.new()
	preview.tags = before_tags
	preview.tag_descriptions = before_descriptions
	if not preview.remove_tag(tag, true):
		return

	(
		undo_redo_manager
		. create_action(
			"Remove Gameplay Tag %s" % String(tag),
			UndoRedo.MERGE_DISABLE,
			_database,
		)
	)
	(
		undo_redo_manager
		. add_do_method(
			self,
			"_apply_database_state",
			preview.get_all_tags(),
			preview.tag_descriptions.duplicate(true),
			"Removed %s and its children." % String(tag),
		)
	)
	(
		undo_redo_manager
		. add_undo_method(
			self,
			"_apply_database_state",
			before_tags,
			before_descriptions,
			"Restored %s and its children." % String(tag),
		)
	)
	undo_redo_manager.commit_action()


func _remove_tag_immediately(tag: StringName) -> void:
	var removed: bool = false
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("remove_tag"):
		removed = bool(registry.remove_tag(tag, true))
		_database = registry.get_database()
		if removed and not _save_tag_ids_script():
			return
	else:
		removed = _database.remove_tag(tag, true)
		if removed and not _save_database():
			return

	if removed:
		_refresh()
		_set_status("Removed %s and its children." % String(tag))


func _apply_database_state(
	raw_tags: Array[StringName],
	descriptions: Dictionary[String, String],
	status_message: String,
	selected_tag: StringName = &"",
) -> void:
	if _database == null:
		_load_database()
	if _database == null:
		return

	_database.tags = GameplayTagDatabase.canonicalize_tag_array(raw_tags)
	_database.tag_descriptions = descriptions.duplicate(true)
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("set_database"):
		registry.set_database(_database)
	_refresh()
	if selected_tag != &"":
		_select_tag_in_tree(selected_tag)
	if not _save_database():
		return
	_set_status(status_message)


func _on_tools_menu_id_pressed(id: int) -> void:
	match id:
		ToolsAction.REFRESH:
			_on_refresh_pressed()
		ToolsAction.REGENERATE_IDS:
			_on_regenerate_pressed()
		ToolsAction.PASTE_TAGS:
			_on_paste_tags_pressed()
		ToolsAction.IMPORT_CSV:
			_on_import_csv_pressed()
		ToolsAction.EXPORT_CSV:
			_on_export_csv_pressed()
		_:
			pass


func _on_refresh_pressed() -> void:
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("reload_database"):
		_database = registry.reload_database()
	else:
		_load_database()
	_refresh()


func _on_regenerate_pressed() -> void:
	if _save_tag_ids_script():
		_set_status("Regenerated %s" % _get_tag_ids_path())


func _on_paste_tags_pressed() -> void:
	_paste_dialog.popup_centered(Vector2i(620, 430))
	_paste_input.grab_focus()


func _on_paste_tags_confirmed() -> void:
	if _database == null:
		_load_database()
	if _database == null:
		return

	var candidates: Array[StringName] = GameplayTagDatabase.tags_from_csv_text(_paste_input.text)
	if candidates.is_empty():
		_set_status("No valid gameplay tags were found in the pasted text.")
		return

	var existing_count: int = 0
	var invalid_count: int = 0
	for tag in candidates:
		if not GameplayTagDatabase.is_valid_tag_name(tag):
			invalid_count += 1
		elif _database.has_tag(tag):
			existing_count += 1

	var added: int = 0
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("add_tags"):
		added = int(registry.add_tags(candidates, false))
		_database = registry.get_database()
	else:
		added = _database.add_tags(candidates)
	if added > 0:
		if not _save_database():
			return
		_paste_input.clear()
	_refresh()
	_set_status(
		(
			"Added %d pasted tag(s); %d already existed; %d invalid."
			% [added, existing_count, invalid_count]
		)
	)


func _on_import_csv_pressed() -> void:
	_import_dialog.popup_centered(Vector2i(720, 480))


func _on_export_csv_pressed() -> void:
	_export_dialog.current_file = "gameplay_tags.csv"
	_export_dialog.popup_centered(Vector2i(720, 480))


func _on_import_csv_selected(path: String) -> void:
	var added: int = _import_tags_from_csv(path)
	if added < 0:
		return
	if added == 0:
		_set_status("No new tags imported from %s." % path)
		return
	_refresh()
	if not _save_tag_ids_script():
		_set_status(
			"Imported %d tags from %s, but GameplayTagIds could not be regenerated." % [added, path]
		)
		return
	_set_status("Imported %d tags from %s." % [added, path])


func _on_export_csv_selected(path: String) -> void:
	var err: Error = _export_tags_to_csv(path)
	if err == OK:
		_set_status("Exported tags to %s." % path)
	else:
		_set_status("Could not export CSV: %s" % error_string(err))


func _on_search_changed(_text: String) -> void:
	_refresh()


func _on_tag_submitted(_text: String) -> void:
	_on_add_pressed()


func _on_description_submitted(_text: String) -> void:
	if not _update_description_button.disabled:
		_on_update_description_pressed()


func _on_edit_description_changed(text: String) -> void:
	if _database == null or _selected_tag == &"":
		_update_description_button.disabled = true
		return
	var current_description: String = String(
		_database.tag_descriptions.get(String(_selected_tag), "")
	)
	_update_description_button.disabled = text.strip_edges() == current_description


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tag_tree.get_selected()
	if item == null or _database == null:
		_selected_tag = &""
		_details_container.visible = false
		_update_description_button.disabled = true
		_rename_button.disabled = true
		_remove_button.disabled = true
		return

	_selected_tag = StringName(item.get_metadata(0))
	_selected_tag_label.text = String(_selected_tag)
	_edit_description_input.text = String(_database.tag_descriptions.get(String(_selected_tag), ""))
	_details_container.visible = true
	_update_description_button.disabled = true
	_rename_button.disabled = false
	_remove_button.disabled = false


func _select_tag_in_tree(tag: StringName) -> void:
	var item: TreeItem = _tree_items_by_tag.get(tag)
	if item == null:
		return
	item.select(0)
	_tag_tree.scroll_to_item(item)
	_on_tree_item_selected()


func _save_database() -> bool:
	if not _save_database_resource():
		return false
	return _save_tag_ids_script()


func _save_database_resource() -> bool:
	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return false
	var path: String = _get_database_path()
	if ResourceLoader.exists(path):
		var existing_resource: Resource = (
			ResourceLoader
			. load(
				path,
				"",
				ResourceLoader.CACHE_MODE_IGNORE,
			)
		)
		if not existing_resource is GameplayTagDatabase:
			_set_status("Refusing to overwrite another resource at: %s" % path)
			return false
	var directory_error: Error = _ensure_database_directory(path)
	if directory_error != OK:
		_set_status("Could not create database directory: %s" % error_string(directory_error))
		return false
	var err: Error = ResourceSaver.save(_database, path)
	if err != OK:
		_set_status("Could not save database: %s" % error_string(err))
		return false
	return true


func _save_tag_ids_script() -> bool:
	if _database == null:
		return false
	var path: String = _get_tag_ids_path()
	var err: Error = TagCodeGenerator.save_tag_ids(_database, path)
	if err != OK:
		_set_status("Could not generate GameplayTagIds: %s" % error_string(err))
		return false
	TagCodeGenerator.refresh_editor_filesystem()
	return true


func _import_tags_from_csv(path: String) -> int:
	var added: int = 0
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("import_tags_from_csv"):
		added = int(registry.import_tags_from_csv(path, true))
		_database = registry.get_database()
	elif _database != null:
		added = _import_tags_from_csv_without_registry(path)
	return added


func _import_tags_from_csv_without_registry(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Could not open CSV: %s" % path)
		return -1
	var added: int = _database.add_tags_from_csv_text(file.get_as_text())
	file.close()
	if added > 0 and not _save_database_resource():
		return -1
	return added


func _export_tags_to_csv(path: String) -> Error:
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("export_tags_to_csv"):
		return registry.export_tags_to_csv(path)

	var directory_error: Error = _ensure_database_directory(path)
	if directory_error != OK:
		return directory_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	file.store_string(_database.to_csv_text())
	file.close()
	return OK


func _ensure_database_directory(path: String) -> Error:
	var directory: String = path.get_base_dir()
	if directory.is_empty() or directory == "res://" or directory == "user://":
		return OK
	return DirAccess.make_dir_recursive_absolute(directory)


func _get_database_path() -> String:
	return String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))


func _get_tag_ids_path() -> String:
	return String(ProjectSettings.get_setting(TAG_IDS_SETTING, DEFAULT_TAG_IDS_PATH))


func _get_registry() -> Node:
	return GameplayTagUtils.get_registry(self)


func _apply_editor_icon(button: Button, icon_name: StringName) -> void:
	if has_theme_icon(icon_name, "EditorIcons"):
		button.icon = get_theme_icon(icon_name, "EditorIcons")


func _set_status(message: String) -> void:
	if _status_label == null:
		return

	_status_label.text = message
	_status_label.remove_theme_color_override("font_color")
	var color_name: StringName = &""
	if message.contains("could not be regenerated"):
		color_name = &"warning_color"
	elif (
		message.begins_with("Added")
		or message.begins_with("Cleared")
		or message.begins_with("Removed")
		or message.begins_with("Updated")
		or message.begins_with("Restored")
		or message.begins_with("Imported")
		or message.begins_with("Exported")
		or message.begins_with("Regenerated")
		or message.begins_with("Renamed")
	):
		color_name = &"success_color"
	elif (
		message.begins_with("Could not")
		or message.begins_with("Refusing")
		or message.begins_with("Database path")
		or message.begins_with("Tag already")
	):
		color_name = &"error_color"
	elif message.begins_with("Enter") or message.begins_with("No "):
		color_name = &"warning_color"

	if color_name != &"" and has_theme_color(color_name, "Editor"):
		(
			_status_label
			. add_theme_color_override(
				"font_color",
				get_theme_color(color_name, "Editor"),
			)
		)
