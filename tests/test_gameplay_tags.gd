@tool
extends McpTestSuite

func suite_name() -> String:
	return "gameplay_tags"

func test_database_normalizes_adds_and_validates_tags() -> void:
	var database := GameplayTagDatabase.new()

	assert_true(database.add_tag(" State.Stunned "), "Should add normalized tag")
	assert_false(database.add_tag("State.Stunned"), "Duplicate tag should not be added")
	assert_true(database.has_tag("State.Stunned"), "Database should contain the exact tag")
	assert_eq(database.validate().size(), 0, "Database should be valid")

	var tag := database.get_tag("State.Stunned")
	assert_true(tag != null, "get_tag should return a GameplayTag resource")
	assert_eq(String(tag.tag_name), "State.Stunned")

func test_database_can_ensure_parents_and_find_children() -> void:
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

func test_container_hierarchical_matching() -> void:
	var container := GameplayTagContainer.new()
	assert_true(container.add("State.Stunned"))
	assert_true(container.add("Team.Enemy"))
	assert_false(container.add("Team.Enemy"), "Duplicate container tags should be rejected")

	assert_true(container.has("State"), "Parent tag should match owned child tag")
	assert_true(container.has("State.Stunned"), "Exact owned tag should match")
	assert_false(container.has_exact("State"), "Parent should not be an exact match")
	assert_true(container.has_exact("Team.Enemy"), "Owned tag should exact match")

func test_container_any_all_and_removal() -> void:
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

func test_query_modes() -> void:
	var container := GameplayTagContainer.new()
	container.add("State.Stunned")
	container.add("Team.Enemy")

	assert_true(GameplayTagQuery.all(["State", "Team.Enemy"]).matches(container), "ALL query should match")
	assert_true(GameplayTagQuery.any(["Damage.Fire", "State"]).matches(container), "ANY query should match")
	assert_true(GameplayTagQuery.none(["State.Invulnerable", "Team.Player"]).matches(container), "NONE query should match absent tags")
	assert_false(GameplayTagQuery.exact_all(["State"]).matches(container), "Exact query should not match parent unless exact tag is owned")
