@tool
extends VBoxContainer

const DATABASE_SETTING := "gameplay_tags/database_path"
const TAG_IDS_SETTING := "gameplay_tags/generated_tag_ids_path"
const DEFAULT_DATABASE_PATH := "res://gameplay_tags_database.tres"
const DEFAULT_TAG_IDS_PATH := "res://gameplay_tag_ids.gd"
const TagCodeGenerator := preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_code_generator.gd"
)

var _database: GameplayTagDatabase
var _tag_list: ItemList
var _search_input: LineEdit
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
	path_label.text = (
		"Database: %s\nCode constants: %s" % [_get_database_path(), _get_tag_ids_path()]
	)
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(path_label)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search tags"
	_search_input.text_changed.connect(_on_search_changed)
	add_child(_search_input)

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
	_description_input.text_submitted.connect(_on_tag_submitted)
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

	var regenerate_button := Button.new()
	regenerate_button.text = "Regenerate IDs"
	regenerate_button.pressed.connect(_on_regenerate_pressed)
	buttons.add_child(regenerate_button)

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
		_database = GameplayTagDatabase.new()
		_database.resource_path = path
		_save_database()


func _refresh() -> void:
	if _tag_list == null:
		return

	_tag_list.clear()
	_selected_tag = &""
	_remove_button.disabled = true

	if _database == null:
		_set_status("No gameplay tag database loaded.")
		return

	var visible_tags := _database.find_tags(_search_input.text if _search_input != null else "")
	for tag in visible_tags:
		var index := _tag_list.add_item(String(tag))
		_tag_list.set_item_metadata(index, tag)
		_tag_list.set_item_tooltip(index, String(_database.tag_descriptions.get(String(tag), "")))

	_set_status("%d visible / %d total tags." % [visible_tags.size(), _database.tags.size()])


func _on_add_pressed() -> void:
	if _database == null:
		_load_database()

	var tag_text := _tag_input.text.strip_edges()
	if tag_text.is_empty():
		_set_status("Enter a tag name first.")
		return

	var added := false
	var registry := _get_registry()
	if registry != null and registry.has_method("add_tag"):
		added = bool(registry.add_tag(tag_text, _description_input.text.strip_edges()))
		_database = registry.get_database()
		if added and not _save_tag_ids_script():
			return
	else:
		added = _database.add_tag(tag_text, _description_input.text.strip_edges())
		if added and not _save_database():
			return

	if not added:
		_set_status("Tag already exists or is invalid: %s" % tag_text)
		return

	_tag_input.clear()
	_description_input.clear()
	_refresh()
	_set_status("Added %s" % String(GameplayTagDatabase.normalize_tag(tag_text)))


func _on_remove_pressed() -> void:
	if _database == null or _selected_tag == &"":
		return

	var removed := false
	var registry := _get_registry()
	if registry != null and registry.has_method("remove_tag"):
		removed = bool(registry.remove_tag(_selected_tag, true))
		_database = registry.get_database()
		if removed and not _save_tag_ids_script():
			return
	else:
		removed = _database.remove_tag(_selected_tag, true)
		if removed and not _save_database():
			return

	if removed:
		_refresh()
		_set_status("Removed %s and its children." % String(_selected_tag))


func _on_refresh_pressed() -> void:
	_load_database()
	_refresh()


func _on_regenerate_pressed() -> void:
	if _save_tag_ids_script():
		_set_status("Regenerated %s" % _get_tag_ids_path())


func _on_search_changed(_text: String) -> void:
	_refresh()


func _on_tag_submitted(_text: String) -> void:
	_on_add_pressed()


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _tag_list.get_item_count():
		_selected_tag = &""
		_remove_button.disabled = true
		return

	_selected_tag = _tag_list.get_item_metadata(index)
	_remove_button.disabled = false


func _save_database() -> bool:
	var path := _get_database_path()
	var directory_error := _ensure_database_directory(path)
	if directory_error != OK:
		_set_status("Could not create database directory: %s" % error_string(directory_error))
		return false
	var err := ResourceSaver.save(_database, path)
	if err != OK:
		_set_status("Could not save database: %s" % error_string(err))
		return false
	return _save_tag_ids_script()


func _save_tag_ids_script() -> bool:
	if _database == null:
		return false
	var path := _get_tag_ids_path()
	var err := TagCodeGenerator.save_tag_ids(_database, path)
	if err != OK:
		_set_status("Could not generate GameplayTagIds: %s" % error_string(err))
		return false
	TagCodeGenerator.refresh_editor_filesystem()
	return true


func _ensure_database_directory(path: String) -> Error:
	var directory := path.get_base_dir()
	if directory.is_empty() or directory == "res://" or directory == "user://":
		return OK
	return DirAccess.make_dir_recursive_absolute(directory)


func _get_database_path() -> String:
	return String(ProjectSettings.get_setting(DATABASE_SETTING, DEFAULT_DATABASE_PATH))


func _get_tag_ids_path() -> String:
	return String(ProjectSettings.get_setting(TAG_IDS_SETTING, DEFAULT_TAG_IDS_PATH))


func _get_registry() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameplayTags")


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
