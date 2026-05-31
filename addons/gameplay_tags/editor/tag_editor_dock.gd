@tool
extends VBoxContainer

const DATABASE_SETTING := "gameplay_tags/database_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const GameplayTagDatabaseScript := preload(
	"res://addons/gameplay_tags/resources/gameplay_tag_database.gd"
)

var _database: GameplayTagDatabase
var _tag_list: ItemList
var _tag_input: LineEdit
var _description_input: LineEdit
var _status_label: Label
var _remove_button: Button
var _selected_tag: StringName = &""


func _ready() -> void:
	_build_ui()
	_load_database()
	_refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Gameplay Tags"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var path_label := Label.new()
	path_label.text = "Database: %s" % _get_database_path()
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(path_label)

	_tag_list = ItemList.new()
	_tag_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tag_list.item_selected.connect(_on_item_selected)
	add_child(_tag_list)

	_tag_input = LineEdit.new()
	_tag_input.placeholder_text = "State.Stunned"
	_tag_input.text_submitted.connect(_on_tag_submitted)
	add_child(_tag_input)

	_description_input = LineEdit.new()
	_description_input.placeholder_text = "Optional description"
	add_child(_description_input)

	var buttons := HBoxContainer.new()
	add_child(buttons)

	var add_button := Button.new()
	add_button.text = "Add"
	add_button.pressed.connect(_on_add_pressed)
	buttons.add_child(add_button)

	_remove_button = Button.new()
	_remove_button.text = "Remove"
	_remove_button.disabled = true
	_remove_button.pressed.connect(_on_remove_pressed)
	buttons.add_child(_remove_button)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_on_refresh_pressed)
	buttons.add_child(refresh_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)


func _load_database() -> void:
	var registry := _get_registry()
	if registry != null and registry.has_method("get_database"):
		_database = registry.get_database()
		return

	var path := _get_database_path()
	if ResourceLoader.exists(path):
		_database = load(path) as GameplayTagDatabase

	if _database == null:
		_database = GameplayTagDatabaseScript.new()
		_save_database()


func _get_registry() -> Node:
	return get_node_or_null("/root/GameplayTags")


func _refresh() -> void:
	if _tag_list == null:
		return

	_tag_list.clear()
	_selected_tag = &""
	_remove_button.disabled = true

	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return

	for tag in _database.tags:
		var index := _tag_list.add_item(String(tag))
		var description := String(_database.tag_descriptions.get(String(tag), ""))
		if not description.is_empty():
			_tag_list.set_item_tooltip(index, description)

	_set_status("%d tags loaded." % _database.tags.size())


func _on_add_pressed() -> void:
	if _database == null:
		_load_database()

	var tag_text := _tag_input.text.strip_edges()
	if tag_text.is_empty():
		_set_status("Enter a tag name first.")
		return

	var description := _description_input.text.strip_edges()
	var registry := _get_registry()
	var added := false

	if registry != null and registry.has_method("add_tag"):
		added = bool(registry.add_tag(tag_text, description))
		if added and registry.has_method("ensure_parent_tags"):
			registry.ensure_parent_tags()
		if registry.has_method("get_database"):
			_database = registry.get_database()
	else:
		added = _database.add_tag(tag_text, description)
		if added:
			_database.ensure_parent_tags()
			_save_database()

	if added:
		_tag_input.clear()
		_description_input.clear()
		_refresh()
		_set_status("Added %s" % tag_text)
	else:
		_set_status("Tag already exists or is invalid: %s" % tag_text)


func _on_remove_pressed() -> void:
	if _database == null or _selected_tag == &"":
		return

	var registry := _get_registry()
	var removed := false
	if registry != null and registry.has_method("remove_tag"):
		removed = bool(registry.remove_tag(_selected_tag, true))
		if registry.has_method("get_database"):
			_database = registry.get_database()
	else:
		removed = _database.remove_tag(_selected_tag, true)
		if removed:
			_save_database()

	if removed:
		_refresh()
		_set_status("Removed %s and its children." % String(_selected_tag))


func _on_refresh_pressed() -> void:
	_load_database()
	_refresh()


func _on_tag_submitted(_text: String) -> void:
	_on_add_pressed()


func _on_item_selected(index: int) -> void:
	if _database == null or index < 0 or index >= _database.tags.size():
		_selected_tag = &""
		_remove_button.disabled = true
		return

	_selected_tag = _database.tags[index]
	_remove_button.disabled = false


func _save_database() -> void:
	var err := ResourceSaver.save(_database, _get_database_path())
	if err != OK:
		_set_status("Could not save database: %s" % error_string(err))


func _get_database_path() -> String:
	return String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
