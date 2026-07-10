extends SceneTree


class TaggedObject:
	extends RefCounted

	var owned_tags: Array[StringName] = []

	func get_owned_gameplay_tags() -> Array[StringName]:
		return owned_tags


class MethodTaggedObject:
	extends RefCounted

	var owned_tags: Array[StringName] = []
	var method_tags: Array[StringName] = []

	func get_owned_gameplay_tags() -> Array[StringName]:
		return method_tags


const GameplayTagsScript := preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")
const TagCodeGenerator := preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_code_generator.gd"
)

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
	_run_test("generated_id_collisions_are_rejected", _test_generated_id_collisions)
	_run_test("container_hierarchical_matching", _test_container)
	_run_test("component_target_helpers", _test_component_target_helpers)
	_run_test("direct_node_tags_and_csv", _test_direct_node_tags_and_csv)
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


func _test_generated_id_collisions() -> void:
	var database := GameplayTagDatabase.new()
	database.add_tag(&"Foo_Bar")
	database.add_tag(&"Foo-Bar")

	var collisions := TagCodeGenerator.get_constant_name_collisions(database)
	assert_eq(collisions.size(), 1, "Generated ID collisions should be detected")
	assert_eq(collisions[0]["name"], "FOO_BAR")
	assert_eq(collisions[0]["tags"].size(), 2)


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
	assert_true(container.all(["State", "Team.Enemy"]), "GDTag-style all alias should work")
	assert_true(container.any(["Damage", "Team"]), "GDTag-style any alias should work")
	assert_true(container.none(["Damage.Ice"]), "Container none helper should reject overlaps")
	assert_eq(container.overlap_count(["State", "Team.Enemy"]), 2)
	assert_true(container.exact([GameplayTagIds.STATE_STUNNED, GameplayTagIds.TEAM_ENEMY]))
	assert_false(container.exact([GameplayTagIds.STATE, GameplayTagIds.TEAM_ENEMY]))
	assert_true(container.remove_tag(GameplayTagIds.TEAM_ENEMY))
	assert_false(container.has_exact(GameplayTagIds.TEAM_ENEMY))
	container.clear()
	assert_true(container.is_empty(), "Container clear should remove all tags")


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


func _test_direct_node_tags_and_csv() -> void:
	var actor := Node.new()
	root.add_child(actor)

	assert_eq(
		_registry.add_tags_to_node(actor, [GameplayTagIds.TEAM_PLAYER, &"Missing.Tag"]),
		1,
		"Direct node tags should validate against the central DB"
	)
	assert_true(actor.is_in_group("gameplay_tagged_nodes"))
	assert_true(_registry.target_has_tag(actor, GameplayTagIds.TEAM))

	var component := GameplayTagComponent.new()
	actor.add_child(component)
	component.add_tag(GameplayTagIds.STATE_STUNNED)
	assert_true(
		_registry.target_has_all(actor, [GameplayTagIds.TEAM_PLAYER, GameplayTagIds.STATE_STUNNED]),
		"Direct node tags and child component tags should combine"
	)

	var tagged_nodes: Array[Node] = _registry.get_nodes_with_tag(root, GameplayTagIds.TEAM_PLAYER)
	assert_true(tagged_nodes.has(actor), "Node tag group lookup should find direct tags")
	var component_nodes: Array[Node] = _registry.get_nodes_with_tag(
		root, GameplayTagIds.STATE_STUNNED
	)
	assert_true(component_nodes.has(actor), "Node tag group lookup should find component owners")
	assert_true(_registry.remove_tag_from_node(actor, GameplayTagIds.TEAM_PLAYER))
	assert_false(actor.is_in_group("gameplay_tagged_nodes"))
	actor.free()

	var database := GameplayTagDatabase.new()
	assert_eq(database.add_tags_from_csv_text("Ability,Dash\nDamage/Ice\n"), 2)
	assert_true(database.has_tag("Ability"), "CSV import should create parent tags")
	assert_true(database.has_tag("Damage.Ice"), "CSV import should normalize slash paths")
	assert_true(database.to_csv_text().contains("Ability.Dash"))


func _test_plain_object_target_helpers() -> void:
	var tagged_object := TaggedObject.new()
	tagged_object.owned_tags = [GameplayTagIds.STATE_STUNNED]

	assert_true(_registry.target_has_tag(tagged_object, GameplayTagIds.STATE))
	assert_true(_registry.target_has_all(tagged_object, [GameplayTagIds.STATE_STUNNED]))
	assert_false(
		_registry.target_has_any(
			tagged_object, [GameplayTagIds.TEAM_ENEMY, GameplayTagIds.DAMAGE_FIRE]
		)
	)

	var method_tagged_object := MethodTaggedObject.new()
	method_tagged_object.owned_tags = [GameplayTagIds.TEAM_ENEMY]
	method_tagged_object.method_tags = [GameplayTagIds.STATE_STUNNED]
	assert_true(
		_registry.target_has_tag(method_tagged_object, GameplayTagIds.STATE),
		"Explicit get_owned_gameplay_tags() method should provide plain-object tags"
	)
	assert_false(
		_registry.target_has_tag(method_tagged_object, GameplayTagIds.TEAM_ENEMY, true),
		"Explicit tag method should take precedence over duplicate plain-object properties"
	)


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
