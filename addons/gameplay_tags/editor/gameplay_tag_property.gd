@tool
extends EditorProperty

const DATABASE_SETTING := "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const VALUE_STRING_NAME := 0
const VALUE_RESOURCE := 1

var value_mode := VALUE_STRING_NAME
var _current_tag: StringName = &""
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
	_current_tag = &""
	if edited != null:
		_current_tag = _tag_from_value(edited.get(get_edited_property()))
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
	var row := HBoxContainer.new()
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

	var popup_root := VBoxContainer.new()
	popup_root.custom_minimum_size = Vector2(420.0, 380.0)
	_popup.add_child(popup_root)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search central Gameplay Tags database"
	_search_box.text_changed.connect(_on_search_changed)
	popup_root.add_child(_search_box)
	add_focusable(_search_box)

	_tag_list = ItemList.new()
	_tag_list.select_mode = ItemList.SELECT_SINGLE
	_tag_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tag_list.item_selected.connect(_on_item_selected)
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
	_popup.popup_centered(Vector2i(420, 380))
	_search_box.grab_focus()


func _on_clear_pressed() -> void:
	if _read_only or _current_tag == &"":
		return
	_current_tag = &""
	_emit_current_tag()


func _on_search_changed(_text: String) -> void:
	_refresh_popup_list()


func _on_item_selected(index: int) -> void:
	if _updating or _read_only or index < 0 or index >= _visible_tags.size():
		return
	_current_tag = _visible_tags[index]
	_emit_current_tag()


func _emit_current_tag() -> void:
	_updating = true
	emit_changed(get_edited_property(), _value_from_current_tag())
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
		if tag == _current_tag:
			_tag_list.select(item_index)

	_status_label.text = _get_status_text(database)
	_updating = was_updating


func _get_status_text(database: GameplayTagDatabase) -> String:
	var status := "%d known tags" % database.tags.size()
	if _current_tag != &"" and not database.has_tag(_current_tag):
		status += " · Invalid here: %s" % String(_current_tag)
	return status


func _tag_from_value(value: Variant) -> StringName:
	if value is GameplayTag:
		return value.tag_name
	return GameplayTagDatabase.normalize_tag(value)


func _value_from_current_tag() -> Variant:
	if value_mode == VALUE_RESOURCE:
		if _current_tag == &"":
			return null
		return GameplayTag.new(_current_tag)
	return _current_tag


func _get_database() -> GameplayTagDatabase:
	var registry := _get_registry()
	if registry != null and registry.has_method("get_database"):
		return registry.get_database()

	var path := String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))
	if ResourceLoader.exists(path):
		return load(path) as GameplayTagDatabase
	return null


func _get_registry() -> Node:
	return GameplayTagUtils.get_registry(self)
