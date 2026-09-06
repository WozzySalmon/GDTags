extends "res://tests/tag_test_case.gd"


# Counts push_warning traffic so tests can assert warning behavior without touching
# the shared harness. Godot routes push_warning through _log_error with a warning type.
class WarningCaptureLogger:
	extends Logger

	var warning_count: int = 0
	var warning_texts: Array[String] = []
	var last_warning_text: String = ""

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		_code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			return
		warning_count += 1
		last_warning_text = rationale if not rationale.is_empty() else _code
		warning_texts.append(last_warning_text)


var _query_change_count: int = 0
var _database_change_count: int = 0
var _nested_database: GameplayTagDatabase


func _suite_name() -> String:
	return "GDSCRIPT_GAMEPLAY_TAGS_EDGE_TEST"


func _run_tests() -> void:
	run_test("database_recursive_removal_and_csv_round_trip", _test_database_edges)
	run_test("container_component_and_query_mutations", _test_runtime_mutations)
	run_test("fused_canonicalization_preserves_mutation_contract", _test_fused_canonicalization)
	run_test("has_all_fallback_matches_cached_fast_path", _test_has_all_fallback)
	run_test("database_mutations_emit_one_change", _test_database_single_notification)
	run_test("cache_only_database_is_not_loaded", _test_cache_only_database_is_not_loaded)
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
	var tag_value: GameplayTag = GameplayTag.new(&"State.Stunned")
	assert_false(tag_value.is_empty())
	assert_eq(tag_value.parent_name(), &"State")
	assert_true(tag_value.is_child_of(&"State"))
	assert_true(GameplayTag.new().is_empty())

	var assigned_database: GameplayTagDatabase = GameplayTagDatabase.new()
	assigned_database.tags = [&"Valid.Assigned", &"Invalid@Assigned"]
	assert_true(assigned_database.has_tag(&"Valid.Assigned"))
	assert_false(
		assigned_database.has_tag(&"Invalid@Assigned"),
		"The database setter should reject the same invalid names as containers",
	)


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
	assert_true(query.add_tag(&"State"))
	var query_batch: Array[StringName] = [
		&"Team.Enemy",
		&"Damage.Fire",
		&"State",
		&"Team.Enemy",
		&"Bad@Tag",
	]
	assert_eq(query.add_tags(query_batch), 2)
	assert_true(
		query.matches(GameplayTagContainer.new([&"State.Stunned", &"Team.Enemy", &"Damage.Fire"]))
	)
	assert_true(query.remove_tag(&"Damage.Fire"))
	assert_eq(query.remove_tags([&"State", &"State", &"Missing.Tag"]), 1)
	query.clear()
	assert_true(query.tags.is_empty())
	assert_eq(
		_query_change_count,
		5,
		"Each single or batch query mutation should emit Resource.changed exactly once",
	)
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
	assert_true(registry.add_tag(&"Facade.New", "Facade description", false))
	var facade_batch_tags: Array[StringName] = [&"Facade.Batch.One", &"Facade.Batch.Two"]
	assert_eq(registry.add_tags(facade_batch_tags, false), 2)
	assert_true(registry.set_tag_description(&"Facade.New", "Updated facade description", false))
	assert_true(registry.rename_tag(&"Facade.New", &"Facade.Renamed", false))
	assert_true(registry.is_valid_tag(&"Facade.New"), "Facade validation should resolve redirects")
	assert_true(registry.request_tag(&"Facade.Renamed") != null)
	assert_true(registry.get_all_tags().has(&"Facade.Batch.One"))
	assert_true(registry.find_tags("renamed").has(&"Facade.Renamed"))
	assert_true(registry.ensure_parent_tags(&"Facade.Batch.One", false) == false)
	assert_true(registry.remove_tag(&"Facade.Batch", true, false))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path))

	var original_database_path: String = registry.get_database_path()
	var save_path: String = "user://gameplay_tags_facade_save_test.tres"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	registry.set_database_path(save_path)
	registry.set_database(GameplayTagDatabase.new())
	assert_true(registry.add_tag(&"Facade.Saved", "Saved through the facade"))
	assert_true(FileAccess.file_exists(save_path), "Facade mutations should honor save_now=true")
	assert_eq(registry.save_database(), OK)
	assert_true(
		registry.reload_database().has_tag(&"Facade.Saved"),
		"Facade-saved mutations should survive a reload",
	)
	registry.set_database_path(original_database_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	registry.set_database(_make_test_database())
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


func _on_query_changed() -> void:
	_query_change_count += 1


func _test_database_single_notification() -> void:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	_database_change_count = 0
	_nested_database = null

	# Guard: a stray end call must not drive the depth negative and silence every
	# future change notification.
	database._end_change_suppression()
	assert_eq(
		int(database.get("_suppressed_change_depth")),
		0,
		"A stray suppression end call must be clamped, not underflowed",
	)

	database.tags_changed.connect(_on_database_tags_changed)

	assert_true(database.add_tag(&"Notified.Tag", "One description"))
	assert_eq(
		_database_change_count,
		1,
		"add_tag with a description is one logical mutation and notifies once",
	)
	assert_eq(database.tag_descriptions.get("Notified.Tag", ""), "One description")

	assert_false(database.add_tag(&"Notified.Tag", "Changed description"))
	assert_eq(_database_change_count, 1, "A no-op add_tag must not notify")

	_database_change_count = 0
	assert_true(database.rename_tag(&"Notified.Tag", &"Renamed.Tag"))
	assert_eq(
		_database_change_count,
		1,
		"rename_tag touches tags, descriptions, and redirects but notifies once",
	)
	assert_eq(database.tag_descriptions.get("Renamed.Tag", ""), "One description")

	_database_change_count = 0
	assert_true(database.remove_tag(&"Renamed.Tag"))
	assert_eq(
		_database_change_count,
		1,
		"remove_tag retires the tag and its description but notifies once",
	)
	assert_false(database.tag_descriptions.has("Renamed.Tag"))

	database.add_tags([&"Batch.One", &"Batch.Two"])
	_database_change_count = 0
	assert_eq(database.remove_tags([&"Batch.One", &"Batch.Two"]), 2)
	assert_eq(_database_change_count, 1, "remove_tags is one logical mutation and notifies once")
	assert_false(database.tag_descriptions.has("Batch.One"))

	_database_change_count = 0
	database.set_state([&"State.Tag"], {"State.Tag": "described"}, {})
	assert_eq(_database_change_count, 1, "set_state replaces the whole state but notifies once")

	# A change listener may mutate the database again. Suppression is a depth counter,
	# so the nested mutation publishes its own single change and every path, including
	# the no-op add_tag inside the handler, restores the depth to zero.
	_nested_database = database
	_database_change_count = 0
	assert_true(database.add_tag(&"Outer.Tag"))
	assert_eq(
		_database_change_count,
		2,
		"The outer and the listener-triggered mutation should each notify exactly once",
	)
	assert_true(database.has_tag(&"Nested.FromListener"))
	assert_eq(
		int(database.get("_suppressed_change_depth")),
		0,
		"Suppression must be fully restored after nested mutations",
	)
	_nested_database = null
	database.tags_changed.disconnect(_on_database_tags_changed)


func _on_database_tags_changed() -> void:
	_database_change_count += 1
	if _nested_database != null:
		_nested_database.add_tag(&"Nested.FromListener")


func _test_cache_only_database_is_not_loaded() -> void:
	# A database whose file was deleted while a copy is still loaded leaves a cache-only
	# resource: ResourceLoader.exists() reports true although nothing is on disk. The
	# loader must honour the deletion instead of resurrecting the cached copy.
	var original_path: String = registry.get_database_path()
	var original_database: GameplayTagDatabase = registry.get_database()
	var path: String = "user://gameplay_tags_cache_only_load_test.tres"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var cache_only_database: GameplayTagDatabase = GameplayTagDatabase.new()
	cache_only_database.add_tag(&"Cache.Only")
	cache_only_database.resource_path = path
	assert_true(
		ResourceLoader.exists(path), "Test precondition: the cache entry should be registered"
	)
	assert_false(FileAccess.file_exists(path), "Test precondition: no file may exist on disk")

	registry.set_database_path(path)
	var loaded: GameplayTagDatabase = registry.get_database()
	assert_false(
		loaded.has_tag(&"Cache.Only"),
		"A cache-only resource must not be loaded as the central database",
	)
	assert_true(
		FileAccess.file_exists(path),
		"Without a file the loader should create a fresh database instead",
	)

	# The recreated database must own the cache entry: the stale cache-only copy kept
	# the path registered even though its file was gone, and REUSE loads would keep
	# returning it after the fresh file was written.
	var from_cache: GameplayTagDatabase = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_REUSE
	)
	assert_true(
		from_cache == loaded,
		"The recreated database must take over the cache entry from the stale copy",
	)
	assert_false(
		from_cache.has_tag(&"Cache.Only"),
		"A REUSE load must not resurrect the stale cache-only copy",
	)

	registry.set_database_path(original_path)
	registry.set_database(original_database)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_fused_canonicalization() -> void:
	# canonicalize_valid_tag_array() fuses normalization with character validation, so
	# its contract must survive: canonical, duplicate, unsorted, whitespace, double-dot,
	# invalid-character, and empty inputs.
	var raw_tags: Array[StringName] = [
		&"Team.Enemy",
		&" State ",
		&"State..Stunned",
		&"State.Stunned",
		&"State/Stunned",
		&"Bad@Tag",
		&"",
		&"   ",
	]
	assert_eq(
		GameplayTagDatabase.canonicalize_valid_tag_array(raw_tags),
		[&"State", &"State.Stunned", &"Team.Enemy"],
		"Fused canonicalization should normalize, dedupe, sort, and drop unusable tags",
	)

	var warning_logger: WarningCaptureLogger = WarningCaptureLogger.new()
	OS.add_logger(warning_logger)
	var filtered_tags: Array[StringName] = GameplayTagDatabase.canonicalize_valid_tag_array(
		[&"Team.Enemy", &"Z@Bad", &"Bad@Tag", &" Bad@Tag ", &""]
	)
	OS.remove_logger(warning_logger)
	assert_eq(filtered_tags, [&"Team.Enemy"], "Invalid tags should be dropped from the result")
	assert_eq(
		warning_logger.warning_count,
		2,
		"Each unique normalized invalid tag should emit exactly one warning",
	)
	assert_true(
		warning_logger.warning_texts[0].contains("Bad@Tag"),
		"Invalid-tag warnings should retain their sorted order",
	)
	assert_true(
		warning_logger.last_warning_text.contains("Z@Bad"),
		"Invalid-tag warnings should retain their sorted order",
	)

	# Add and mutation paths share the fused shortcut: usable names normalize in, and
	# names no database could accept are rejected without entering the owner.
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	assert_true(
		database.add_tag(&" State.Stunned "),
		"Whitespace around a valid name should normalize before the add",
	)
	assert_true(database.has_tag(&"State.Stunned"))
	assert_false(database.add_tag(&"Bad@Tag"), "Invalid characters should be rejected")
	assert_false(database.has_tag(&"Bad@Tag"))
	assert_eq(database.add_tags([&" Team ", &"Bad@Tag", &" Team "]), 1)
	assert_true(database.has_tag(&"Team"))
	assert_false(
		database.rename_tag(&"Team", &"Bad@Tag"),
		"Renames onto an unusable name should be rejected",
	)
	assert_false(
		database.add_redirect(&"Bad@Tag", &"Team"),
		"Redirects from an unusable name should be rejected",
	)

	var container: GameplayTagContainer = GameplayTagContainer.new()
	assert_true(container.add_tag(&" State.Stunned "))
	assert_false(container.add_tag(&"Bad@Tag"))
	assert_eq(container.add_tags([&" Team ", &"Bad@Tag", &" Team "]), 1)
	assert_true(container.has_tag(&"Team"))
	assert_eq(container.add_tag_stack(&" Team "), 2, "Stacking should accept a normalized name")
	assert_eq(container.add_tag_stack(&"Bad@Tag"), 0)
	assert_true(container.set_tag_count(&" State.Stunned ", 3))
	assert_eq(container.get_tag_count(&"State.Stunned"), 3)
	assert_false(container.set_tag_count(&"Bad@Tag", 2))


func _test_has_all_fallback() -> void:
	var container: GameplayTagContainer = GameplayTagContainer.new(
		[&"State.Stunned", &"Team.Enemy"]
	)
	assert_true(
		container.has_all([&"State.Stunned", &"Team.Enemy"]),
		"Canonical ALL requirements should hit the cached set",
	)
	assert_true(
		container.has_all([&" State ", &" Team / Enemy "]),
		"Non-canonical ALL requirements should normalize in the fallback",
	)
	assert_true(
		container.has_all([&" State.Stunned "], true),
		"exact=true should accept a normalized owned tag",
	)
	assert_false(
		container.has_all([&"State"], true),
		"exact=true should not let a required parent match",
	)
	assert_false(container.has_all([&"State.Stunned", &"Missing.Tag"]))
	assert_false(container.has_all([&" State ", &"Bad@Tag"]))
	assert_false(container.has_all([&"Bad@Tag"], true))

	var component: GameplayTagComponent = GameplayTagComponent.new()
	component.validate_with_database = false
	component.owned_tags = [&"State.Stunned", &"Team.Enemy"]
	root.add_child(component)
	assert_true(component.has_all([&"State.Stunned", &"Team.Enemy"]))
	assert_true(component.has_all([&" State ", &" Team / Enemy "]))
	assert_true(component.has_all([&" State.Stunned "], true))
	assert_false(component.has_all([&"State"], true))
	assert_false(component.has_all([&"State.Stunned", &"Missing.Tag"]))
	component.free()

	# Split ownership: no single component satisfies the ALL clause, so the node
	# check must combine both components' cached sets in its fallback.
	var first_component: GameplayTagComponent = GameplayTagComponent.new()
	first_component.validate_with_database = false
	first_component.owned_tags = [&"State.Stunned"]
	var second_component: GameplayTagComponent = GameplayTagComponent.new()
	second_component.validate_with_database = false
	second_component.owned_tags = [&"Team.Enemy"]
	var owner_node: Node = Node.new()
	owner_node.add_child(first_component)
	owner_node.add_child(second_component)
	root.add_child(owner_node)
	assert_false(
		first_component.has_all([&" State ", &"Team.Enemy"]),
		"One split component must not satisfy the whole ALL clause",
	)
	var split_requirements: Array[StringName] = [&" State ", &" Team / Enemy "]
	assert_true(
		registry.target_has_all(owner_node, split_requirements),
		"Split node ownership should satisfy a non-canonical ALL clause",
	)
	var canonical_requirements: Array[StringName] = [&"State", &"Team.Enemy"]
	assert_true(registry.target_has_all(owner_node, canonical_requirements))
	assert_false(
		registry.target_has_all(owner_node, canonical_requirements, true),
		"Exact ALL checks must not merge split components into one owner",
	)
	owner_node.free()
