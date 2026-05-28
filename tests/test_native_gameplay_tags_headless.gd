extends SceneTree

const EXTENSION_PATH := "res://addons/gameplay_tags/gameplay_tags.gdextension"

func _init() -> void:
	if not ClassDB.class_exists("NativeGameplayTagDatabase"):
		var load_result := GDExtensionManager.load_extension(EXTENSION_PATH)
		if load_result != OK:
			_fail("Failed to load %s: error %s" % [EXTENSION_PATH, load_result])
			return

	_assert(ClassDB.class_exists("NativeGameplayTagDatabase"), "NativeGameplayTagDatabase should be registered")
	_assert(ClassDB.class_exists("NativeGameplayTagContainer"), "NativeGameplayTagContainer should be registered")
	_assert(ClassDB.class_exists("NativeGameplayTagQuery"), "NativeGameplayTagQuery should be registered")

	var database = ClassDB.instantiate("NativeGameplayTagDatabase")
	_assert(database.add_tag(" State.Stunned.Heavy "), "database should add normalized child tag")
	_assert(database.ensure_parent_tags(), "database should create parent tags")
	_assert(database.has_tag("State"), "database should contain root parent")
	_assert(database.has_tag("State.Stunned"), "database should contain intermediate parent")
	_assert(database.get_child_tags("State", true).size() == 2, "database should find recursive children")

	var container = ClassDB.instantiate("NativeGameplayTagContainer")
	_assert(container.add("State.Stunned"), "container should add tag")
	_assert(container.add("Team.Enemy"), "container should add second tag")
	_assert(container.has("State"), "container should match parent hierarchically")
	_assert(container.has_exact("State.Stunned"), "container should match exact owned tag")
	_assert(not container.has_exact("State"), "container should not exact-match parent")

	var any_query = NativeGameplayTagQuery.any(["Damage.Fire", "State"])
	var exact_query = NativeGameplayTagQuery.exact_all(["State"])
	_assert(any_query.matches(container), "ANY query should match hierarchy")
	_assert(not exact_query.matches(container), "exact query should not match parent hierarchy")

	print("NATIVE_SMOKE_TEST passed")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
