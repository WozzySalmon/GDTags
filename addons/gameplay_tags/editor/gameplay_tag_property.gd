@tool
extends EditorProperty

const DATABASE_SETTING: String = "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH: String = "res://gameplay_tags_database.tres"
const VALUE_STRING_NAME: int = 0
const VALUE_RESOURCE: int = 1

var value_mode: int = VALUE_STRING_NAME
var _current_tag: StringName = &""
var _updating: bool = false
var _read_only: bool = false
var _summary_button: Button
var _clear_button: Button
var _popup: PopupPanel
var _search_box: LineEdit
var _tag_tree: Tree
var _status_label: Label


func _init() -> void:
	_build_ui()


func _update_property() -> void:
	if _updating:
		return
	_updating = true
	var edited: Object = get_edited_object()
	_current_tag = &""
	if edited != null:
		# get() returns Variant — unavoidable dynamic boundary.
		_current_tag = _tag_from_dynamic_value(edited.get(get_edited_property()))
	_refresh_summary()
	_refresh_popup_list()
	_updating = false


func _set_read_only(read_only: bool) -> void:
	_read_only = read_only
	if _summary_button != null:
		_summary_button.disabled = read_only
	if _clear_button != null:
		_clear_button.disabled = read_only


func _build_ui() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)

	_summary_button = Button.new()
	_summary_button.text = "Pick gameplay tag"
	_summary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_button.pressed.connect(_on_summary_pressed)
	row.add_child(_summary_button)
	add_focusable(_summary_button)

	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.pressed.connect(_on_clear_pressed)
	row.add_child(_clear_button)
	add_focusable(_clear_button)

	_popup = PopupPanel.new()
	_popup.exclusive = false
	add_child(_popup)

	var popup_margin: MarginContainer = MarginContainer.new()
	popup_margin.custom_minimum_size = Vector2(420.0, 380.0)
	popup_margin.add_theme_constant_override("margin_left", 10)
	popup_margin.add_theme_constant_override("margin_top", 10)
	popup_margin.add_theme_constant_override("margin_right", 10)
	popup_margin.add_theme_constant_override("margin_bottom", 10)
	_popup.add_child(popup_margin)

	var popup_root: VBoxContainer = VBoxContainer.new()
	popup_root.add_theme_constant_override("separation", 8)
	popup_margin.add_child(popup_root)

	var heading: Label = Label.new()
	heading.text = "Select Gameplay Tag"
	popup_root.add_child(heading)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search gameplay tags"
	_search_box.clear_button_enabled = true
	_search_box.text_changed.connect(_on_search_changed)
	popup_root.add_child(_search_box)
	add_focusable(_search_box)

	_tag_tree = Tree.new()
	_tag_tree.hide_root = true
	_tag_tree.columns = 1
	_tag_tree.select_mode = Tree.SELECT_SINGLE
	_tag_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tag_tree.item_selected.connect(_on_tree_item_selected)
	popup_root.add_child(_tag_tree)
	add_focusable(_tag_tree)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate.a = 0.8
	popup_root.add_child(_status_label)

	var done_button: Button = Button.new()
	done_button.text = "Done"
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	done_button.pressed.connect(Callable(_popup, "hide"))
	popup_root.add_child(done_button)


func _on_summary_pressed() -> void:
	if _read_only:
		return
	_refresh_popup_list()
	_popup.popup_centered(Vector2i(420, 380))
	_search_box.grab_focus()


func _on_clear_pressed() -> void:
	if _read_only or _current_tag == &"":
		return
	_current_tag = &""
	_emit_current_tag()


func _on_search_changed(_text: String) -> void:
	_refresh_popup_list()


func _on_tree_item_selected() -> void:
	if _updating or _read_only:
		return
	var item: TreeItem = _tag_tree.get_selected()
	if item == null:
		return
	_current_tag = StringName(item.get_metadata(0))
	_emit_current_tag()


func _emit_current_tag() -> void:
	_updating = true
	if value_mode == VALUE_RESOURCE:
		emit_changed(
			get_edited_property(), null if _current_tag == &"" else GameplayTag.new(_current_tag)
		)
	else:
		emit_changed(get_edited_property(), _current_tag)
	_refresh_summary()
	_refresh_popup_list()
	_updating = false


func _refresh_summary() -> void:
	if _summary_button == null:
		return
	_summary_button.text = "Pick gameplay tag" if _current_tag == &"" else String(_current_tag)
	if _clear_button != null:
		_clear_button.disabled = _read_only or _current_tag == &""


func _refresh_popup_list() -> void:
	if _tag_tree == null:
		return
	var was_updating: bool = _updating
	_updating = true
	_tag_tree.clear()
	var database: GameplayTagDatabase = _get_database()
	if database == null:
		_status_label.text = "No GameplayTagDatabase found. Add tags in the Gameplay Tags dock."
		_updating = was_updating
		return
	var known_tags: Array[StringName] = database.find_tags(
		_search_box.text if _search_box != null else ""
	)
	var tree_tags: Array[StringName] = _include_ancestor_tags(database, known_tags)
	var root: TreeItem = _tag_tree.create_item()
	var items_by_tag: Dictionary[StringName, TreeItem] = {}
	for tag in tree_tags:
		var tag_text: String = String(tag)
		var parent_item: TreeItem = root
		var separator_index: int = tag_text.rfind(".")
		if separator_index >= 0:
			var parent_tag: StringName = StringName(tag_text.left(separator_index))
			parent_item = items_by_tag.get(parent_tag, root)
		var item: TreeItem = _tag_tree.create_item(parent_item)
		item.set_text(0, tag_text.get_slice(".", tag_text.get_slice_count(".") - 1))
		item.set_metadata(0, tag)
		var description: String = String(database.tag_descriptions.get(tag_text, ""))
		item.set_tooltip_text(
			0, tag_text if description.is_empty() else "%s\n%s" % [tag_text, description]
		)
		items_by_tag[tag] = item
		if tag == _current_tag:
			item.select(0)
	_status_label.text = _get_status_text(database)
	_updating = was_updating


func _include_ancestor_tags(
	database: GameplayTagDatabase,
	matched_tags: Array[StringName],
) -> Array[StringName]:
	var tree_tags: Array[StringName] = matched_tags.duplicate()
	for tag in matched_tags:
		var parent_text: String = String(tag)
		while parent_text.contains("."):
			parent_text = parent_text.left(parent_text.rfind("."))
			var parent_tag: StringName = StringName(parent_text)
			if database.has_tag(parent_tag) and not tree_tags.has(parent_tag):
				tree_tags.append(parent_tag)
	return GameplayTagDatabase.canonicalize_tag_array(tree_tags)


func _get_status_text(database: GameplayTagDatabase) -> String:
	var status: String = "%d known tags" % database.tags.size()
	if _current_tag != &"" and not database.has_tag(_current_tag):
		status += " · Invalid here: %s" % String(_current_tag)
	return status


# EditorProperty gives us Variant values from Object.get() — unavoidable boundary.
# We convert to StringName here and require callers to provide legit types.
func _tag_from_dynamic_value(value: Variant) -> StringName:
	if value is GameplayTag:
		return value.tag_name
	if value is StringName or value is String:
		return GameplayTagDatabase.normalize_tag(StringName(value))
	return &""


func _get_database() -> GameplayTagDatabase:
	var registry: Node = _get_registry()
	if registry != null and registry.has_method("get_database"):
		return registry.get_database()
	var path: String = String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))
	if ResourceLoader.exists(path):
		return load(path) as GameplayTagDatabase
	return null


func _get_registry() -> Node:
	return GameplayTagUtils.get_registry(self)
