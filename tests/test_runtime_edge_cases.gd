extends "res://tests/tag_test_case.gd"

var _query_change_count: int = 0


func _suite_name() -> String:
	return "GDSCRIPT_GAMEPLAY_TAGS_EDGE_TEST"


func _run_tests() -> void:
	run_test("database_recursive_removal_and_csv_round_trip", _test_database_edges)
	run_test("container_component_and_query_mutations", _test_runtime_mutations)
	run_test("autoload_csv_and_node_helpers", _test_autoload_helpers)


func _make_test_database() -> GameplayTagDatabase:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	(
		database
		. add_tags(
			[
				&"Ability.Dash",
				&"Damage.Fire",
				&"State.Stunned",
				&"Team.Enemy",
				&"Team.Player",
			]
		)
	)
	return database


func _test_database_edges() -> void:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tag(&"State.Stunned.Heavy", "Heavy stun")
	database.tag_descriptions["State"] = "State root"
	database.tag_descriptions["State.Stunned"] = "Stunned state"

	assert_eq(database.get_children(&"State").size(), 1)
	assert_eq(database.get_children(&"State", true).size(), 2)
	assert_true(database.remove_tag(&"State.Stunned", true))
	assert_true(database.has_tag(&"State"), "Recursive child removal should retain its parent")
	assert_false(database.has_tag(&"State.Stunned"))
	assert_false(database.has_tag(&"State.Stunned.Heavy"))
	assert_eq(database.tag_descriptions.get("State", ""), "State root")
	assert_false(database.tag_descriptions.has("State.Stunned"))
	assert_false(database.tag_descriptions.has("State.Stunned.Heavy"))

	var batch_database: GameplayTagDatabase = GameplayTagDatabase.new()
	batch_database.add_tags([&"Ability.Dash", &"Damage.Fire", &"Team.Enemy"])
	assert_eq(batch_database.remove_tags([&"Ability.Dash", &"Damage.Fire"]), 2)
	assert_false(batch_database.has_tag(&"Ability.Dash"))
	assert_false(batch_database.has_tag(&"Damage.Fire"))
	assert_true(batch_database.has_tag(&"Team.Enemy"))

	var csv_text: String = batch_database.to_csv_text()
	var round_trip: GameplayTagDatabase = GameplayTagDatabase.new()
	round_trip.add_tags_from_csv_text(csv_text)
	assert_eq(round_trip.get_all_tags(), batch_database.get_all_tags())
	assert_true(GameplayTagDatabase.is_valid_tag_name(&"Valid.Child-1"))
	assert_false(GameplayTagDatabase.is_valid_tag_name(&"Invalid@Child"))
	assert_false(GameplayTagDatabase.tag_matches(&"State", &"State.Stunned"))


func _test_runtime_mutations() -> void:
	var container: GameplayTagContainer = GameplayTagContainer.new()
	assert_eq(container.add_tags([&"State.Stunned", &"Team.Enemy", &"Team.Enemy"]), 2)
	assert_true(container.has_all([]), "An empty required set should match")
	assert_false(container.has_all([&"State"], true))
	assert_eq(container.overlap_count([&"State", &"Team.Enemy"], true), 1)
	assert_eq(container.remove_tags([&"State.Stunned", &"Missing.Tag"]), 1)
	assert_false(container.has_tag(&"State"))

	var duplicate: GameplayTagContainer = container.duplicate_container()
	duplicate.add_tag(&"Damage.Fire")
	assert_false(container.has_tag(&"Damage.Fire", true), "Container copies must be independent")

	var component: GameplayTagComponent = GameplayTagComponent.new()
	component.validate_with_database = false
	root.add_child(component)
	assert_true(component.is_in_group(GameplayTagComponent.GROUP_NAME))
	assert_true(component.add_tag(&"Custom.Unregistered"))
	assert_true(component.has_tag(&"Custom"))
	assert_true(component.has_any([&"Custom", &"Missing"]))
	assert_true(component.has_all([&"Custom.Unregistered"], true))
	assert_true(component.remove_tag(&"Custom.Unregistered"))
	assert_false(component.has_tag(&"Custom"))
	component.free()

	var query: GameplayTagQuery = GameplayTagQuery.new()
	_query_change_count = 0
	query.changed.connect(_on_query_changed)
	assert_true(query.add(&"State"))
	assert_eq(query.add_tags([&"Team.Enemy", &"Damage.Fire", &"State"]), 2)
	assert_true(
		query.matches(GameplayTagContainer.new([&"State.Stunned", &"Team.Enemy", &"Damage.Fire"]))
	)
	assert_true(query.remove(&"Damage.Fire"))
	assert_eq(query.remove_tags([&"State", &"Missing.Tag"]), 1)
	query.clear()
	assert_true(query.tags.is_empty())
	assert_true(_query_change_count > 0, "Query mutators should emit Resource.changed")
	assert_false(GameplayTagQuery.all([&"State"]).matches(null))


func _test_autoload_helpers() -> void:
	var csv_path: String = "user://gameplay_tags_edge_export.csv"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path))

	var source_database: GameplayTagDatabase = GameplayTagDatabase.new()
	source_database.add_tags([&"Ability.Dash", &"Damage.Fire", &"Team.Enemy"])
	registry.set_database(source_database)
	assert_eq(registry.export_tags_to_csv(csv_path), OK)

	var imported_database: GameplayTagDatabase = GameplayTagDatabase.new()
	registry.set_database(imported_database)
	assert_true(registry.import_tags_from_csv(csv_path, false) > 0)
	assert_eq(imported_database.get_all_tags(), source_database.get_all_tags())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path))

	registry.set_database(_make_test_database())
	var actor: Node = Node.new()
	root.add_child(actor)
	var custom_tags: Array[StringName] = [&"Custom.Unregistered"]
	assert_true(registry.set_node_tags(actor, custom_tags, false))
	assert_true(registry.get_node_tags(actor).has_tag(&"Custom"))
	assert_true(actor.is_in_group("gameplay_tagged_nodes"))
	registry.clear_node_tags(actor)
	assert_true(registry.get_node_tags(actor).is_empty())
	assert_false(actor.is_in_group("gameplay_tagged_nodes"))

	var team_enemy_tags: Array[StringName] = [&"Team.Enemy"]
	var team_tags: Array[StringName] = [&"Team"]
	var damage_or_team_tags: Array[StringName] = [&"Damage", &"Team"]
	var damage_tags: Array[StringName] = [&"Damage"]
	assert_true(registry.make_container(team_enemy_tags).has_tag(&"Team"))
	assert_true(
		registry.make_query_all(team_tags).matches(GameplayTagContainer.new(team_enemy_tags))
	)
	assert_true(
		registry.make_query_any(damage_or_team_tags).matches(
			GameplayTagContainer.new(team_enemy_tags)
		)
	)
	assert_true(
		registry.make_query_none(damage_tags).matches(GameplayTagContainer.new(team_enemy_tags))
	)
	actor.free()


func _on_query_changed() -> void:
	_query_change_count += 1
