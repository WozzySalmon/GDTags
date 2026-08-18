@tool
extends VBoxContainer

const TagCodeGenerator: Script = preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_code_generator.gd"
)
const StatusStyle: Script = preload("res://addons/gameplay_tags/editor/tag_dock_status_style.gd")
const TagDockBulk: Script = preload("res://addons/gameplay_tags/editor/tag_dock_bulk.gd")
const TagDockIo: Script = preload("res://addons/gameplay_tags/editor/tag_dock_io.gd")
const TagDockTree: Script = preload("res://addons/gameplay_tags/editor/tag_dock_tree.gd")
const TagDockUi: Script = preload("res://addons/gameplay_tags/editor/tag_dock_ui.gd")
const TagDockUndo: Script = preload("res://addons/gameplay_tags/editor/tag_dock_undo.gd")

const SEARCH_DEBOUNCE_SECONDS: float = 0.2

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
var _add_child_button: Button
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
var _search_debounce_timer: Timer
var _tree_items_by_tag: Dictionary[StringName, TreeItem] = {}
var _last_database_resource_save_succeeded: bool = true
var _last_database_state_save_succeeded: bool = true


func _ready() -> void:
	_build_ui()
	_load_database()
	_refresh()


func _build_ui() -> void:
	add_theme_constant_override("separation", 8)

	var title: Label = TagDockUi.build_title(self)
	add_child(title)

	var path_label: Label = TagDockUi.build_database_path_label(
		GameplayTagUtils.get_database_path(), GameplayTagUtils.get_tag_ids_path()
	)
	add_child(path_label)

	var tags_heading: Label = TagDockUi.build_tags_heading()
	add_child(tags_heading)

	_search_input = TagDockUi.build_search_input()
	_search_input.text_changed.connect(_on_search_changed)
	add_child(_search_input)

	# Rebuilding the whole Tree on every keystroke is visibly slow once a project has
	# a few thousand tags, so coalesce bursts of typing into one refresh.
	_search_debounce_timer = TagDockUi.build_search_debounce_timer(SEARCH_DEBOUNCE_SECONDS)
	_search_debounce_timer.timeout.connect(_refresh)
	add_child(_search_debounce_timer)

	_tag_tree = TagDockUi.build_tag_tree()
	_tag_tree.item_selected.connect(_on_tree_item_selected)
	add_child(_tag_tree)

	var details: Dictionary[String, Control] = TagDockUi.build_details_panel(self)
	_details_container = details["container"] as VBoxContainer
	_selected_tag_label = details["selected_tag_label"] as Label
	_edit_description_input = details["edit_description_input"] as LineEdit
	_update_description_button = details["update_description_button"] as Button
	_add_child_button = details["add_child_button"] as Button
	_rename_button = details["rename_button"] as Button
	_remove_button = details["remove_button"] as Button
	add_child(_details_container)

	var details_separator: HSeparator = details["separator"] as HSeparator
	_details_container.add_child(details_separator)

	var details_heading: Label = details["heading"] as Label
	_details_container.add_child(details_heading)

	_details_container.add_child(_selected_tag_label)

	_edit_description_input.text_changed.connect(_on_edit_description_changed)
	_edit_description_input.text_submitted.connect(_on_description_submitted)
	_details_container.add_child(_edit_description_input)

	_update_description_button.pressed.connect(_on_update_description_pressed)
	_details_container.add_child(_update_description_button)

	var tag_action_buttons: HBoxContainer = details["action_buttons"] as HBoxContainer
	_details_container.add_child(tag_action_buttons)

	_add_child_button.pressed.connect(_on_add_child_pressed)
	tag_action_buttons.add_child(_add_child_button)

	_rename_button.pressed.connect(_on_rename_pressed)
	tag_action_buttons.add_child(_rename_button)

	_remove_button.pressed.connect(_on_remove_pressed)
	tag_action_buttons.add_child(_remove_button)

	var add_form: Dictionary[String, Control] = TagDockUi.build_add_form(self)
	var add_separator: HSeparator = add_form["separator"] as HSeparator
	add_child(add_separator)

	var add_heading: Label = add_form["heading"] as Label
	add_child(add_heading)

	_tag_input = add_form["tag_input"] as LineEdit
	_tag_input.text_submitted.connect(_on_tag_submitted)
	add_child(_tag_input)

	_description_input = add_form["description_input"] as LineEdit
	_description_input.text_submitted.connect(_on_tag_submitted)
	add_child(_description_input)

	var buttons: HBoxContainer = add_form["buttons"] as HBoxContainer
	add_child(buttons)

	var add_button: Button = add_form["add_button"] as Button
	add_button.pressed.connect(_on_add_pressed)
	buttons.add_child(add_button)

	var tools_button: MenuButton = TagDockUi.build_tools_menu(self)
	buttons.add_child(tools_button)

	var tools_menu: PopupMenu = tools_button.get_popup()
	tools_menu.id_pressed.connect(_on_tools_menu_id_pressed)

	_build_file_dialogs()

	_status_label = TagDockUi.build_status_label()
	add_child(_status_label)


func _build_file_dialogs() -> void:
	var dialogs: Dictionary[String, Node] = TagDockUi.build_file_dialogs()
	_rename_dialog = dialogs["rename_dialog"] as ConfirmationDialog
	_rename_input = dialogs["rename_input"] as LineEdit
	_paste_dialog = dialogs["paste_dialog"] as ConfirmationDialog
	_paste_input = dialogs["paste_input"] as TextEdit
	_import_dialog = dialogs["import_dialog"] as FileDialog
	_export_dialog = dialogs["export_dialog"] as FileDialog
	_remove_confirmation = dialogs["remove_confirmation"] as ConfirmationDialog

	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	add_child(_rename_dialog)
	_rename_dialog.add_child(_rename_input)

	_paste_dialog.confirmed.connect(_on_paste_tags_confirmed)
	add_child(_paste_dialog)
	_paste_dialog.add_child(_paste_input)

	_import_dialog.file_selected.connect(_on_import_csv_selected)
	add_child(_import_dialog)

	_export_dialog.file_selected.connect(_on_export_csv_selected)
	add_child(_export_dialog)

	_remove_confirmation.confirmed.connect(_on_remove_confirmed)
	add_child(_remove_confirmation)


func _load_database() -> void:
	var registry: GameplayTagRegistry = _get_registry()
	if registry != null:
		_database = registry.get_database()
		return

	var path: String = GameplayTagUtils.get_database_path()
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

	# Keep the current selection across rebuilds. Losing it on every refresh fights the
	# documented "select a parent, then Add Child" workflow.
	var previously_selected: StringName = _selected_tag
	_tag_tree.clear()
	_tree_items_by_tag.clear()
	_clear_selection_state()

	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return

	var search_text: String = _search_input.text if _search_input != null else ""
	var matched_tags: Array[StringName] = _database.find_tags(search_text)
	var tree_tags: Array[StringName] = TagDockTree.include_ancestor_tags(_database, matched_tags)
	_tree_items_by_tag = TagDockTree.populate(_tag_tree, _database, tree_tags)

	if previously_selected != &"" and _tree_items_by_tag.has(previously_selected):
		_select_tag_in_tree(previously_selected)

	_set_status("%d visible / %d total tags." % [matched_tags.size(), _database.tags.size()])


func _on_add_child_pressed() -> void:
	if _selected_tag.is_empty():
		_set_status("Select a parent tag first.")
		return

	_tag_input.text = "%s." % String(_selected_tag)
	_tag_input.caret_column = _tag_input.text.length()
	_tag_input.grab_focus()
	_set_status("Enter the child name after %s." % String(_selected_tag))


func _on_add_pressed() -> void:
	if _database == null:
		_load_database()
	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return

	var tag_text: String = _tag_input.text.strip_edges()
	if tag_text.is_empty():
		_set_status("Enter a tag name first.")
		return

	var tag: StringName = GameplayTagDatabase.normalize_tag(StringName(tag_text))
	var before_tags: Array[StringName] = _database.get_all_tags()
	var before_descriptions: Dictionary[String, String] = _database.tag_descriptions.duplicate(true)
	var before_redirects: Dictionary[StringName, StringName] = _database.tag_redirects.duplicate(
		true
	)
	var preview: GameplayTagDatabase = GameplayTagDatabase.new()
	preview.set_state(before_tags, before_descriptions, before_redirects)
	if not preview.add_tag(tag, _description_input.text.strip_edges()):
		_set_status("Tag already exists or is invalid: %s" % tag_text)
		return
	if not TagCodeGenerator.get_constant_name_collisions(preview).is_empty():
		_set_status(
			(
				"Could not add %s because the generated GameplayTagIds constants would collide."
				% String(tag)
			)
		)
		return

	var status_message: String = "Added %s" % String(tag)
	if undo_redo_manager == null:
		_apply_database_state(
			_database,
			preview.get_all_tags(),
			preview.tag_descriptions.duplicate(true),
			preview.tag_redirects.duplicate(true),
			status_message,
			tag,
		)
	else:
		var do_step: Dictionary = (
			TagDockUndo
			. make_step(
				preview.get_all_tags(),
				preview.tag_descriptions.duplicate(true),
				preview.tag_redirects.duplicate(true),
				status_message,
				tag,
			)
		)
		var undo_step: Dictionary = (
			TagDockUndo
			. make_step(
				before_tags,
				before_descriptions,
				before_redirects,
				"Removed newly added %s." % String(tag),
				&"",
			)
		)
		(
			TagDockUndo
			. commit_state_change(
				undo_redo_manager,
				self,
				_database,
				"Add Gameplay Tag %s" % String(tag),
				do_step,
				undo_step,
			)
		)

	_tag_input.clear()
	_description_input.clear()


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
		_apply_tag_description(_database, tag, new_description, update_status)
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
			_database,
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
			_database,
			tag,
			current_description,
			"Restored description for %s." % String(tag),
		)
	)
	undo_redo_manager.commit_action()


func _apply_tag_description(
	target_database: GameplayTagDatabase,
	tag: StringName,
	description: String,
	status_message: String,
) -> void:
	if target_database == null:
		return
	if _database == null:
		_load_database()

	if target_database != _database:
		target_database.set_tag_description(tag, description)
		_persist_off_screen_database(
			target_database, "Restored a description on the previously configured database."
		)
		return

	var changed: bool = false
	var registry: GameplayTagRegistry = _get_registry()
	if registry != null:
		changed = registry.set_tag_description(tag, description, false)
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
	var before_redirects: Dictionary[StringName, StringName] = _database.tag_redirects.duplicate(
		true
	)
	var preview: GameplayTagDatabase = GameplayTagDatabase.new()
	preview.set_state(before_tags, before_descriptions, before_redirects)
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
			_database,
			preview.get_all_tags(),
			preview.tag_descriptions.duplicate(true),
			preview.tag_redirects.duplicate(true),
			status_message,
			new_tag,
		)
		return

	var do_step: Dictionary = (
		TagDockUndo
		. make_step(
			preview.get_all_tags(),
			preview.tag_descriptions.duplicate(true),
			preview.tag_redirects.duplicate(true),
			status_message,
			new_tag,
		)
	)
	var undo_step: Dictionary = (
		TagDockUndo
		. make_step(
			before_tags,
			before_descriptions,
			before_redirects,
			"Restored %s and its child tags." % String(tag),
			tag,
		)
	)
	(
		TagDockUndo
		. commit_state_change(
			undo_redo_manager,
			self,
			_database,
			"Rename Gameplay Tag %s" % String(tag),
			do_step,
			undo_step,
		)
	)


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
	var before_redirects: Dictionary[StringName, StringName] = _database.tag_redirects.duplicate(
		true
	)
	var preview: GameplayTagDatabase = GameplayTagDatabase.new()
	preview.set_state(before_tags, before_descriptions, before_redirects)
	if not preview.remove_tag(tag, true):
		return

	var do_step: Dictionary = (
		TagDockUndo
		. make_step(
			preview.get_all_tags(),
			preview.tag_descriptions.duplicate(true),
			preview.tag_redirects.duplicate(true),
			"Removed %s and its children." % String(tag),
			&"",
		)
	)
	var undo_step: Dictionary = (
		TagDockUndo
		. make_step(
			before_tags,
			before_descriptions,
			before_redirects,
			"Restored %s and its children." % String(tag),
			&"",
		)
	)
	(
		TagDockUndo
		. commit_state_change(
			undo_redo_manager,
			self,
			_database,
			"Remove Gameplay Tag %s" % String(tag),
			do_step,
			undo_step,
		)
	)


func _remove_tag_immediately(tag: StringName) -> void:
	var removed: bool = false
	var registry: GameplayTagRegistry = _get_registry()
	if registry != null:
		removed = registry.remove_tag(tag, true)
		_database = registry.get_database()
		if removed:
			_refresh()
			if not _save_tag_ids_script():
				return
	else:
		removed = _database.remove_tag(tag, true)
		if removed:
			_refresh()
			if not _save_database():
				return

	if removed:
		_set_status("Removed %s and its children." % String(tag))


func _apply_database_state(
	target_database: GameplayTagDatabase,
	raw_tags: Array[StringName],
	descriptions: Dictionary[String, String],
	redirects: Dictionary[StringName, StringName],
	status_message: String,
	selected_tag: StringName = &"",
) -> void:
	_last_database_resource_save_succeeded = false
	_last_database_state_save_succeeded = false
	if target_database == null:
		return
	if _database == null:
		_load_database()

	target_database.set_state(raw_tags, descriptions, redirects)
	if target_database != _database:
		_persist_off_screen_database(
			target_database, "Restored tags on the previously configured database."
		)
		return

	var registry: GameplayTagRegistry = _get_registry()
	if registry != null:
		registry.set_database(_database)
	_refresh()
	if selected_tag != &"":
		_select_tag_in_tree(selected_tag)
	if not _save_database_resource():
		return
	_last_database_resource_save_succeeded = true
	if not _save_tag_ids_script():
		return
	_last_database_state_save_succeeded = true
	_set_status(status_message)


# Undo actions outlive the database they target. If the configured path changes, write an
# old action's snapshot straight to its original database instead of the one now on screen.
func _persist_off_screen_database(
	target_database: GameplayTagDatabase, status_message: String
) -> void:
	var path: String = target_database.resource_path
	if path.is_empty():
		_set_status("Could not persist the previously configured gameplay tag database.")
		return
	if TagDockIo.database_path_conflicts(path):
		_set_status("Refusing to overwrite another resource at: %s" % path)
		return
	var err: Error = ResourceSaver.save(target_database, path)
	if err != OK:
		_set_status("Could not save database: %s" % error_string(err))
		return
	_set_status(status_message)


func _on_tools_menu_id_pressed(id: int) -> void:
	match id:
		TagDockUi.ToolsAction.REFRESH:
			_on_refresh_pressed()
		TagDockUi.ToolsAction.REGENERATE_IDS:
			_on_regenerate_pressed()
		TagDockUi.ToolsAction.PASTE_TAGS:
			_on_paste_tags_pressed()
		TagDockUi.ToolsAction.IMPORT_CSV:
			_on_import_csv_pressed()
		TagDockUi.ToolsAction.EXPORT_CSV:
			_on_export_csv_pressed()
		TagDockUi.ToolsAction.SCAN_REFERENCES:
			_on_scan_references_pressed()
		TagDockUi.ToolsAction.MIGRATE_REFERENCES:
			_on_migrate_references_pressed()
		_:
			pass


func _on_migrate_references_pressed() -> void:
	if _database == null:
		_load_database()
	if _database == null:
		_set_status("No gameplay tag database to migrate against.")
		return

	var retired_tags: Array[StringName] = _database.get_redirected_tags()
	if retired_tags.is_empty():
		_set_status("No renamed tags to migrate.")
		return

	var changes: Dictionary[String, int] = GameplayTagReferenceIndex.migrate_redirected_tags(
		_database
	)
	if changes.is_empty():
		_set_status("Nothing still refers to the %d renamed tags." % retired_tags.size())
		return

	print_rich("[b]Migrated gameplay tag references[/b]")
	for path in changes:
		print("  %s (%d tags)" % [path, changes[path]])
	_set_status(
		(
			"Rewrote references in %d file(s). Reload affected scenes before editing them."
			% changes.size()
		)
	)


func _on_scan_references_pressed() -> void:
	if _database == null:
		_load_database()
	if _database == null:
		_set_status("No gameplay tag database to scan against.")
		return

	var index: Dictionary[StringName, PackedStringArray] = GameplayTagReferenceIndex.scan(_database)
	var unused: Array[StringName] = GameplayTagReferenceIndex.find_unused_tags(index)
	var total_references: int = 0
	for tag in index:
		total_references += index[tag].size()

	# Printed as well as summarised: the dock status line has room for a count, but the
	# actual locations are what makes the scan worth running.
	print_rich("[b]Gameplay tag references[/b]")
	for tag in index:
		if index[tag].is_empty():
			continue
		print("  %s (%d)" % [String(tag), index[tag].size()])
		for location in index[tag]:
			print("    %s" % location)
	if not unused.is_empty():
		var unused_names: PackedStringArray = PackedStringArray()
		for tag in unused:
			unused_names.append(String(tag))
		print("  unused: %s" % ", ".join(unused_names))

	_set_status(
		(
			"Scanned %d tags: %d references, %d unused. See Output for locations."
			% [index.size(), total_references, unused.size()]
		)
	)


func _on_refresh_pressed() -> void:
	var registry: GameplayTagRegistry = _get_registry()
	if registry != null:
		_database = registry.reload_database()
	else:
		_load_database()
	_refresh()


func _on_regenerate_pressed() -> void:
	if _save_tag_ids_script():
		_set_status("Regenerated %s" % GameplayTagUtils.get_tag_ids_path())


func _on_paste_tags_pressed() -> void:
	_paste_dialog.popup_centered(Vector2i(620, 430))
	_paste_input.grab_focus()


func _on_paste_tags_confirmed() -> void:
	if _database == null:
		_load_database()
	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return

	var candidates: Array[StringName] = GameplayTagDatabase.tags_from_csv_text(_paste_input.text)
	if candidates.is_empty():
		_set_status("No valid gameplay tags were found in the pasted text.")
		return

	var existing_count: int = 0
	var invalid_count: int = 0
	for tag in candidates:
		if not GameplayTagDatabase.is_canonical_tag_name(tag):
			invalid_count += 1
		elif _database.has_tag(tag):
			existing_count += 1

	var plan: Dictionary = TagDockBulk.make_addition(_database, candidates)
	var added: int = int(plan["added"])
	if bool(plan["has_collisions"]):
		_set_status(
			"Could not paste tags because the generated GameplayTagIds constants would collide."
		)
		return

	var status_message: String = (
		"Added %d pasted tag(s); %d already existed; %d invalid."
		% [added, existing_count, invalid_count]
	)
	if added == 0:
		_set_status(status_message)
		return
	(
		TagDockBulk
		. commit_addition(
			undo_redo_manager,
			self,
			_database,
			plan,
			"Paste Gameplay Tags",
			status_message,
			"Removed %d pasted tag(s)." % added,
		)
	)
	_paste_input.clear()


func _on_import_csv_pressed() -> void:
	_import_dialog.popup_centered(Vector2i(720, 480))


func _on_export_csv_pressed() -> void:
	_export_dialog.current_file = "gameplay_tags.csv"
	_export_dialog.popup_centered(Vector2i(720, 480))


func _on_import_csv_selected(path: String) -> void:
	var added: int = _import_tags_from_csv(path)
	if added == 0:
		_set_status("No new tags imported from %s." % path)
	elif (
		added > 0
		and _last_database_resource_save_succeeded
		and not _last_database_state_save_succeeded
	):
		_set_status(
			"Imported %d tags from %s, but GameplayTagIds could not be regenerated." % [added, path]
		)


func _on_export_csv_selected(path: String) -> void:
	var err: Error = _export_tags_to_csv(path)
	if err == OK:
		_set_status("Exported tags to %s." % path)
	else:
		_set_status("Could not export CSV: %s" % error_string(err))


func _on_search_changed(_text: String) -> void:
	if _search_debounce_timer == null:
		_refresh()
		return
	_search_debounce_timer.start(SEARCH_DEBOUNCE_SECONDS)


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


func _clear_selection_state() -> void:
	_selected_tag = &""
	_details_container.visible = false
	_update_description_button.disabled = true
	_add_child_button.disabled = true
	_rename_button.disabled = true
	_remove_button.disabled = true


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tag_tree.get_selected()
	if item == null or _database == null:
		_clear_selection_state()
		return

	_selected_tag = StringName(item.get_metadata(0))
	_selected_tag_label.text = String(_selected_tag)
	_edit_description_input.text = String(_database.tag_descriptions.get(String(_selected_tag), ""))
	_details_container.visible = true
	_update_description_button.disabled = true
	_add_child_button.disabled = false
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
	var path: String = GameplayTagUtils.get_database_path()
	if TagDockIo.database_path_conflicts(path):
		_set_status("Refusing to overwrite another resource at: %s" % path)
		return false
	var directory_error: Error = TagDockIo.ensure_database_directory(path)
	if directory_error != OK:
		_set_status("Could not create database directory: %s" % error_string(directory_error))
		return false
	var err: Error = TagDockIo.save_database_resource(_database, path)
	if err != OK:
		_set_status("Could not save database: %s" % error_string(err))
		return false
	return true


func _save_tag_ids_script() -> bool:
	if _database == null:
		return false
	var path: String = GameplayTagUtils.get_tag_ids_path()
	var err: Error = TagCodeGenerator.save_tag_ids(_database, path)
	if err != OK:
		_set_status("Could not generate GameplayTagIds: %s" % error_string(err))
		return false
	TagCodeGenerator.refresh_editor_filesystem()
	return true


func _import_tags_from_csv(path: String) -> int:
	if _database == null:
		_load_database()
	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return -1

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Could not open CSV: %s" % path)
		return -1
	var candidates: Array[StringName] = GameplayTagDatabase.tags_from_csv_text(file.get_as_text())
	file.close()

	var plan: Dictionary = TagDockBulk.make_addition(_database, candidates)
	var added: int = int(plan["added"])
	if added == 0:
		return 0
	if bool(plan["has_collisions"]):
		_set_status(
			"Could not import tags because the generated GameplayTagIds constants would collide."
		)
		return -1

	var status_message: String = "Imported %d tags from %s." % [added, path]
	(
		TagDockBulk
		. commit_addition(
			undo_redo_manager,
			self,
			_database,
			plan,
			"Import Gameplay Tags from CSV",
			status_message,
			"Removed %d tags imported from %s." % [added, path],
		)
	)
	return added


func _export_tags_to_csv(path: String) -> Error:
	var registry: GameplayTagRegistry = _get_registry()
	if registry != null:
		return registry.export_tags_to_csv(path)
	if _database == null:
		_load_database()
	if _database == null:
		return ERR_DOES_NOT_EXIST
	return TagDockIo.export_tags_to_csv_file(_database, path)


func _get_registry() -> GameplayTagRegistry:
	return GameplayTagUtils.get_registry(self) as GameplayTagRegistry


func _set_status(message: String) -> void:
	if _status_label == null:
		return

	_status_label.text = message
	_status_label.remove_theme_color_override("font_color")
	var color_name: StringName = StatusStyle.get_status_color_name(message)
	if color_name != &"" and has_theme_color(color_name, "Editor"):
		(
			_status_label
			. add_theme_color_override(
				"font_color",
				get_theme_color(color_name, "Editor"),
			)
		)
