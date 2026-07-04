extends SceneTree

var _assertion_count := 0
var _failed := false


func _init() -> void:
	_run_test(
		"database_normalizes_adds_and_validates_tags",
		_test_database_normalizes_adds_and_validates_tags
	)
	_run_test(
		"database_can_ensure_parents_and_find_children",
		_test_database_can_ensure_parents_and_find_children
	)
	_run_test("container_hierarchical_matching", _test_container_hierarchical_matching)
	_run_test(
		"normalization_is_shared_across_runtime_types",
		_test_normalization_is_shared_across_runtime_types
	)
	_run_test("container_any_all_and_removal", _test_container_any_all_and_removal)
	_run_test("batch_apis", _test_batch_apis)
	_run_test("query_modes", _test_query_modes)

	if not _failed:
		print("GDSCRIPT_GAMEPLAY_TAGS_TEST passed (%d assertions)" % _assertion_count)
		quit(0)


func _run_test(test_name: String, test_callable: Callable) -> void:
	if _failed:
		return
	test_callable.call()
	if not _failed:
		print("PASS %s" % test_name)


func _test_database_normalizes_adds_and_validates_tags() -> void:
	var database := GameplayTagDatabase.new()

	assert_true(database.add_tag(" State.Stunned "), "Should add normalized tag")
	assert_false(database.add_tag("State.Stunned"), "Duplicate tag should not be added")
	assert_true(database.has_tag("State.Stunned"), "Database should contain the exact tag")
	assert_eq(database.validate().size(), 0, "Database should be valid")

	var tag := database.get_tag("State.Stunned")
	assert_true(tag != null, "get_tag should return a GameplayTag resource")
	assert_eq(String(tag.tag_name), "State.Stunned")


func _test_database_can_ensure_parents_and_find_children() -> void:
	var database := GameplayTagDatabase.new()
	database.add_tag("State.Stunned.Heavy")
	assert_true(database.ensure_parent_tags(), "Should add missing parent tags")

	assert_true(database.has_tag("State"), "Should create root parent")
	assert_true(database.has_tag("State.Stunned"), "Should create intermediate parent")

	var direct_children := database.get_children("State", false)
	assert_eq(direct_children.size(), 1, "State should have one direct child")
	assert_eq(String(direct_children[0].tag_name), "State.Stunned")

	var recursive_children := database.get_children("State", true)
	assert_eq(recursive_children.size(), 2, "State should have two recursive children")


func _test_container_hierarchical_matching() -> void:
	var container := GameplayTagContainer.new()
	assert_true(container.add("State.Stunned"))
	assert_true(container.add("Team.Enemy"))
	assert_false(container.add("Team.Enemy"), "Duplicate container tags should be rejected")

	assert_true(container.has("State"), "Parent tag should match owned child tag")
	assert_true(container.has("State.Stunned"), "Exact owned tag should match")
	assert_false(container.has_exact("State"), "Parent should not be an exact match")
	assert_true(container.has_exact("Team.Enemy"), "Owned tag should exact match")


func _test_normalization_is_shared_across_runtime_types() -> void:
	var database := GameplayTagDatabase.new()
	assert_true(
		database.add_tag(" .State . Stunned..Heavy. "), "Database should add normalized tag"
	)
	assert_true(database.has_tag("State.Stunned.Heavy"), "Database should use canonical tag names")

	var tag := database.get_tag(" State . Stunned . Heavy ")
	assert_true(tag != null, "Database lookup should normalize incoming names")
	assert_true(
		tag.matches(" .State . Stunned..Heavy. ", true),
		"GameplayTag matching should normalize requested names"
	)

	var container := GameplayTagContainer.new()
	assert_true(container.add(" .State . Stunned..Heavy. "), "Container should add normalized tag")
	assert_true(
		container.has(" State . Stunned "),
		"Container hierarchy checks should normalize requested names"
	)
	assert_true(
		container.has_exact("State.Stunned.Heavy"),
		"Container exact checks should use canonical tag names"
	)

	var query := GameplayTagQuery.all([" State . Stunned "])
	assert_true(query.matches(container), "Query tags should normalize before matching containers")


func _test_container_any_all_and_removal() -> void:
	var container := GameplayTagContainer.new()
	container.add("Damage.Fire")
	container.add("Team.Enemy")

	var any_tags := GameplayTagContainer.new()
	any_tags.add("State.Stunned")
	any_tags.add("Damage")

	var all_tags := GameplayTagContainer.new()
	all_tags.add("Damage")
	all_tags.add("Team.Enemy")

	assert_true(container.has_any(any_tags), "has_any should use hierarchical matching")
	assert_true(container.has_all(all_tags), "has_all should use hierarchical matching")
	assert_true(container.remove("Damage.Fire"))
	assert_false(container.has("Damage"), "Removed child should stop parent match")


func _test_batch_apis() -> void:
	var database := GameplayTagDatabase.new()
	assert_eq(
		database.add_tags(["State.Stunned", "State.Stunned", " Team.Enemy ", ""]),
		2,
		"Database should add unique normalized tags in one call"
	)
	assert_true(database.has_tag("State.Stunned"))
	assert_true(database.has_tag("Team.Enemy"))
	assert_eq(
		database.remove_tags(["State.Stunned", "Missing.Tag"]),
		1,
		"Database should remove existing tags in one call"
	)
	assert_false(database.has_tag("State.Stunned"))

	var container := GameplayTagContainer.new()
	assert_eq(
		container.add_tags(["Damage.Fire", "Damage.Fire", "State.Stunned"]),
		2,
		"Container should add unique tags in one call"
	)
	assert_true(container.has_any(["Damage", "Team.Player"]))
	assert_eq(container.remove_tags(["Damage.Fire", "Missing.Tag"]), 1)
	assert_false(container.has("Damage"))

	var query := GameplayTagQuery.any([])
	assert_eq(query.add_tags(["State", "State", "Damage.Fire"]), 2)
	assert_true(query.matches(container), "Batch-built query should match container")
	assert_eq(query.remove_tags(["State", "Missing.Tag"]), 1)
	assert_false(query.matches(container), "Removed query tag should stop matching")


func _test_query_modes() -> void:
	var container := GameplayTagContainer.new()
	container.add("State.Stunned")
	container.add("Team.Enemy")

	assert_true(
		GameplayTagQuery.all(["State", "Team.Enemy"]).matches(container), "ALL query should match"
	)
	assert_true(
		GameplayTagQuery.any(["Damage.Fire", "State"]).matches(container), "ANY query should match"
	)
	assert_true(
		GameplayTagQuery.none(["State.Invulnerable", "Team.Player"]).matches(container),
		"NONE query should match absent tags"
	)
	assert_false(
		GameplayTagQuery.exact_all(["State"]).matches(container),
		"Exact query should not match parent unless exact tag is owned"
	)


func assert_true(condition: bool, message: String = "Expected condition to be true") -> void:
	_assertion_count += 1
	if not condition:
		_fail(message)


func assert_false(condition: bool, message: String = "Expected condition to be false") -> void:
	_assertion_count += 1
	if condition:
		_fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertion_count += 1
	if actual != expected:
		var prefix := "%s: " % message if not message.is_empty() else ""
		_fail("%sexpected %s, got %s" % [prefix, str(expected), str(actual)])


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
