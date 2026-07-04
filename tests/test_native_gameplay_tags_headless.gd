extends SceneTree

const EXTENSION_PATH := "res://addons/gameplay_tags/gameplay_tags.gdextension"


func _init() -> void:
	if not ClassDB.class_exists("NativeGameplayTagDatabase"):
		var load_result := GDExtensionManager.load_extension(EXTENSION_PATH)
		if load_result != OK:
			_fail("Failed to load %s: error %s" % [EXTENSION_PATH, load_result])
			return

	_assert(
		ClassDB.class_exists("NativeGameplayTagDatabase"),
		"NativeGameplayTagDatabase should be registered"
	)
	_assert(
		ClassDB.class_exists("NativeGameplayTagContainer"),
		"NativeGameplayTagContainer should be registered"
	)
	_assert(
		ClassDB.class_exists("NativeGameplayTagQuery"),
		"NativeGameplayTagQuery should be registered"
	)

	var database = ClassDB.instantiate("NativeGameplayTagDatabase")
	_assert(
		database.add_tags([" .State . Stunned..Heavy. ", "Team.Enemy", "Team.Enemy"]) == 2,
		"database should batch-add unique normalized tags"
	)
	_assert(database.ensure_parent_tags(), "database should create parent tags")
	_assert(database.has_tag("State"), "database should contain root parent")
	_assert(database.has_tag("State.Stunned"), "database should contain intermediate parent")
	_assert(
		database.has_tag(" State . Stunned . Heavy "),
		"database lookups should normalize incoming names"
	)
	_assert(
		database.get_child_tags("State", true).size() == 2,
		"database should find recursive children"
	)

	var container = ClassDB.instantiate("NativeGameplayTagContainer")
	_assert(
		container.add_tags([" .State . Stunned. ", "Team.Enemy", "Team.Enemy"]) == 2,
		"container should batch-add unique normalized tags"
	)
	_assert(container.has(" State "), "container should match parent hierarchically")
	_assert(container.has_exact("State.Stunned"), "container should match exact owned tag")
	_assert(not container.has_exact("State"), "container should not exact-match parent")

	var any_query = ClassDB.instantiate("NativeGameplayTagQuery")
	any_query.set_mode(1)  # MODE_ANY
	_assert(
		any_query.add_tags(["Damage.Fire", " State ", " State "]) == 2,
		"query should batch-add unique normalized tags"
	)

	var exact_query = ClassDB.instantiate("NativeGameplayTagQuery")
	exact_query.set_mode(0)  # MODE_ALL
	exact_query.set_exact(true)
	exact_query.add("State")

	_assert(any_query.matches(container), "ANY query should match hierarchy")
	_assert(not exact_query.matches(container), "exact query should not match parent hierarchy")

	var gdscript_container := GameplayTagContainer.new()
	gdscript_container.add("State.Stunned")
	_assert(
		any_query.matches(gdscript_container),
		"native query should also match duck-typed GDScript containers"
	)

	print("NATIVE_SMOKE_TEST passed")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
