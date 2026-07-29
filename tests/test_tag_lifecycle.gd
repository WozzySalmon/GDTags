extends "res://tests/tag_test_case.gd"
## Covers the capabilities added on top of the original tag core: owner-level stack
## depths, query diagnostics, tag redirects, and the editor reference index.


func _suite_name() -> String:
	return "GDSCRIPT_GAMEPLAY_TAGS_LIFECYCLE_TEST"


func _run_tests() -> void:
	run_test("owner_level_stacking_survives_resolution", _test_owner_level_stacking)
	run_test("query_explain_agrees_with_matches", _test_query_explain)
	run_test("query_validation_reports_issues", _test_query_validation)
	run_test("rename_records_followable_redirects", _test_rename_redirects)
	run_test("redirects_keep_authored_data_resolving", _test_redirect_resolution)
	run_test("reference_index_finds_uses_and_dead_tags", _test_reference_index)
	run_test("migration_rewrites_only_whole_references", _test_reference_migration)
	run_test("renaming_then_migrating_retires_the_redirect", _test_redirect_driven_migration)


func _make_test_database() -> GameplayTagDatabase:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	(
		database
		. add_tags(
			[
				&"Damage.Fire",
				&"State.Stunned",
				&"State.Invulnerable",
				&"Team.Enemy",
				&"Team.Player",
			]
		)
	)
	return database


func _test_owner_level_stacking() -> void:
	var actor: Node = Node.new()
	var component: GameplayTagComponent = GameplayTagComponent.new()
	actor.add_child(component)
	root.add_child(actor)

	var stunned_tags: Array[StringName] = [GameplayTagIds.STATE_STUNNED]
	component.owned_tags = stunned_tags

	assert_eq(
		component.get_tag_count(GameplayTagIds.STATE_STUNNED),
		1,
		"A plain owned tag should report a depth of one",
	)
	assert_eq(
		component.add_tag_stack(GameplayTagIds.STATE_STUNNED),
		2,
		"Stacking an owned tag should return the new depth",
	)
	assert_eq(
		component.add_tag_stack(GameplayTagIds.STATE_STUNNED),
		3,
		"Stacking again should keep increasing the depth",
	)

	# The point of owner-level stacking: depth survives the autoload's resolution,
	# which previously rebuilt a container and dropped every count.
	var resolved: GameplayTagContainer = registry.get_owned_gameplay_tags(actor)
	assert_eq(
		resolved.get_tag_count(GameplayTagIds.STATE_STUNNED),
		3,
		"Resolving a target should carry component stack depth through",
	)
	assert_true(
		registry.target_has_tag(actor, GameplayTagIds.STATE_STUNNED),
		"A stacked tag should still satisfy an ordinary tag check",
	)

	assert_eq(
		component.remove_tag_stack(GameplayTagIds.STATE_STUNNED),
		2,
		"Releasing one stack should return the remaining depth",
	)
	component.remove_tag_stack(GameplayTagIds.STATE_STUNNED)
	assert_eq(
		component.remove_tag_stack(GameplayTagIds.STATE_STUNNED),
		0,
		"Releasing the last stack should report no depth remaining",
	)
	assert_false(
		component.has_tag(GameplayTagIds.STATE_STUNNED),
		"Releasing the last stack should release the tag itself",
	)

	# Replacing the owned set must not leave orphaned counts behind.
	component.owned_tags = stunned_tags
	component.set_tag_count(GameplayTagIds.STATE_STUNNED, 4)
	assert_eq(
		component.get_tag_count(GameplayTagIds.STATE_STUNNED), 4, "set_tag_count should apply"
	)
	var other_tags: Array[StringName] = [GameplayTagIds.TEAM_ENEMY]
	component.owned_tags = other_tags
	component.owned_tags = stunned_tags
	assert_eq(
		component.get_tag_count(GameplayTagIds.STATE_STUNNED),
		1,
		"Re-adding a tag after it was replaced should not resurrect its old depth",
	)

	root.remove_child(actor)
	actor.free()


func _test_query_explain() -> void:
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

	# The trace is a debugging aid, so its verdict must never disagree with matches().
	var cases: Array[Array] = [
		[GameplayTagIds.STATE_STUNNED],
		[GameplayTagIds.STATE_STUNNED, GameplayTagIds.STATE_INVULNERABLE],
		[GameplayTagIds.TEAM_ENEMY],
		[],
	]
	for case_tags in cases:
		var typed_tags: Array[StringName] = []
		typed_tags.assign(case_tags)
		var container: GameplayTagContainer = GameplayTagContainer.new(typed_tags)
		var explanation: String = composed.explain(container)
		var expected_verdict: String = "MATCH" if composed.matches(container) else "NO MATCH"
		assert_true(
			explanation.ends_with("result: %s" % expected_verdict),
			"explain() verdict should agree with matches() for %s" % str(case_tags),
		)

	var stunned_tags: Array[StringName] = [GameplayTagIds.STATE_STUNNED]
	var stunned: GameplayTagContainer = GameplayTagContainer.new(stunned_tags)
	assert_true(
		composed.explain(stunned).contains("owned: State.Stunned"),
		"explain() should report the tags the target actually owns",
	)

	var immune_tags: Array[StringName] = [
		GameplayTagIds.STATE_STUNNED,
		GameplayTagIds.STATE_INVULNERABLE,
	]
	var immune_trace: String = composed.explain(GameplayTagContainer.new(immune_tags))
	assert_true(
		immune_trace.contains("owns State.Invulnerable"),
		"explain() should name the tag that tripped a NONE clause",
	)

	var missing_trace: String = GameplayTagQuery.all(fire_or_stunned).explain(stunned)
	assert_true(
		missing_trace.contains("missing Damage.Fire"),
		"explain() should name the tags an ALL clause is missing",
	)


func _test_query_validation() -> void:
	var known_tags: Array[StringName] = [GameplayTagIds.STATE_STUNNED]
	var database: GameplayTagDatabase = registry.get_database()

	assert_true(
		GameplayTagQuery.all(known_tags).validate(database).is_empty(),
		"A query over registered tags should report no issues",
	)

	var empty_any: GameplayTagQuery = GameplayTagQuery.new()
	empty_any.mode = GameplayTagQuery.Mode.ANY
	var dead_issues: PackedStringArray = empty_any.validate(database)
	assert_eq(dead_issues.size(), 1, "An empty ANY query should report exactly one issue")
	assert_true(
		dead_issues[0].contains("can never match"),
		"An empty ANY query should be reported as unmatchable",
	)

	var contradiction: GameplayTagQuery = GameplayTagQuery.all(known_tags)
	contradiction.add_sub_query(GameplayTagQuery.none(known_tags))
	var contradiction_issues: PackedStringArray = contradiction.validate(database)
	assert_eq(contradiction_issues.size(), 1, "A contradiction should report exactly one issue")
	assert_true(
		contradiction_issues[0].contains("both required and forbidden"),
		"Requiring and forbidding the same tag should be reported",
	)

	# Forbidding exactly State.Stunned still allows satisfying a non-exact requirement
	# with a child tag, so this pair is not a contradiction.
	var exact_forbid: GameplayTagQuery = GameplayTagQuery.all(known_tags)
	exact_forbid.add_sub_query(GameplayTagQuery.none(known_tags, true))
	assert_true(
		exact_forbid.validate(database).is_empty(),
		"An exact NONE should not contradict a non-exact ALL",
	)

	var unknown_tags: Array[StringName] = [&"Not.Registered"]
	var unknown_issues: PackedStringArray = GameplayTagQuery.all(unknown_tags).validate(database)
	assert_eq(unknown_issues.size(), 1, "An unregistered tag should report exactly one issue")
	assert_true(
		unknown_issues[0].contains("not in the database"),
		"An unregistered tag should be reported as missing from the database",
	)

	var outer: GameplayTagQuery = GameplayTagQuery.all(known_tags)
	var inner: GameplayTagQuery = GameplayTagQuery.all(known_tags)
	outer.add_sub_query(inner)
	inner.add_sub_query(outer)
	var cycle_issues: PackedStringArray = outer.validate(database)
	assert_true(
		cycle_issues.size() > 0 and cycle_issues[0].contains("nested inside itself"),
		"A query cycle should be reported rather than recursing forever",
	)
	inner.remove_sub_query(outer)


func _test_rename_redirects() -> void:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tag(&"State.Stunned.Heavy")
	database.add_tag(&"State.Running")

	assert_true(database.rename_tag(&"State.Stunned", &"Condition.Disabled"))
	assert_eq(
		database.resolve_tag(&"State.Stunned"),
		&"Condition.Disabled",
		"Renaming should record a redirect from the retired name",
	)
	assert_eq(
		database.resolve_tag(&"State.Stunned.Heavy"),
		&"Condition.Disabled.Heavy",
		"Renaming a branch should redirect every child it retired",
	)
	assert_eq(
		database.resolve_tag(&"State.Running"),
		&"State.Running",
		"An untouched tag should resolve to itself",
	)

	# Chains: renaming the replacement must keep the original name resolving.
	assert_true(database.rename_tag(&"Condition.Disabled", &"Status.Incapacitated"))
	assert_eq(
		database.resolve_tag(&"State.Stunned"),
		&"Status.Incapacitated",
		"A second rename should keep the oldest name resolving to the newest tag",
	)
	assert_eq(database.validate().size(), 0, "A redirected database should still validate")

	# Restoring a retired name must win over the redirect that retired it.
	assert_true(database.add_tag(&"State.Stunned"))
	assert_eq(
		database.resolve_tag(&"State.Stunned"),
		&"State.Stunned",
		"Re-adding a retired tag should drop its redirect",
	)

	var cyclic: GameplayTagDatabase = GameplayTagDatabase.new()
	cyclic.add_tag(&"Alpha")
	cyclic.add_tag(&"Beta")
	assert_true(cyclic.add_redirect(&"Retired.One", &"Retired.Two"))
	assert_false(
		cyclic.add_redirect(&"Retired.Two", &"Retired.One"),
		"A redirect that would close a cycle should be refused",
	)
	assert_false(
		cyclic.add_redirect(&"Retired.Three", &"Retired.Three"),
		"A self-redirect should be refused",
	)


func _test_redirect_resolution() -> void:
	var database: GameplayTagDatabase = registry.get_database()
	assert_true(database.rename_tag(&"State.Stunned", &"State.Incapacitated"))

	assert_true(
		registry.is_valid_tag(&"State.Stunned"),
		"A retired tag name should still validate through its redirect",
	)

	# The point of a redirect: a scene authored before the rename keeps working, and
	# the old name is stored as its replacement rather than dropped as unregistered.
	var actor: Node = Node.new()
	var component: GameplayTagComponent = GameplayTagComponent.new()
	actor.add_child(component)
	root.add_child(actor)

	var retired_tags: Array[StringName] = [&"State.Stunned"]
	component.owned_tags = retired_tags
	assert_eq(
		component.owned_tags,
		[&"State.Incapacitated"] as Array[StringName],
		"Authored tags naming a retired branch should be stored as the replacement",
	)
	assert_true(
		registry.target_has_tag(actor, &"State.Incapacitated"),
		"A target authored with the retired name should match the replacement",
	)

	var node_tags: Array[StringName] = [&"State.Stunned"]
	registry.set_node_tags(actor, node_tags)
	assert_true(
		registry.get_node_tags(actor).has_tag(&"State.Incapacitated", true),
		"Direct node tags should resolve a retired name to its replacement",
	)

	root.remove_child(actor)
	actor.free()
	registry.set_database(_make_test_database())


func _test_reference_index() -> void:
	var scan_root: String = _make_scan_fixture()
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tags([&"State.Stunned", &"State.Stunned.Heavy", &"Team.Enemy", &"Damage.Fire"])

	var index: Dictionary[StringName, PackedStringArray] = GameplayTagReferenceIndex.scan(
		database, scan_root
	)

	assert_eq(index[&"State.Stunned"].size(), 2, "A tag used twice should record both locations")
	assert_true(
		index[&"State.Stunned"][0].ends_with(":2"),
		"A recorded location should carry the line number it was found on",
	)
	assert_eq(
		index[&"Team.Enemy"].size(),
		1,
		"A tag referenced only through a scene file should still be found",
	)
	# Line 3 of the fixture names this tag only through GameplayTagIds, line 4 only as a
	# literal. Finding both is what makes the index usable for scripts as well as scenes.
	var heavy_locations: PackedStringArray = index[&"State.Stunned.Heavy"]
	assert_eq(heavy_locations.size(), 2, "A tag should be found through constant and literal")
	assert_true(
		heavy_locations.has(scan_root.path_join("gameplay.gd") + ":3"),
		"A tag referenced only through its generated constant should be found",
	)
	assert_true(
		heavy_locations.has(scan_root.path_join("gameplay.gd") + ":4"),
		"A tag referenced as a quoted literal should be found",
	)

	# Damage.Fire is unused and Damage exists only to parent it, so the whole branch is
	# dead. State and Team are equally unreferenced by name but hold up used children,
	# which is exactly the noise that would make this report useless.
	var unused: Array[StringName] = GameplayTagReferenceIndex.find_unused_tags(index)
	assert_eq(
		unused,
		[&"Damage", &"Damage.Fire"] as Array[StringName],
		"An entirely unreferenced branch should be reported as dead",
	)
	assert_false(
		unused.has(&"State"), "A parent whose child is referenced should not count as dead"
	)

	_remove_directory(scan_root)


func _test_reference_migration() -> void:
	var scan_root: String = _make_scan_fixture()
	var script_path: String = scan_root.path_join("gameplay.gd")

	var files: PackedStringArray = PackedStringArray([script_path])
	var changes: Dictionary[String, int] = GameplayTagReferenceIndex.migrate_tag(
		&"State.Stunned", &"Condition.Disabled", files
	)
	assert_eq(changes.size(), 1, "Migration should report the one file it rewrote")

	var migrated: String = FileAccess.get_file_as_string(script_path)
	assert_true(
		migrated.contains('"Condition.Disabled"'),
		"Migration should rewrite a quoted tag literal",
	)
	assert_true(
		migrated.contains("GameplayTagIds.CONDITION_DISABLED"),
		"Migration should rewrite the generated constant too",
	)
	assert_false(migrated.contains('"State.Stunned"'), "The old quoted literal should be gone")

	# The whole point of matching whole tokens: neighbouring names must survive.
	assert_true(
		migrated.contains('"State.Stunned.Heavy"'),
		"Migrating a parent must not corrupt a child tag literal",
	)
	assert_true(
		migrated.contains("GameplayTagIds.STATE_STUNNED_HEAVY"),
		"Migrating a parent must not corrupt a child tag constant",
	)
	assert_true(
		migrated.contains("StateStunnedMachine"),
		"An unrelated identifier containing the tag text must be untouched",
	)

	_remove_directory(scan_root)


func _test_redirect_driven_migration() -> void:
	var scan_root: String = _make_scan_fixture()
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	database.add_tags([&"State.Stunned", &"State.Stunned.Heavy", &"Team.Enemy"])
	assert_true(database.rename_tag(&"State.Stunned", &"Condition.Disabled"))

	# The rename records redirects; migration then walks that table and rewrites files,
	# which is the step that lets a redirect eventually be retired.
	var changes: Dictionary[String, int] = GameplayTagReferenceIndex.migrate_redirected_tags(
		database, scan_root
	)
	assert_eq(changes.size(), 1, "Migration should rewrite the one file naming retired tags")

	var migrated: String = FileAccess.get_file_as_string(scan_root.path_join("gameplay.gd"))
	assert_true(migrated.contains('"Condition.Disabled"'), "The retired parent should be rewritten")
	assert_true(
		migrated.contains('"Condition.Disabled.Heavy"'),
		"A retired child should be rewritten to its new branch",
	)
	assert_true(
		migrated.contains("GameplayTagIds.CONDITION_DISABLED_HEAVY"),
		"A retired child constant should be rewritten too",
	)
	assert_false(migrated.contains("State.Stunned"), "No retired name should survive migration")
	assert_true(
		migrated.contains("StateStunnedMachine"),
		"Migration must still leave unrelated identifiers alone",
	)

	# Nothing names the retired tags any more, so a second pass has no work to do.
	var second_pass: Dictionary[String, int] = GameplayTagReferenceIndex.migrate_redirected_tags(
		database, scan_root
	)
	assert_true(second_pass.is_empty(), "A completed migration should be idempotent")

	_remove_directory(scan_root)


# Writes a small throwaway project tree so scanning and migration run against real
# files without touching anything in the repository.
func _make_scan_fixture() -> String:
	var scan_root: String = "user://tag_reference_fixture"
	_remove_directory(scan_root)
	DirAccess.make_dir_recursive_absolute(scan_root)

	var script_source: String = (
		"extends Node\n"
		+ 'var blocked: StringName = &"State.Stunned"\n'
		+ "var heavy: StringName = GameplayTagIds.STATE_STUNNED_HEAVY\n"
		+ 'var child: StringName = &"State.Stunned.Heavy"\n'
		+ "var stunned_again: StringName = GameplayTagIds.STATE_STUNNED\n"
		+ 'var unrelated: String = "StateStunnedMachine"\n'
	)
	_write_fixture_file(scan_root.path_join("gameplay.gd"), script_source)

	var scene_source: String = (
		'[gd_scene format=3]\n\n[node name="Enemy" type="Node"]\n'
		+ 'owned_tags = Array[StringName]([&"Team.Enemy"])\n'
	)
	_write_fixture_file(scan_root.path_join("enemy.tscn"), scene_source)
	return scan_root


func _write_fixture_file(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not create fixture file at %s" % path)
		return
	file.store_string(contents)
	file.close()


func _remove_directory(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if not directory.current_is_dir():
			directory.remove(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
