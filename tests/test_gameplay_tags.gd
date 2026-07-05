extends SceneTree


class TaggedObject:
	extends RefCounted

	var owned_tags: Array[StringName] = []

	func get_owned_gameplay_tags() -> Array[StringName]:
		return owned_tags


const GameplayTagsScript := preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")

var _assertion_count := 0
var _failed := false
var _previous_database: GameplayTagDatabase
var _registry


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	_registry = _get_or_create_registry()
	_previous_database = _registry.get_database()
	_registry.set_database(_make_test_database())

	_run_test("database_normalizes_parents_and_searches", _test_database)
	_run_test("container_hierarchical_matching", _test_container)
	_run_test("component_target_helpers", _test_component_target_helpers)
	_run_test("plain_object_target_helpers", _test_plain_object_target_helpers)
	_run_test("query_modes", _test_query_modes)
	_run_test("area3d_trigger_helper", _test_area3d_trigger_helper)

	_registry.set_database(_previous_database)
	if not _failed:
		print("GDSCRIPT_GAMEPLAY_TAGS_TEST passed (%d assertions)" % _assertion_count)
		quit(0)


func _get_or_create_registry():
	var existing := root.get_node_or_null("GameplayTags")
	if existing != null:
		return existing

	var registry := GameplayTagsScript.new()
	registry.name = "GameplayTags"
	root.add_child(registry)
	return registry


func _make_test_database() -> GameplayTagDatabase:
	var database := GameplayTagDatabase.new()
	(
		database
		. add_tags(
			[
				"Ability.Cooldown",
				"Damage.Fire",
				"State.Stunned",
				"State.Invulnerable",
				"Team.Enemy",
				"Team.Player",
			]
		)
	)
	return database


func _run_test(test_name: String, test_callable: Callable) -> void:
	if _failed:
		return
	test_callable.call()
	if not _failed:
		print("PASS %s" % test_name)


func _test_database() -> void:
	var database := GameplayTagDatabase.new()

	assert_true(database.add_tag(" State.Stunned.Heavy "))
	assert_true(database.has_tag("State"), "Adding a child should create root parent")
	assert_true(database.has_tag("State.Stunned"), "Adding a child should create middle parent")
	assert_false(database.add_tag("State.Stunned.Heavy"), "Duplicate tag should fail")
	assert_false(
		database.remove_tag("State", false), "Non-recursive remove should protect children"
	)
	assert_eq(database.validate().size(), 0, "Database should validate")
	assert_eq(database.find_tags("stun").size(), 2, "Search should find parent and child")

	var orphan_database := GameplayTagDatabase.new()
	orphan_database.tags = [&"State.Stunned"]
	assert_eq(orphan_database.validate().size(), 1, "Database should report missing parents")

	var tag := database.get_tag("State.Stunned.Heavy")
	assert_true(tag != null, "get_tag should return a GameplayTag")
	assert_true(tag.matches("State.Stunned"), "GameplayTag should use hierarchical matching")


func _test_container() -> void:
	var container := GameplayTagContainer.new()
	assert_true(container.add_tag("State.Stunned"))
	assert_true(container.add_tag("Team.Enemy"))
	assert_false(container.add_tag("Team.Enemy"), "Duplicate container tag should fail")

	assert_true(container.has_tag("State"), "Parent query should match owned child")
	assert_true(container.has_exact("Team.Enemy"), "Exact owned tag should match")
	assert_false(container.has_exact("State"), "Parent should not exact-match child")
	assert_true(container.has_all(["State", "Team.Enemy"]))
	assert_true(container.has_any(["Damage", "Team"]))


func _test_component_target_helpers() -> void:
	var actor := Node.new()
	var component := GameplayTagComponent.new()
	actor.add_child(component)
	root.add_child(actor)

	assert_true(
		GameplayTagIds.all().has(GameplayTagIds.TEAM_PLAYER),
		"Generated tag IDs should expose database constants"
	)
	assert_true(component.add_tag(GameplayTagIds.TEAM_ENEMY), "Registered DB tags can be assigned")
	assert_false(component.add_tag("Missing.Tag"), "Component rejects tags outside central DB")
	component.owned_tags = [&"Missing.Tag"]
	assert_false(
		_registry.target_has_tag(component, "Missing"),
		"Direct property assignment should reject unregistered tags"
	)
	component.set_owned_gameplay_tags([GameplayTagIds.TEAM_ENEMY, &"Missing.Tag"])
	assert_false(
		_registry.target_has_tag(component, "Missing"),
		"Direct component assignment should reject unregistered tags"
	)
	assert_true(
		_registry.target_has_tag(actor, GameplayTagIds.TEAM),
		"Actor child component should be found"
	)
	assert_true(_registry.target_has_tag(component, GameplayTagIds.TEAM_ENEMY, true))
	assert_false(_registry.target_has_tag(actor, "Team", true), "Exact parent should fail")

	var owned: GameplayTagContainer = _registry.get_owned_gameplay_tags(actor)
	assert_true(owned.has_tag("Team.Enemy", true), "Owned tags should come back as a container")
	actor.free()


func _test_plain_object_target_helpers() -> void:
	var tagged_object := TaggedObject.new()
	tagged_object.owned_tags = [&"State.Stunned"]

	assert_true(_registry.target_has_tag(tagged_object, "State"))
	assert_true(_registry.target_has_all(tagged_object, ["State.Stunned"]))
	assert_false(_registry.target_has_any(tagged_object, ["Team.Enemy", "Damage.Fire"]))


func _test_query_modes() -> void:
	var component := GameplayTagComponent.new()
	root.add_child(component)
	component.add_tag("State.Stunned")
	component.add_tag("Team.Enemy")

	assert_true(GameplayTagQuery.all(["State", "Team.Enemy"]).matches(component))
	assert_true(GameplayTagQuery.any(["Damage.Fire", "State"]).matches(component))
	assert_true(GameplayTagQuery.none(["State.Invulnerable", "Team.Player"]).matches(component))
	assert_false(GameplayTagQuery.exact_all(["State"]).matches(component))
	component.free()


func _test_area3d_trigger_helper() -> void:
	var actor := Node3D.new()
	var component := GameplayTagComponent.new()
	actor.add_child(component)
	root.add_child(actor)
	component.add_tag("Team.Enemy")

	var trigger := GameplayTagTrigger3D.new()
	root.add_child(trigger)
	trigger.required_tags = [&"Team.Enemy"]
	assert_true(trigger.can_trigger(actor), "Trigger should accept matching tagged target")

	trigger.required_tags = [&"Team.Player"]
	assert_false(trigger.can_trigger(actor), "Trigger should reject non-matching target")

	trigger.required_tags = [&"Team"]
	trigger.exact_match = true
	assert_false(trigger.can_trigger(actor), "Exact trigger should not match parent")

	actor.free()
	trigger.free()


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
	if _registry != null:
		_registry.set_database(_previous_database)
	quit(1)
