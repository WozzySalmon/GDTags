@tool
extends RefCounted

## Builds and configures the Gameplay Tags editor dock controls without wiring behavior.

enum ToolsAction {
	REFRESH,
	REGENERATE_IDS,
	PASTE_TAGS,
	IMPORT_CSV,
	EXPORT_CSV,
}


static func build_title(theme_source: Control) -> Label:
	var title: Label = Label.new()
	title.text = "Gameplay Tags"
	if theme_source.has_theme_font("bold", "EditorFonts"):
		title.add_theme_font_override("font", theme_source.get_theme_font("bold", "EditorFonts"))
	if theme_source.has_theme_font_size("title_size", "EditorFonts"):
		(
			title
			. add_theme_font_size_override(
				"font_size",
				theme_source.get_theme_font_size("title_size", "EditorFonts"),
			)
		)
	return title


static func build_database_path_label(database_path: String, tag_ids_path: String) -> Label:
	var path_label: Label = Label.new()
	path_label.text = database_path
	path_label.tooltip_text = (
		"Gameplay Tags database: %s\nGenerated code constants: %s" % [database_path, tag_ids_path]
	)
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_label.modulate.a = 0.7
	return path_label


static func build_tags_heading() -> Label:
	var tags_heading: Label = Label.new()
	tags_heading.text = "Tags"
	return tags_heading


static func build_search_input() -> LineEdit:
	var search_input: LineEdit = LineEdit.new()
	search_input.placeholder_text = "Search tags"
	search_input.clear_button_enabled = true
	search_input.tooltip_text = "Filter tags by name or description"
	return search_input


static func build_search_debounce_timer(wait_seconds: float) -> Timer:
	var search_debounce_timer: Timer = Timer.new()
	search_debounce_timer.one_shot = true
	search_debounce_timer.wait_time = wait_seconds
	return search_debounce_timer


static func build_tag_tree() -> Tree:
	var tag_tree: Tree = Tree.new()
	tag_tree.hide_root = true
	tag_tree.columns = 1
	tag_tree.select_mode = Tree.SELECT_SINGLE
	tag_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag_tree.tooltip_text = "Select a tag to view its description or remove it"
	return tag_tree


static func build_details_panel(theme_source: Control) -> Dictionary[String, Control]:
	var details_container: VBoxContainer = VBoxContainer.new()
	details_container.add_theme_constant_override("separation", 6)
	details_container.visible = false

	var separator: HSeparator = HSeparator.new()

	var heading: Label = Label.new()
	heading.text = "Selected tag"

	var selected_tag_label: Label = Label.new()
	selected_tag_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_tag_label.modulate.a = 0.75

	var edit_description_input: LineEdit = LineEdit.new()
	edit_description_input.placeholder_text = "Optional description"
	edit_description_input.clear_button_enabled = true

	var update_description_button: Button = Button.new()
	update_description_button.text = "Update Description"
	update_description_button.tooltip_text = "Save the selected tag's description"

	var action_buttons: HBoxContainer = HBoxContainer.new()
	action_buttons.add_theme_constant_override("separation", 6)

	var add_child_button: Button = Button.new()
	add_child_button.text = "Add Child"
	add_child_button.disabled = true
	add_child_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child_button.tooltip_text = "Add a child beneath the selected tag"
	_apply_editor_icon(theme_source, add_child_button, &"Add")

	var rename_button: Button = Button.new()
	rename_button.text = "Rename"
	rename_button.disabled = true
	rename_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_button.tooltip_text = "Rename or move the selected tag and its child tags"
	_apply_editor_icon(theme_source, rename_button, &"Rename")

	var remove_button: Button = Button.new()
	remove_button.text = "Remove"
	remove_button.disabled = true
	remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_button.tooltip_text = "Remove the selected tag and its child tags"
	_apply_editor_icon(theme_source, remove_button, &"Remove")

	var controls: Dictionary[String, Control] = {
		"container": details_container,
		"separator": separator,
		"heading": heading,
		"selected_tag_label": selected_tag_label,
		"edit_description_input": edit_description_input,
		"update_description_button": update_description_button,
		"action_buttons": action_buttons,
		"add_child_button": add_child_button,
		"rename_button": rename_button,
		"remove_button": remove_button,
	}
	return controls


static func build_add_form(theme_source: Control) -> Dictionary[String, Control]:
	var separator: HSeparator = HSeparator.new()

	var heading: Label = Label.new()
	heading.text = "Add a tag"

	var tag_input: LineEdit = LineEdit.new()
	tag_input.placeholder_text = "Tag name, for example State.Stunned"
	tag_input.clear_button_enabled = true
	tag_input.tooltip_text = "Use dots to create a tag hierarchy"

	var description_input: LineEdit = LineEdit.new()
	description_input.placeholder_text = "Optional description"
	description_input.clear_button_enabled = true

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)

	var add_button: Button = Button.new()
	add_button.text = "Add Tag"
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button.tooltip_text = "Add the tag and any missing parent tags"
	_apply_editor_icon(theme_source, add_button, &"Add")

	var controls: Dictionary[String, Control] = {
		"separator": separator,
		"heading": heading,
		"tag_input": tag_input,
		"description_input": description_input,
		"buttons": buttons,
		"add_button": add_button,
	}
	return controls


static func build_tools_menu(theme_source: Control) -> MenuButton:
	var tools_button: MenuButton = MenuButton.new()
	tools_button.text = "Tools"
	tools_button.tooltip_text = "Database maintenance, import, and export actions"
	_apply_editor_icon(theme_source, tools_button, &"Tools")

	var tools_menu: PopupMenu = tools_button.get_popup()
	tools_menu.add_item("Refresh", ToolsAction.REFRESH)
	tools_menu.add_item("Regenerate IDs", ToolsAction.REGENERATE_IDS)
	tools_menu.add_separator()
	tools_menu.add_item("Paste Tags…", ToolsAction.PASTE_TAGS)
	tools_menu.add_item("Import CSV", ToolsAction.IMPORT_CSV)
	tools_menu.add_item("Export CSV", ToolsAction.EXPORT_CSV)
	return tools_button


static func build_status_label() -> Label:
	var status_label: Label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.modulate.a = 0.85
	return status_label


static func build_file_dialogs() -> Dictionary[String, Node]:
	var rename_dialog: ConfirmationDialog = ConfirmationDialog.new()
	rename_dialog.title = "Rename Gameplay Tag"
	rename_dialog.get_ok_button().text = "Rename Tag"

	var rename_input: LineEdit = LineEdit.new()
	rename_input.placeholder_text = "New tag path"
	rename_input.clear_button_enabled = true
	rename_input.custom_minimum_size = Vector2(460.0, 0.0)

	var paste_dialog: ConfirmationDialog = ConfirmationDialog.new()
	paste_dialog.title = "Paste Gameplay Tags"
	paste_dialog.dialog_text = (
		"Enter one tag per line. " + "Commas and slashes create hierarchy segments."
	)
	paste_dialog.get_ok_button().text = "Add Tags"

	var paste_input: TextEdit = TextEdit.new()
	paste_input.custom_minimum_size = Vector2(560.0, 280.0)
	paste_input.placeholder_text = "Ability.Jump\nState,Stunned\nDamage/Fire"

	var import_dialog: FileDialog = FileDialog.new()
	import_dialog.access = FileDialog.ACCESS_RESOURCES
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.filters = PackedStringArray(["*.csv ; CSV files"])
	import_dialog.title = "Import Gameplay Tags CSV"

	var export_dialog: FileDialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_RESOURCES
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.csv ; CSV files"])
	export_dialog.title = "Export Gameplay Tags CSV"

	var remove_confirmation: ConfirmationDialog = ConfirmationDialog.new()
	remove_confirmation.title = "Remove Gameplay Tags"

	var controls: Dictionary[String, Node] = {
		"rename_dialog": rename_dialog,
		"rename_input": rename_input,
		"paste_dialog": paste_dialog,
		"paste_input": paste_input,
		"import_dialog": import_dialog,
		"export_dialog": export_dialog,
		"remove_confirmation": remove_confirmation,
	}
	return controls


# Icons and fonts resolve through the dock's own theme context, not EditorInterface:
# the editor theme singleton is unavailable when the dock is built headlessly.
static func _apply_editor_icon(
	theme_source: Control, button: Button, icon_name: StringName
) -> void:
	if theme_source.has_theme_icon(icon_name, "EditorIcons"):
		button.icon = theme_source.get_theme_icon(icon_name, "EditorIcons")
