@tool
extends EditorProperty

const DATABASE_SETTING := "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"

var _current_tags: Array[StringName] = []
var _visible_tags: Array[StringName] = []
var _updating := false
var _read_only := false

var _summary_button: Button
var _clear_button: Button
var _popup: PopupPanel
var _search_box: LineEdit
var _tag_list: ItemList
var _status_label: Label


func _init() -> void:
	_build_ui()


func _update_property() -> void:
	if _updating:
		return
	_updating = true
	var edited := get_edited_object()
	if edited != null:
		_current_tags = _canonicalize(edited.get(get_edited_property()))
	_refresh_summary()
	_refresh_popup_list()
	_updating = false


func _set_read_only(read_only: bool) -> void:
	_read_only = read_only
	if _summary_button != null:
		_summary_button.disabled = read_only
	if _clear_button != null:
		_clear_button.disabled = read_only
	if _tag_list != null:
		_tag_list.allow_rmb_select = not read_only


func _build_ui() -> void:
	var row := HBoxContainer.new()
	add_child(row)

	_summary_button = Button.new()
	_summary_button.text = "Pick gameplay tags"
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

	var popup_root := VBoxContainer.new()
	popup_root.custom_minimum_size = Vector2(460.0, 420.0)
	_popup.add_child(popup_root)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search central Gameplay Tags database"
	_search_box.text_changed.connect(_on_search_changed)
	popup_root.add_child(_search_box)
	add_focusable(_search_box)

	_tag_list = ItemList.new()
	_tag_list.select_mode = ItemList.SELECT_MULTI
	_tag_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tag_list.multi_selected.connect(_on_tag_multi_selected)
	popup_root.add_child(_tag_list)
	add_focusable(_tag_list)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_root.add_child(_status_label)

	var done_button := Button.new()
	done_button.text = "Done"
	done_button.pressed.connect(Callable(_popup, "hide"))
	popup_root.add_child(done_button)


func _on_summary_pressed() -> void:
	if _read_only:
		return
	_refresh_popup_list()
	_popup.popup_centered(Vector2i(460, 420))
	_search_box.grab_focus()


func _on_clear_pressed() -> void:
	if _read_only or _current_tags.is_empty():
		return
	_current_tags.clear()
	_emit_current_tags()


func _on_search_changed(_text: String) -> void:
	_refresh_popup_list()


func _on_tag_multi_selected(index: int, selected: bool) -> void:
	if _updating or _read_only or index < 0 or index >= _visible_tags.size():
		return

	var tag := _visible_tags[index]
	if selected:
		if not _current_tags.has(tag):
			_current_tags.append(tag)
	else:
		_current_tags.erase(tag)
	_current_tags = GameplayTagDatabase.canonicalize_tag_array(_current_tags)
	_emit_current_tags()


func _emit_current_tags() -> void:
	_updating = true
	emit_changed(get_edited_property(), _current_tags.duplicate())
	_refresh_summary()
	_refresh_popup_list()
	_updating = false


func _refresh_summary() -> void:
	if _summary_button == null:
		return
	if _current_tags.is_empty():
		_summary_button.text = "Pick gameplay tags"
	else:
		_summary_button.text = ", ".join(_to_string_array(_current_tags))
	if _clear_button != null:
		_clear_button.disabled = _read_only or _current_tags.is_empty()


func _refresh_popup_list() -> void:
	if _tag_list == null:
		return

	var was_updating := _updating
	_updating = true
	_tag_list.clear()
	_visible_tags.clear()

	var database := _get_database()
	if database == null:
		_status_label.text = "No GameplayTagDatabase found. Add tags in the Gameplay Tags dock."
		_updating = was_updating
		return

	var known_tags := database.find_tags(_search_box.text if _search_box != null else "")
	for tag in known_tags:
		_visible_tags.append(tag)
		var item_index := _tag_list.add_item(String(tag))
		_tag_list.set_item_tooltip(
			item_index, String(database.tag_descriptions.get(String(tag), ""))
		)
		if _current_tags.has(tag):
			_tag_list.select(item_index, false)

	var invalid_tags := _get_invalid_current_tags(database)
	var status := "%d known tags" % database.tags.size()
	if not invalid_tags.is_empty():
		status += " · Invalid here: %s" % ", ".join(_to_string_array(invalid_tags))
	_status_label.text = status
	_updating = was_updating


func _get_database() -> GameplayTagDatabase:
	var registry := _get_registry()
	if registry != null and registry.has_method("get_database"):
		return registry.get_database()

	var path := String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))
	if ResourceLoader.exists(path):
		return load(path) as GameplayTagDatabase
	return null


func _get_registry() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameplayTags")


func _get_invalid_current_tags(database: GameplayTagDatabase) -> Array[StringName]:
	var invalid: Array[StringName] = []
	for tag in _current_tags:
		if not database.has_tag(tag):
			invalid.append(tag)
	return invalid


func _canonicalize(value: Variant) -> Array[StringName]:
	if value is GameplayTagContainer:
		return value.get_tags()
	if value is Array:
		return GameplayTagDatabase.canonicalize_tag_array(value)
	return []


func _to_string_array(source_tags: Array) -> Array[String]:
	var result: Array[String] = []
	for tag in source_tags:
		result.append(String(tag))
	return result
