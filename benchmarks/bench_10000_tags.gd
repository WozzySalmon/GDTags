extends SceneTree

const GameplayTagsScript: Script = preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")

const TAG_COUNT: int = 10000
const GROUP_COUNT: int = 100
const TARGET_CHECK_COUNT: int = 100000
const QUERY_CHECK_COUNT: int = 100000
const SINGULAR_MUTATION_COUNT: int = 250
const SINGULAR_REMOVAL_COUNT: int = 125
const COMPONENT_MUTATION_COUNT: int = 100
const MULTI_COMPONENT_COUNT: int = 4
const MULTI_COMPONENT_TAGS_PER_COMPONENT: int = 100
const MULTI_COMPONENT_CHECK_COUNT: int = 2500
const STACK_PAIR_COUNT: int = 5000
const MERGE_RESOLVE_COUNT: int = 40
const RNG_SEED: int = 0xC0FFEE

var _validation_failures: int = 0


# Setup sanity checks record failures instead of aborting with an early return: the
# shared metric printing at the end is also what reports the nonzero failure exit.
func _fail(message: String) -> void:
	push_error(message)
	_validation_failures += 1


func _init() -> void:
	var database: GameplayTagDatabase = GameplayTagDatabase.new()
	var tag_names: Array[StringName] = []
	tag_names.resize(TAG_COUNT)

	for index in range(TAG_COUNT):
		tag_names[index] = StringName(&"Perf.Group%03d.Tag%05d" % [index % 100, index])

	var add_start: int = Time.get_ticks_usec()
	database.add_tags(tag_names)
	var add_usec: int = Time.get_ticks_usec() - add_start
	var database_peak_tags_with_parents: int = database.tags.size()
	# 10,000 leaves plus their 100 Perf.GroupNNN parents plus the Perf root: this size
	# is the hierarchy contract, so a regression that drops or duplicates parents fails
	# here instead of only showing up as a slower metric.
	if database_peak_tags_with_parents != TAG_COUNT + GROUP_COUNT + 1:
		_fail(
			(
				"Unexpected peak parent-inclusive database size: %d (expected %d)"
				% [database_peak_tags_with_parents, TAG_COUNT + GROUP_COUNT + 1]
			)
		)

	for tag_name in tag_names:
		if not database.has_tag(tag_name):
			_fail("Missing added tag: %s" % tag_name)

	var container: GameplayTagContainer = GameplayTagContainer.new(tag_names)
	var lookup_tags: Array[StringName] = []
	lookup_tags.resize(TAG_COUNT)
	for index in range(TAG_COUNT):
		lookup_tags[index] = &"Perf.Group%03d" % [index % 100]
	var lookup_start: int = Time.get_ticks_usec()
	for tag in lookup_tags:
		container.has_tag(tag)
	var lookup_usec: int = Time.get_ticks_usec() - lookup_start

	var target_tags: Array[StringName] = []
	target_tags.assign(tag_names.slice(0, 16))
	var component: GameplayTagComponent = GameplayTagComponent.new()
	component.validate_with_database = false
	component.owned_tags = target_tags
	var actor: Node = Node.new()
	actor.add_child(component)
	var facade: GameplayTagRegistry = root.get_node_or_null("GameplayTags") as GameplayTagRegistry
	if facade == null:
		facade = GameplayTagsScript.new()
		facade.name = "GameplayTags"
		root.add_child(facade)
	root.add_child(actor)
	var requested_parent: StringName = &"Perf.Group000"

	var component_check_start: int = Time.get_ticks_usec()
	for _index in range(TARGET_CHECK_COUNT):
		facade.target_has_tag(component, requested_parent)
	var component_check_usec: int = Time.get_ticks_usec() - component_check_start

	var node_check_start: int = Time.get_ticks_usec()
	for _index in range(TARGET_CHECK_COUNT):
		facade.target_has_tag(actor, requested_parent)
	var node_check_usec: int = Time.get_ticks_usec() - node_check_start

	var target_container: GameplayTagContainer = GameplayTagContainer.new(target_tags)
	var container_check_start: int = Time.get_ticks_usec()
	for _index in range(TARGET_CHECK_COUNT):
		facade.target_has_tag(target_container, requested_parent)
	var container_check_usec: int = Time.get_ticks_usec() - container_check_start

	var query_tags: Array[StringName] = [requested_parent, tag_names[0]]
	var component_bulk_start: int = Time.get_ticks_usec()
	for _index in range(TARGET_CHECK_COUNT):
		facade.target_has_all(component, query_tags)
	var component_bulk_usec: int = Time.get_ticks_usec() - component_bulk_start

	var node_bulk_start: int = Time.get_ticks_usec()
	for _index in range(TARGET_CHECK_COUNT):
		facade.target_has_all(actor, query_tags)
	var node_bulk_usec: int = Time.get_ticks_usec() - node_bulk_start

	var container_bulk_start: int = Time.get_ticks_usec()
	for _index in range(TARGET_CHECK_COUNT):
		facade.target_has_all(target_container, query_tags)
	var container_bulk_usec: int = Time.get_ticks_usec() - container_bulk_start

	if (
		not facade.target_has_all(component, query_tags)
		or not facade.target_has_all(actor, query_tags)
		or not facade.target_has_all(target_container, query_tags)
	):
		_fail("Bulk target-check benchmark setup did not match its known tags")

	var query: GameplayTagQuery = GameplayTagQuery.all(query_tags)
	var component_query_start: int = Time.get_ticks_usec()
	for _index in range(QUERY_CHECK_COUNT):
		query.matches(component)
	var component_query_usec: int = Time.get_ticks_usec() - component_query_start

	var node_query_start: int = Time.get_ticks_usec()
	for _index in range(QUERY_CHECK_COUNT):
		query.matches(actor)
	var node_query_usec: int = Time.get_ticks_usec() - node_query_start

	var container_query_start: int = Time.get_ticks_usec()
	for _index in range(QUERY_CHECK_COUNT):
		query.matches(target_container)
	var container_query_usec: int = Time.get_ticks_usec() - container_query_start

	var query_setup_error: String = ""
	if not query.matches(component):
		query_setup_error = "component"
	elif not query.matches(actor):
		query_setup_error = "node"
	elif not query.matches(target_container):
		query_setup_error = "container"
	if not query_setup_error.is_empty():
		_fail("Query benchmark %s did not match its known tags" % query_setup_error)

	var orphan_database: GameplayTagDatabase = GameplayTagDatabase.new()
	orphan_database.tags = tag_names
	var ensure_parent_start: int = Time.get_ticks_usec()
	orphan_database.ensure_parent_tags()
	var ensure_parent_usec: int = Time.get_ticks_usec() - ensure_parent_start
	if not orphan_database.has_tag(&"Perf") or not orphan_database.has_tag(requested_parent):
		_fail("Parent restoration benchmark did not create the known ancestors")

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var removal_order: Array[StringName] = tag_names.duplicate()
	for index in range(removal_order.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: StringName = removal_order[index]
		removal_order[index] = removal_order[swap_index]
		removal_order[swap_index] = temporary

	var remove_start: int = Time.get_ticks_usec()
	database.remove_tags(removal_order)
	var remove_usec: int = Time.get_ticks_usec() - remove_start

	for tag_name in tag_names:
		if database.has_tag(tag_name):
			_fail("Expected removed leaf tag: %s" % tag_name)

	# Batch removal only removes the tags it was given, so the parent skeleton must
	# survive intact: the 100 group parents plus the Perf root.
	if database.tags.size() != GROUP_COUNT + 1:
		_fail(
			(
				"Unexpected retained parent skeleton size: %d (expected %d)"
				% [database.tags.size(), GROUP_COUNT + 1]
			)
		)

	# --- Singular database mutation -------------------------------------------
	# add_tag() and remove_tag() one call at a time against the parent skeleton left
	# by the batch removal: every singular call re-collects, canonicalizes, and
	# re-sorts the whole catalog, so this is the path small projects actually hit.
	var singular_database: GameplayTagDatabase = GameplayTagDatabase.new()
	var singular_tags: Array[StringName] = []
	singular_tags.resize(SINGULAR_MUTATION_COUNT)
	for index in range(SINGULAR_MUTATION_COUNT):
		singular_tags[index] = StringName(&"Perf.Single%04d" % index)

	var singular_start: int = Time.get_ticks_usec()
	for tag_name in singular_tags:
		singular_database.add_tag(tag_name)
	var singular_peak_size: int = singular_database.tags.size()
	for index in range(SINGULAR_REMOVAL_COUNT):
		singular_database.remove_tag(singular_tags[index])
	var singular_usec: int = Time.get_ticks_usec() - singular_start

	if singular_database.tags.size() != singular_peak_size - SINGULAR_REMOVAL_COUNT:
		_fail("Singular mutation benchmark left an unexpected catalog size")
	if singular_database.has_tag(singular_tags[0]):
		_fail("Singular removal benchmark did not remove its first tag")
	if not singular_database.has_tag(singular_tags[SINGULAR_MUTATION_COUNT - 1]):
		_fail("Singular addition benchmark lost its last tag")

	# --- Component add/remove -------------------------------------------------
	# Singular and batch component mutations, including the owner tag index refresh
	# each change triggers on the component's parent node.
	var mutation_owner: Node = Node.new()
	var mutation_component: GameplayTagComponent = GameplayTagComponent.new()
	mutation_component.validate_with_database = false
	mutation_owner.add_child(mutation_component)
	root.add_child(mutation_owner)

	var singular_component_tags: Array[StringName] = []
	singular_component_tags.resize(COMPONENT_MUTATION_COUNT)
	for index in range(COMPONENT_MUTATION_COUNT):
		singular_component_tags[index] = StringName(&"Perf.CompSingle%04d" % index)
	var batch_component_tags: Array[StringName] = []
	batch_component_tags.resize(COMPONENT_MUTATION_COUNT)
	for index in range(COMPONENT_MUTATION_COUNT):
		batch_component_tags[index] = StringName(&"Perf.CompBatch%04d" % index)

	var component_mutation_start: int = Time.get_ticks_usec()
	for tag_name in singular_component_tags:
		mutation_component.add_tag(tag_name)
	mutation_component.add_tags(batch_component_tags)
	for tag_name in singular_component_tags:
		mutation_component.remove_tag(tag_name)
	mutation_component.remove_tags(batch_component_tags)
	var component_mutation_usec: int = Time.get_ticks_usec() - component_mutation_start

	if not mutation_component.owned_tags.is_empty():
		_fail("Component mutation benchmark did not remove every added tag")

	# --- Multi-component has_all and query fallback ---------------------------
	# Tags are split across sibling components, so every ALL check misses on the
	# cached child pass and pays the per-tag child scan fallback.
	var fallback_owner: Node = Node.new()
	root.add_child(fallback_owner)
	var fallback_required: Array[StringName] = []
	for component_index in range(MULTI_COMPONENT_COUNT):
		var component_tags: Array[StringName] = []
		component_tags.resize(MULTI_COMPONENT_TAGS_PER_COMPONENT)
		for tag_index in range(MULTI_COMPONENT_TAGS_PER_COMPONENT):
			component_tags[tag_index] = StringName(
				&"Perf.Multi%d.Tag%03d" % [component_index, tag_index]
			)
		var fallback_component: GameplayTagComponent = GameplayTagComponent.new()
		fallback_component.validate_with_database = false
		fallback_component.owned_tags = component_tags
		fallback_owner.add_child(fallback_component)
		fallback_required.append(component_tags[0])

	var fallback_missing: Array[StringName] = fallback_required.duplicate()
	fallback_missing.append(&"Perf.Multi9.Tag000")
	if not facade.target_has_all(fallback_owner, fallback_required):
		_fail("Multi-component fallback benchmark did not match its split tags")
	if facade.target_has_all(fallback_owner, fallback_missing):
		_fail("Multi-component fallback benchmark matched a missing tag")

	var fallback_all_start: int = Time.get_ticks_usec()
	for _index in range(MULTI_COMPONENT_CHECK_COUNT):
		facade.target_has_all(fallback_owner, fallback_required)
	var fallback_all_usec: int = Time.get_ticks_usec() - fallback_all_start

	var fallback_query: GameplayTagQuery = GameplayTagQuery.all(fallback_required)
	if not fallback_query.matches(fallback_owner):
		_fail("Multi-component fallback query did not match its split tags")
	var fallback_query_start: int = Time.get_ticks_usec()
	for _index in range(MULTI_COMPONENT_CHECK_COUNT):
		fallback_query.matches(fallback_owner)
	var fallback_query_usec: int = Time.get_ticks_usec() - fallback_query_start

	# --- Stack and container merge paths ---------------------------------------
	var stack_container: GameplayTagContainer = GameplayTagContainer.new()
	if not stack_container.add_tag(&"Perf.Stack"):
		_fail("Stack benchmark could not seed its container tag")

	var stack_start: int = Time.get_ticks_usec()
	for _index in range(STACK_PAIR_COUNT):
		stack_container.add_tag_stack(&"Perf.Stack")
		stack_container.remove_tag_stack(&"Perf.Stack")
	var stack_usec: int = Time.get_ticks_usec() - stack_start

	var stacked_owner: Node = Node.new()
	root.add_child(stacked_owner)
	var stacked_first: Array[StringName] = []
	stacked_first.assign(tag_names.slice(0, 100))
	var stacked_second: Array[StringName] = []
	stacked_second.assign(tag_names.slice(100, 200))
	var stacked_first_component: GameplayTagComponent = GameplayTagComponent.new()
	stacked_first_component.validate_with_database = false
	stacked_first_component.owned_tags = stacked_first
	var stacked_second_component: GameplayTagComponent = GameplayTagComponent.new()
	stacked_second_component.validate_with_database = false
	stacked_second_component.owned_tags = stacked_second
	stacked_owner.add_child(stacked_first_component)
	stacked_owner.add_child(stacked_second_component)
	for index in range(0, 100, 2):
		stacked_first_component.set_tag_count(tag_names[index], 2)

	var depth_check: GameplayTagContainer = facade.get_owned_gameplay_tags(stacked_owner)
	if depth_check.get_tag_count(tag_names[0]) != 2:
		_fail("Merge benchmark did not carry component stack depth")

	var merge_start: int = Time.get_ticks_usec()
	for _index in range(MERGE_RESOLVE_COUNT):
		facade.get_owned_gameplay_tags(stacked_owner)
	var merge_usec: int = Time.get_ticks_usec() - merge_start

	var target_check_usec: int = component_check_usec + node_check_usec + container_check_usec
	var bulk_check_usec: int = component_bulk_usec + node_bulk_usec + container_bulk_usec
	var query_check_usec: int = component_query_usec + node_query_usec + container_query_usec
	var total_usec: int = (
		add_usec
		+ lookup_usec
		+ target_check_usec
		+ bulk_check_usec
		+ query_check_usec
		+ ensure_parent_usec
		+ remove_usec
		+ singular_usec
		+ component_mutation_usec
		+ fallback_all_usec
		+ fallback_query_usec
		+ stack_usec
		+ merge_usec
	)
	if _validation_failures > 0:
		quit(1)
		return
	print("METRIC count=%d" % TAG_COUNT)
	print("METRIC target_check_count=%d" % TARGET_CHECK_COUNT)
	print("METRIC target_check_total=%d" % (TARGET_CHECK_COUNT * 3))
	print("METRIC bulk_target_check_total=%d" % (TARGET_CHECK_COUNT * 3))
	print("METRIC query_check_count=%d" % QUERY_CHECK_COUNT)
	print("METRIC query_check_total=%d" % (QUERY_CHECK_COUNT * 3))
	print("METRIC singular_mutation_count=%d" % SINGULAR_MUTATION_COUNT)
	print("METRIC component_mutation_count=%d" % (COMPONENT_MUTATION_COUNT * 4))
	print("METRIC multicomponent_check_count=%d" % (MULTI_COMPONENT_CHECK_COUNT * 2))
	print("METRIC stack_operation_count=%d" % (STACK_PAIR_COUNT * 2))
	print("METRIC merge_resolve_count=%d" % MERGE_RESOLVE_COUNT)
	print("METRIC database_peak_tags_with_parents=%d" % database_peak_tags_with_parents)
	print("METRIC database_tags_after_removal=%d" % database.tags.size())
	print("METRIC add_ms=%.3f" % (add_usec / 1000.0))
	print("METRIC cached_hierarchy_lookup_ms=%.3f" % (lookup_usec / 1000.0))
	print("METRIC component_target_check_ms=%.3f" % (component_check_usec / 1000.0))
	print("METRIC node_target_check_ms=%.3f" % (node_check_usec / 1000.0))
	print("METRIC container_target_check_ms=%.3f" % (container_check_usec / 1000.0))
	print("METRIC component_target_all_ms=%.3f" % (component_bulk_usec / 1000.0))
	print("METRIC node_target_all_ms=%.3f" % (node_bulk_usec / 1000.0))
	print("METRIC container_target_all_ms=%.3f" % (container_bulk_usec / 1000.0))
	print("METRIC component_query_check_ms=%.3f" % (component_query_usec / 1000.0))
	print("METRIC node_query_check_ms=%.3f" % (node_query_usec / 1000.0))
	print("METRIC container_query_check_ms=%.3f" % (container_query_usec / 1000.0))
	print("METRIC ensure_parent_tags_ms=%.3f" % (ensure_parent_usec / 1000.0))
	print("METRIC batch_remove_ms=%.3f" % (remove_usec / 1000.0))
	print("METRIC singular_database_mutation_ms=%.3f" % (singular_usec / 1000.0))
	print("METRIC component_add_remove_ms=%.3f" % (component_mutation_usec / 1000.0))
	print("METRIC multicomponent_has_all_fallback_ms=%.3f" % (fallback_all_usec / 1000.0))
	print("METRIC multicomponent_query_fallback_ms=%.3f" % (fallback_query_usec / 1000.0))
	print("METRIC container_stack_ops_ms=%.3f" % (stack_usec / 1000.0))
	print("METRIC component_merge_resolve_ms=%.3f" % (merge_usec / 1000.0))
	print("METRIC total_ms=%.3f" % (total_usec / 1000.0))
	quit(0)
