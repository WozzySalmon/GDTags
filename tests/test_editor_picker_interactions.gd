extends SceneTree

const TagProperty: Script = preload("res://addons/gameplay_tags/editor/gameplay_tag_property.gd")
const TagArrayProperty: Script = preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_array_property.gd"
)


class TagSelectionTarget:
	extends RefCounted

	var tag: StringName = &""
	var tags: Array[StringName] = []


var _assertion_count: int = 0
var _failed: bool = false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var registry: Node = root.get_node_or_null("GameplayTags")
	var owns_registry: bool = false
	if registry == null:
		registry = preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd").new()
		registry.name = "GameplayTags"
		root.add_child(registry)
		owns_registry = true

	var original_database: GameplayTagDatabase = registry.get_database()
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tag(&"State.Stunned")
	registry.set_database(database)

	_test_single_picker_selection()
	_test_array_picker_selection()

	registry.set_database(original_database)
	if owns_registry:
		registry.free()
	if not _failed:
		print("GDSCRIPT_GAMEPLAY_TAGS_PICKER_TEST passed (%d assertions)" % _assertion_count)
		quit(0)


func _test_single_picker_selection() -> void:
	var target: TagSelectionTarget = TagSelectionTarget.new()
	var picker: EditorProperty = TagProperty.new()
	root.add_child(picker)
	picker.set_object_and_property(target, &"tag")
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
		assert_true(
			tree.get_root() == original_root,
			"Single-tag selection must not rebuild its Tree during the selection signal",
		)
	picker.free()


func _test_array_picker_selection() -> void:
	var target: TagSelectionTarget = TagSelectionTarget.new()
	var picker: EditorProperty = TagArrayProperty.new()
	root.add_child(picker)
	picker.set_object_and_property(target, &"tags")
	picker.call("_update_property")

	var tree: Tree = picker.get("_tag_tree")
	var original_root: TreeItem = tree.get_root()
	var item: TreeItem = _find_tree_item(original_root, &"State.Stunned")
	assert_true(item != null, "Array-tag picker should contain the test tag")
	if item != null:
		picker.call("_on_tag_multi_selected", item, 0, true)
		assert_true(
			tree.get_root() == original_root,
			"Array-tag selection must not rebuild its Tree during the selection signal",
		)
	picker.free()


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


func assert_true(condition: bool, message: String) -> void:
	_assertion_count += 1
	if condition or _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
