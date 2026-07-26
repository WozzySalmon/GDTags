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


class UnrelatedTagsObject:
	extends RefCounted

	# A plain string list that has nothing to do with gameplay tags.
	var tags: Array[String] = []


class StringNameTagsObject:
	extends RefCounted

	var tags: Array[StringName] = []


const GameplayTagsScript: Script = preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")
const TagCodeGenerator: Script = preload(
	"res://addons/gameplay_tags/editor/gameplay_tag_code_generator.gd"
)

var _assertion_count: int = 0
var _failed: bool = false
var _previous_database: GameplayTagDatabase
var _query_change_count: int = 0
var _database_change_count: int = 0
var _registry: Node


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	_registry = _get_or_create_registry()
	_previous_database = _registry.get_database()
	_registry.set_database(_make_test_database())

	_run_test("database_normalizes_parents_and_searches", _test_database)
	_run_test("database_reload_reads_disk", _test_database_reload)
	_run_test("generated_id_collisions_are_rejected", _test_generated_id_collisions)
	_run_test("container_hierarchical_matching", _test_container)
	_run_test("component_target_helpers", _test_component_target_helpers)
	_run_test("direct_node_tags_and_csv", _test_direct_node_tags_and_csv)
	_run_test("plain_object_target_helpers", _test_plain_object_target_helpers)
	_run_test("component_lookup_is_bounded_to_children", _test_component_lookup_is_bounded)
	_run_test("tag_names_are_validated_everywhere", _test_tag_name_validation)
	_run_test("catalog_objects_are_not_tag_targets", _test_catalog_objects_are_not_targets)
	_run_test("database_set_state_applies_whole_state", _test_database_set_state)
	_run_test("container_tag_stacking", _test_container_tag_stacking)
	_run_test("query_composition", _test_query_composition)
	_run_test("tag_index_finds_nodes", _test_tag_index)
	_run_test("ambiguous_tags_property_is_ignored", _test_ambiguous_tags_property)
	_run_test("query_modes", _test_query_modes)
	_run_test("area3d_trigger_helper", _test_area3d_trigger_helper)

	_registry.set_database(_previous_database)
	if not _failed:
		print("GDSCRIPT_GAMEPLAY_TAGS_TEST passed (%d assertions)" % _assertion_count)
		quit(0)


func _get_or_create_registry() -> Node:
	var existing: Node = root.get_node_or_null("GameplayTags")
	if existing != null:
		return existing

	var registry: Node = GameplayTagsScript.new()
	registry.name = "GameplayTags"
	root.add_child(registry)
	return registry


func _make_test_database() -> GameplayTagDatabase:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	(
		database
		. add_tags(
			[
				&"Ability.Cooldown",
				&"Damage.Fire",
				&"State.Stunned",
				&"State.Invulnerable",
				&"Team.Enemy",
				&"Team.Player",
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
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	var unsorted_tags: Array[StringName] = [&"Team.Enemy", &"Ability", &"State.Stunned"]
	var sorted_tags: Array[StringName] = [&"Ability", &"State.Stunned", &"Team.Enemy"]
	assert_eq(
		GameplayTagDatabase.canonicalize_tag_array(unsorted_tags),
		sorted_tags,
		"Canonical tags should remain alphabetically sorted",
	)

	assert_true(database.add_tag(&"State.Stunned.Heavy"))
	assert_true(database.has_tag(&"State"), "Adding a child should create root parent")
	assert_true(database.has_tag(&"State.Stunned"), "Adding a child should create middle parent")
	assert_false(database.add_tag(&"State.Stunned.Heavy"), "Duplicate tag should fail")
	assert_false(
		database.remove_tag(&"State", false), "Non-recursive remove should protect children"
	)
	assert_eq(database.validate().size(), 0, "Database should validate")
	assert_eq(database.find_tags("stun").size(), 2, "Search should find parent and child")
	assert_true(database.set_tag_description(&"State.Stunned", "Prevents movement"))
	assert_eq(
		database.tag_descriptions.get("State.Stunned", ""),
		"Prevents movement",
		"Existing tag descriptions should be editable",
	)
	assert_eq(
		database.find_tags("PREVENTS MOVEMENT"),
		[&"State.Stunned"],
		"Search should find tags by description without case sensitivity",
	)
	assert_false(
		database.set_tag_description(&"State.Stunned", "Prevents movement"),
		"Unchanged descriptions should not report a mutation",
	)
	assert_true(database.set_tag_description(&"State.Stunned", ""))
	assert_false(
		database.tag_descriptions.has("State.Stunned"),
		"Clearing a description should remove its stored entry",
	)
	assert_false(
		database.set_tag_description(&"Missing.Tag", "Missing"),
		"Descriptions cannot be set for unknown tags",
	)

	var rename_database: GameplayTagDatabase = GameplayTagDatabase.new()
	rename_database.add_tag(&"State.Stunned.Heavy", "Heavy stun")
	rename_database.set_tag_description(&"State.Stunned", "Stunned state")
	rename_database.add_tag(&"State.Running")
	assert_true(rename_database.rename_tag(&"State.Stunned", &"Condition.Disabled"))
	assert_true(rename_database.has_tag(&"Condition"), "Rename should create missing parents")
	assert_true(rename_database.has_tag(&"Condition.Disabled"))
	assert_true(rename_database.has_tag(&"Condition.Disabled.Heavy"))
	assert_false(rename_database.has_tag(&"State.Stunned"))
	assert_true(rename_database.has_tag(&"State.Running"), "Unrelated tags should remain")
	assert_eq(
		rename_database.tag_descriptions.get("Condition.Disabled", ""),
		"Stunned state",
		"Rename should migrate parent descriptions",
	)
	assert_eq(
		rename_database.tag_descriptions.get("Condition.Disabled.Heavy", ""),
		"Heavy stun",
		"Rename should migrate child descriptions",
	)
	assert_false(
		rename_database.rename_tag(&"Condition.Disabled", &"State.Running"),
		"Rename should reject collisions with existing tags",
	)
	assert_false(
		rename_database.rename_tag(&"Condition", &"Condition.Child"),
		"Rename should reject moving a branch beneath itself",
	)

	var moved_branch_database: GameplayTagDatabase = GameplayTagDatabase.new()
	moved_branch_database.add_tag(&"Old.Parent.Child")
	assert_true(moved_branch_database.rename_tag(&"Old.Parent", &"New.Parent"))
	assert_false(
		moved_branch_database.has_tag(&"Old.Parent"),
		"Rename should remove the old branch tag",
	)
	assert_false(
		moved_branch_database.has_tag(&"Old"),
		"Rename should remove an empty old parent created for the moved branch",
	)
	assert_true(moved_branch_database.has_tag(&"New.Parent.Child"))

	var described_parent_database: GameplayTagDatabase = GameplayTagDatabase.new()
	described_parent_database.add_tag(&"Old.Parent.Child")
	described_parent_database.set_tag_description(&"Old", "Explicit root description")
	assert_true(described_parent_database.rename_tag(&"Old.Parent", &"New.Parent"))
	assert_true(
		described_parent_database.has_tag(&"Old"),
		"An empty old parent with its own description should be preserved",
	)

	var orphan_database: GameplayTagDatabase = GameplayTagDatabase.new()
	orphan_database.tags = [&"State.Stunned"]
	assert_eq(orphan_database.validate().size(), 1, "Database should report missing parents")

	var tag: GameplayTag = database.get_tag(&"State.Stunned.Heavy")
	assert_true(tag != null, "get_tag should return a GameplayTag")
	assert_true(tag.matches(&"State.Stunned"), "GameplayTag should use hierarchical matching")

	var bulk_database: GameplayTagDatabase = GameplayTagDatabase.new()
	bulk_database.add_tag(&"State.Stunned")
	bulk_database.add_tag(&"State.Running")
	bulk_database.tag_descriptions = {
		"State": "State root",
		"State.Stunned": "Stunned state",
	}
	assert_eq(bulk_database.remove_tags([&"State", &"State.Stunned"]), 1)
	assert_true(bulk_database.has_tag(&"State"), "Parents with remaining children stay protected")
	assert_eq(
		bulk_database.tag_descriptions.get("State", ""),
		"State root",
		"Protected parent descriptions should be preserved",
	)
	assert_false(bulk_database.tag_descriptions.has("State.Stunned"))


func _test_database_reload() -> void:
	var previous_path: String = _registry.get_database_path()
	var previous_database: GameplayTagDatabase = _registry.get_database()
	var test_path: String = "user://gameplay_tags_reload_test.tres"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))

	var initial_database: GameplayTagDatabase = GameplayTagDatabase.new()
	initial_database.add_tag(&"Reload.Before")
	assert_eq(ResourceSaver.save(initial_database, test_path), OK)
	_registry.set_database_path(test_path)
	var cached_database: GameplayTagDatabase = _registry.reload_database()
	assert_true(cached_database.has_tag(&"Reload.Before"))

	var disk_database: GameplayTagDatabase = GameplayTagDatabase.new()
	disk_database.add_tag(&"Reload.After")
	assert_eq(ResourceSaver.save(disk_database, test_path), OK)
	assert_false(cached_database.has_tag(&"Reload.After"), "Cached database should still be stale")

	var reloaded_database: GameplayTagDatabase = _registry.reload_database()
	assert_true(
		reloaded_database.has_tag(&"Reload.After"), "Reload should re-read the disk resource"
	)
	assert_false(reloaded_database.has_tag(&"Reload.Before"))

	_registry.set_database_path(previous_path)
	_registry.set_database(previous_database)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))


func _test_generated_id_collisions() -> void:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tag(&"Foo_Bar")
	database.add_tag(&"Foo-Bar")

	var collisions: Array[Dictionary] = TagCodeGenerator.get_constant_name_collisions(database)
	assert_eq(collisions.size(), 1, "Generated ID collisions should be detected")
	assert_eq(collisions[0]["name"], "FOO_BAR")
	assert_eq(collisions[0]["tags"].size(), 2)

	var generated_path: String = "user://gameplay_tags_generated_ids_test.gd"
	var unrelated_path: String = "user://gameplay_tags_unrelated_script_test.gd"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(generated_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(unrelated_path))

	var generated_database: GameplayTagDatabase = GameplayTagDatabase.new()
	generated_database.add_tag(&"State.Stunned")
	assert_eq(
		TagCodeGenerator.save_tag_ids(generated_database, generated_path),
		OK,
		"Generated-ID output should be writable when the path is unused",
	)
	var first_generated_source: String = FileAccess.get_file_as_string(generated_path)
	assert_true(
		first_generated_source.contains(TagCodeGenerator.GENERATED_FILE_MARKER),
		"Generated-ID output should include its ownership marker",
	)
	generated_database.add_tag(&"Team.Enemy")
	assert_eq(
		TagCodeGenerator.save_tag_ids(generated_database, generated_path),
		OK,
		"Recognizably generated output should be replaceable",
	)
	assert_true(
		FileAccess.get_file_as_string(generated_path).contains("const TEAM_ENEMY"),
		"Replacing generated output should write the latest tags",
	)

	var sentinel_source: String = 'extends Node\n\nconst SENTINEL: String = "keep me"\n'
	var unrelated_file: FileAccess = FileAccess.open(unrelated_path, FileAccess.WRITE)
	assert_true(unrelated_file != null, "Unrelated script fixture should be writable")
	if unrelated_file != null:
		unrelated_file.store_string(sentinel_source)
		unrelated_file.close()
	assert_eq(
		TagCodeGenerator.save_tag_ids(generated_database, unrelated_path),
		ERR_FILE_UNRECOGNIZED,
		"Generated-ID output should refuse an unrelated existing script",
	)
	assert_eq(
		FileAccess.get_file_as_string(unrelated_path),
		sentinel_source,
		"Refused generated-ID output must preserve unrelated bytes",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(generated_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(unrelated_path))


func _test_container() -> void:
	var container: GameplayTagContainer = GameplayTagContainer.new()
	assert_true(container.add_tag(&"State.Stunned"))
	assert_true(container.add_tag(&"Team.Enemy"))
	assert_false(container.add_tag(&"Team.Enemy"), "Duplicate container tag should fail")

	assert_true(container.has_tag(&"State"), "Parent query should match owned child")
	assert_true(container.has_exact(&"Team.Enemy"), "Exact owned tag should match")
	assert_false(container.has_exact(&"State"), "Parent should not exact-match child")
	assert_true(container.has_all([&"State", &"Team.Enemy"]))
	assert_true(container.has_any([&"Damage", &"Team"]))
	assert_true(container.all([&"State", &"Team.Enemy"]), "GDTag-style all alias should work")
	assert_true(container.any([&"Damage", &"Team"]), "GDTag-style any alias should work")
	assert_true(container.none([&"Damage.Ice"]), "Container none helper should reject overlaps")
	assert_eq(container.overlap_count([&"State", &"Team.Enemy"]), 2)
	assert_true(container.exact([GameplayTagIds.STATE_STUNNED, GameplayTagIds.TEAM_ENEMY]))
	assert_false(container.exact([GameplayTagIds.STATE, GameplayTagIds.TEAM_ENEMY]))
	assert_true(container.remove_tag(GameplayTagIds.TEAM_ENEMY))
	assert_false(container.has_exact(GameplayTagIds.TEAM_ENEMY))
	container.clear()
	assert_true(container.is_empty(), "Container clear should remove all tags")


func _test_component_target_helpers() -> void:
	var actor: Node = Node.new()
	var component: GameplayTagComponent = GameplayTagComponent.new()
	actor.add_child(component)
	root.add_child(actor)

	assert_true(
		GameplayTagIds.all().has(GameplayTagIds.TEAM_PLAYER),
		"Generated tag IDs should expose database constants"
	)
	assert_true(component.add_tag(GameplayTagIds.TEAM_ENEMY), "Registered DB tags can be assigned")
	assert_false(component.add_tag(&"Missing.Tag"), "Component rejects tags outside central DB")
	component.owned_tags = [&"Missing.Tag"]
	assert_false(
		_registry.target_has_tag(component, &"Missing"),
		"Direct property assignment should reject unregistered tags"
	)
	component.set_owned_gameplay_tags([GameplayTagIds.TEAM_ENEMY, &"Missing.Tag"])
	assert_false(
		_registry.target_has_tag(component, &"Missing"),
		"Direct component assignment should reject unregistered tags"
	)
	assert_true(
		_registry.target_has_tag(actor, GameplayTagIds.TEAM),
		"Actor child component should be found"
	)
	assert_true(_registry.target_has_tag(component, GameplayTagIds.TEAM_ENEMY, true))
	component.validate_with_database = false
	assert_true(component.add_tag(&"Custom.Unregistered"))
	assert_true(
		_registry.target_has_tag(component, &"Custom"),
		"Target helpers should preserve component tags accepted with validation disabled",
	)
	assert_false(_registry.target_has_tag(actor, &"Team", true), "Exact parent should fail")

	var owned: GameplayTagContainer = _registry.get_owned_gameplay_tags(actor)
	assert_true(owned.has_tag(&"Team.Enemy", true), "Owned tags should come back as a container")
	actor.free()


func _test_direct_node_tags_and_csv() -> void:
	var actor: Node = Node.new()
	root.add_child(actor)
	var direct_tags: Array[StringName] = [GameplayTagIds.TEAM_PLAYER, &"Missing.Tag"]

	assert_eq(
		_registry.add_tags_to_node(actor, direct_tags),
		1,
		"Direct node tags should validate against the central DB"
	)
	assert_true(actor.is_in_group("gameplay_tagged_nodes"))
	assert_true(_registry.target_has_tag(actor, GameplayTagIds.TEAM))

	var component: GameplayTagComponent = GameplayTagComponent.new()
	actor.add_child(component)
	component.add_tag(GameplayTagIds.STATE_STUNNED)
	var combined_tags: Array[StringName] = [
		GameplayTagIds.TEAM_PLAYER,
		GameplayTagIds.STATE_STUNNED,
	]
	assert_true(
		_registry.target_has_all(actor, combined_tags),
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

	var custom_actor: Node = Node.new()
	root.add_child(custom_actor)
	var custom_tags: Array[StringName] = [&"Custom.Unregistered"]
	assert_true(_registry.set_node_tags(custom_actor, custom_tags, false))
	assert_true(
		_registry.get_owned_gameplay_tags(custom_actor).has_tag(&"Custom.Unregistered", true),
		"Owned-tag reads should preserve direct node tags written without validation",
	)
	assert_true(
		_registry.target_has_tag(custom_actor, &"Custom"),
		"Target helpers should preserve direct node tags written without validation",
	)
	custom_actor.free()

	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	assert_eq(database.add_tags_from_csv_text("Ability,Dash\nDamage/Ice\n"), 2)
	assert_true(database.has_tag(&"Ability"), "CSV import should create parent tags")
	assert_true(database.has_tag(&"Damage.Ice"), "CSV import should normalize slash paths")
	assert_true(database.to_csv_text().contains("Ability.Dash"))


func _test_plain_object_target_helpers() -> void:
	var tagged_object: TaggedObject = TaggedObject.new()
	tagged_object.owned_tags = [GameplayTagIds.STATE_STUNNED]

	assert_true(_registry.target_has_tag(tagged_object, GameplayTagIds.STATE))
	var required_tags: Array[StringName] = [GameplayTagIds.STATE_STUNNED]
	var blocked_tags: Array[StringName] = [
		GameplayTagIds.TEAM_ENEMY,
		GameplayTagIds.DAMAGE_FIRE,
	]
	assert_true(_registry.target_has_all(tagged_object, required_tags))
	assert_false(_registry.target_has_any(tagged_object, blocked_tags))

	var method_tagged_object: MethodTaggedObject = MethodTaggedObject.new()
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


func _test_component_lookup_is_bounded() -> void:
	var level: Node = Node.new()
	root.add_child(level)
	var actor: Node = Node.new()
	level.add_child(actor)
	var component: GameplayTagComponent = GameplayTagComponent.new()
	actor.add_child(component)
	component.add_tag(GameplayTagIds.TEAM_ENEMY)

	assert_true(
		_registry.target_has_tag(actor, GameplayTagIds.TEAM),
		"A direct child component should still provide its parent's tags",
	)
	assert_false(
		_registry.target_has_tag(level, GameplayTagIds.TEAM),
		"An ancestor must not inherit tags from a deeper entity's component",
	)
	assert_false(
		_registry.get_nodes_with_tag(level, GameplayTagIds.TEAM).has(level),
		"Group lookups must not report ancestors as tag owners",
	)

	var second_component: GameplayTagComponent = GameplayTagComponent.new()
	actor.add_child(second_component)
	second_component.add_tag(GameplayTagIds.STATE_STUNNED)
	var merged_tags: Array[StringName] = [
		GameplayTagIds.TEAM_ENEMY,
		GameplayTagIds.STATE_STUNNED,
	]
	assert_true(
		_registry.target_has_all(actor, merged_tags),
		"Every direct child component should contribute its tags",
	)
	level.free()


func _test_tag_name_validation() -> void:
	var invalid_tags: Array[StringName] = [&"Bad!Tag", &"Team.Enemy"]
	var container: GameplayTagContainer = GameplayTagContainer.new(invalid_tags)
	assert_eq(
		container.get_tags(),
		[GameplayTagIds.TEAM_ENEMY],
		"Containers should drop tags no database could accept",
	)
	assert_false(container.add_tag(&"Also@Bad"), "Containers should reject invalid tag names")
	assert_eq(container.add_tags(invalid_tags), 0, "Bulk container adds should skip invalid names")

	var query: GameplayTagQuery = GameplayTagQuery.all(invalid_tags)
	assert_eq(query.tags, [GameplayTagIds.TEAM_ENEMY], "Queries should drop invalid tag names")
	assert_false(query.add_tag(&"Also@Bad"), "Queries should reject invalid tag names")

	var component: GameplayTagComponent = GameplayTagComponent.new()
	component.validate_with_database = false
	root.add_child(component)
	assert_false(
		component.add_tag(&"Also@Bad"),
		"Disabling database validation must not accept unusable tag names",
	)
	component.owned_tags = invalid_tags
	assert_eq(component.owned_tags, [GameplayTagIds.TEAM_ENEMY])
	component.free()


func _test_catalog_objects_are_not_targets() -> void:
	var database: GameplayTagDatabase = _registry.get_database()
	assert_false(
		_registry.target_has_tag(database, GameplayTagIds.TEAM_ENEMY),
		"A database catalogs tags; it does not own them",
	)

	var query_tags: Array[StringName] = [GameplayTagIds.TEAM_ENEMY]
	var query: GameplayTagQuery = GameplayTagQuery.all(query_tags)
	assert_false(
		_registry.target_has_tag(query, GameplayTagIds.TEAM_ENEMY),
		"A query describes a filter; it does not own the tags it matches",
	)


func _test_database_set_state() -> void:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tag(&"Discarded.Tag", "Discarded description")

	var state_tags: Array[StringName] = [&"State.Stunned.Heavy", &"Bad!Tag"]
	var state_descriptions: Dictionary[String, String] = {
		"State.Stunned": "Stunned state",
		"Missing.Tag": "Description for a tag that is not in the new state",
	}
	_database_change_count = 0
	database.tags_changed.connect(_on_database_changed)
	database.set_state(state_tags, state_descriptions)

	assert_true(database.has_tag(&"State"), "set_state should create missing parents")
	assert_true(database.has_tag(&"State.Stunned.Heavy"))
	assert_false(database.has_tag(&"Discarded.Tag"), "set_state should replace the previous state")
	assert_false(database.has_tag(&"Bad!Tag"), "set_state should drop invalid tag names")
	assert_eq(database.tag_descriptions.get("State.Stunned", ""), "Stunned state")
	assert_false(
		database.tag_descriptions.has("Missing.Tag"),
		"Descriptions for tags outside the new state should be dropped",
	)
	assert_false(database.tag_descriptions.has("Discarded.Tag"))
	assert_eq(
		_database_change_count, 1, "set_state should apply the whole state in one change signal"
	)


func _test_container_tag_stacking() -> void:
	var container: GameplayTagContainer = GameplayTagContainer.new()
	assert_eq(container.add_tag_stack(GameplayTagIds.STATE_STUNNED), 1, "First stack applies")
	assert_eq(container.add_tag_stack(GameplayTagIds.STATE_STUNNED), 2, "Second stack accumulates")
	assert_true(container.has_tag(GameplayTagIds.STATE), "A stacked tag is owned normally")
	assert_eq(container.get_tag_count(GameplayTagIds.STATE_STUNNED), 2)
	assert_eq(
		container.get_tag_count(GameplayTagIds.STATE),
		0,
		"Stacks are tracked per exact tag, not inherited by parents",
	)

	assert_eq(container.remove_tag_stack(GameplayTagIds.STATE_STUNNED), 1)
	assert_true(
		container.has_tag(GameplayTagIds.STATE_STUNNED, true),
		"A tag survives while other stacks remain",
	)
	assert_eq(container.remove_tag_stack(GameplayTagIds.STATE_STUNNED), 0)
	assert_false(
		container.has_tag(GameplayTagIds.STATE_STUNNED, true),
		"Removing the last stack releases the tag",
	)
	assert_eq(container.remove_tag_stack(GameplayTagIds.STATE_STUNNED), 0, "Unowned tags stay at 0")

	container.add_tag_stack(GameplayTagIds.TEAM_ENEMY)
	container.add_tag_stack(GameplayTagIds.TEAM_ENEMY)
	assert_true(container.set_tag_count(GameplayTagIds.TEAM_ENEMY, 5))
	assert_eq(container.get_tag_count(GameplayTagIds.TEAM_ENEMY), 5)
	assert_false(
		container.set_tag_count(GameplayTagIds.TEAM_ENEMY, 5), "Unchanged counts report no mutation"
	)
	assert_eq(
		container.duplicate_container().get_tag_count(GameplayTagIds.TEAM_ENEMY),
		5,
		"Copies should carry stack depth",
	)
	assert_true(container.set_tag_count(GameplayTagIds.TEAM_ENEMY, 0), "Zero releases the tag")
	assert_false(container.has_tag(GameplayTagIds.TEAM_ENEMY, true))

	container.add_tag_stack(GameplayTagIds.DAMAGE_FIRE)
	container.add_tag_stack(GameplayTagIds.DAMAGE_FIRE)
	assert_true(container.remove_tag(GameplayTagIds.DAMAGE_FIRE), "remove_tag drops every stack")
	assert_eq(container.get_tag_count(GameplayTagIds.DAMAGE_FIRE), 0)
	assert_eq(container.add_tag_stack(&"Bad!Tag"), 0, "Unusable tag names cannot be stacked")


func _test_query_composition() -> void:
	var fire_or_stunned: Array[StringName] = [
		GameplayTagIds.DAMAGE_FIRE,
		GameplayTagIds.STATE_STUNNED,
	]
	var blocked: Array[StringName] = [GameplayTagIds.STATE_INVULNERABLE]
	var nested: Array[GameplayTagQuery] = [
		GameplayTagQuery.any(fire_or_stunned),
		GameplayTagQuery.none(blocked),
	]
	var composed: GameplayTagQuery = GameplayTagQuery.compose(GameplayTagQuery.Mode.ALL, nested)

	var stunned_tags: Array[StringName] = [GameplayTagIds.STATE_STUNNED]
	assert_true(
		composed.matches(GameplayTagContainer.new(stunned_tags)),
		"(Fire or Stunned) and not Invulnerable should match a stunned target",
	)
	var immune_tags: Array[StringName] = [
		GameplayTagIds.STATE_STUNNED,
		GameplayTagIds.STATE_INVULNERABLE,
	]
	assert_false(
		composed.matches(GameplayTagContainer.new(immune_tags)),
		"A blocked tag in a nested NONE should reject the target",
	)
	var team_tags: Array[StringName] = [GameplayTagIds.TEAM_ENEMY]
	assert_false(
		composed.matches(GameplayTagContainer.new(team_tags)),
		"Neither branch of the nested ANY should match an unrelated target",
	)

	var outer: GameplayTagQuery = GameplayTagQuery.all(team_tags)
	assert_true(outer.add_sub_query(GameplayTagQuery.any(fire_or_stunned)))
	assert_false(outer.add_sub_query(outer), "A query must not contain itself")
	assert_false(outer.add_sub_query(null))
	var enemy_and_stunned: Array[StringName] = [
		GameplayTagIds.TEAM_ENEMY,
		GameplayTagIds.STATE_STUNNED,
	]
	assert_true(
		outer.matches(GameplayTagContainer.new(enemy_and_stunned)),
		"Own tags and nested queries should both be required in ALL mode",
	)
	assert_false(
		outer.matches(GameplayTagContainer.new(team_tags)),
		"A failing nested query should reject an otherwise matching target",
	)
	assert_true(outer.remove_sub_query(outer.sub_queries[0]))
	assert_true(outer.matches(GameplayTagContainer.new(team_tags)))


func _test_tag_index() -> void:
	var level: Node = Node.new()
	root.add_child(level)
	var direct_actor: Node = Node.new()
	level.add_child(direct_actor)
	var component_actor: Node = Node.new()
	level.add_child(component_actor)
	var component: GameplayTagComponent = GameplayTagComponent.new()
	component_actor.add_child(component)

	var player_tags: Array[StringName] = [GameplayTagIds.TEAM_PLAYER]
	_registry.set_node_tags(direct_actor, player_tags)
	component.add_tag(GameplayTagIds.TEAM_ENEMY)

	assert_true(
		_registry.get_nodes_with_tag(level, GameplayTagIds.TEAM_PLAYER).has(direct_actor),
		"The index should find metadata-tagged nodes",
	)
	assert_true(
		_registry.get_nodes_with_tag(level, GameplayTagIds.TEAM_ENEMY).has(component_actor),
		"The index should find component owners",
	)
	assert_eq(
		_registry.get_nodes_with_tag(level, GameplayTagIds.TEAM).size(),
		2,
		"A parent tag should match every node owning one of its children",
	)
	assert_eq(
		_registry.get_nodes_with_tag(level, GameplayTagIds.TEAM, true).size(),
		0,
		"Exact lookups should not match nodes owning only child tags",
	)

	_registry.clear_node_tags(direct_actor)
	assert_false(
		_registry.get_nodes_with_tag(level, GameplayTagIds.TEAM_PLAYER).has(direct_actor),
		"Clearing node tags should drop the node from the index",
	)

	component.remove_tag(GameplayTagIds.TEAM_ENEMY)
	assert_false(
		_registry.get_nodes_with_tag(level, GameplayTagIds.TEAM_ENEMY).has(component_actor),
		"Removing a component tag should drop its owner from results",
	)
	level.free()


func _test_ambiguous_tags_property() -> void:
	var unrelated: UnrelatedTagsObject = UnrelatedTagsObject.new()
	unrelated.tags = ["State.Stunned"]
	assert_false(
		_registry.target_has_tag(unrelated, GameplayTagIds.STATE),
		"An Array[String] named tags belongs to the owning class, not this addon",
	)

	var tag_holder: StringNameTagsObject = StringNameTagsObject.new()
	tag_holder.tags = [GameplayTagIds.STATE_STUNNED]
	assert_true(
		_registry.target_has_tag(tag_holder, GameplayTagIds.STATE),
		"An Array[StringName] named tags is still an accepted tag payload",
	)


func _test_query_modes() -> void:
	var component: GameplayTagComponent = GameplayTagComponent.new()
	root.add_child(component)
	component.add_tag(&"State.Stunned")
	component.add_tag(&"Team.Enemy")

	assert_true(
		GameplayTagQuery.all([&"State", &"Team.Enemy"]).matches(component),
		"Queries should resolve tags directly from typed gameplay targets",
	)
	assert_true(
		GameplayTagQuery.any([&"Damage.Fire", &"State"]).matches(
			component.get_owned_gameplay_tags()
		)
	)
	assert_true(
		GameplayTagQuery.none([&"State.Invulnerable", &"Team.Player"]).matches(
			component.get_owned_gameplay_tags()
		)
	)
	assert_false(
		GameplayTagQuery.exact_all([&"State"]).matches(component.get_owned_gameplay_tags())
	)

	var populated_container: GameplayTagContainer = GameplayTagContainer.new([&"State.Stunned"])
	var empty_query_tags: Array[StringName] = []
	assert_true(
		GameplayTagQuery.all(empty_query_tags).matches(populated_container),
		"ALL with no required tags should match a valid target",
	)
	assert_false(
		GameplayTagQuery.any(empty_query_tags).matches(populated_container),
		"ANY with no required tags should not match",
	)
	assert_true(
		GameplayTagQuery.none(empty_query_tags).matches(populated_container),
		"NONE with no blocked tags should match",
	)

	var observed_query: GameplayTagQuery = GameplayTagQuery.new()
	_query_change_count = 0
	observed_query.changed.connect(_on_query_changed)
	observed_query.mode = GameplayTagQuery.Mode.ANY
	observed_query.exact = true
	observed_query.mode = GameplayTagQuery.Mode.ANY
	observed_query.exact = true
	assert_eq(_query_change_count, 2, "Mode and exact changes should emit Resource.changed")
	component.free()


func _test_area3d_trigger_helper() -> void:
	var actor: Node3D = Node3D.new()
	var component: GameplayTagComponent = GameplayTagComponent.new()
	actor.add_child(component)
	root.add_child(actor)
	component.add_tag(&"Team.Enemy")

	var trigger: GameplayTagTrigger3D = GameplayTagTrigger3D.new()
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


func _on_query_changed() -> void:
	_query_change_count += 1


func _on_database_changed() -> void:
	_database_change_count += 1


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
		var prefix: String = "%s: " % message if not message.is_empty() else ""
		_fail("%sexpected %s, got %s" % [prefix, str(expected), str(actual)])


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	if _registry != null:
		_registry.set_database(_previous_database)
	quit(1)
