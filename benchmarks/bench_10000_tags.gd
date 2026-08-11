extends SceneTree

const GameplayTagsScript: Script = preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")

const TAG_COUNT: int = 10000
const TARGET_CHECK_COUNT: int = 100000
const RNG_SEED: int = 0xC0FFEE


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

	for tag_name in tag_names:
		if not database.has_tag(tag_name):
			push_error("Missing added tag: %s" % tag_name)
			quit(1)
			return

	var container: GameplayTagContainer = GameplayTagContainer.new(tag_names)
	var lookup_start: int = Time.get_ticks_usec()
	for index in range(TAG_COUNT):
		container.has_tag(&"Perf.Group%03d" % [index % 100])
	var lookup_usec: int = Time.get_ticks_usec() - lookup_start

	var target_tags: Array[StringName] = []
	target_tags.assign(tag_names.slice(0, 16))
	var component: GameplayTagComponent = GameplayTagComponent.new()
	component.validate_with_database = false
	component.owned_tags = target_tags
	var actor: Node = Node.new()
	actor.add_child(component)
	var facade: Node = GameplayTagsScript.new()
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

	if (
		not facade.target_has_tag(component, requested_parent)
		or not facade.target_has_tag(actor, requested_parent)
		or not facade.target_has_tag(target_container, requested_parent)
	):
		push_error("Target-check benchmark setup did not match its known parent tag")
		quit(1)
		return

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
			push_error("Expected removed leaf tag: %s" % tag_name)
			quit(1)
			return

	var target_check_usec: int = component_check_usec + node_check_usec + container_check_usec
	var total_usec: int = add_usec + lookup_usec + target_check_usec + remove_usec
	print("METRIC count=%d" % TAG_COUNT)
	print("METRIC target_check_count=%d" % TARGET_CHECK_COUNT)
	print("METRIC database_peak_tags_with_parents=%d" % database_peak_tags_with_parents)
	print("METRIC database_tags_after_removal=%d" % database.tags.size())
	print("METRIC add_ms=%.3f" % (add_usec / 1000.0))
	print("METRIC cached_hierarchy_lookup_ms=%.3f" % (lookup_usec / 1000.0))
	print("METRIC component_target_check_ms=%.3f" % (component_check_usec / 1000.0))
	print("METRIC node_target_check_ms=%.3f" % (node_check_usec / 1000.0))
	print("METRIC container_target_check_ms=%.3f" % (container_check_usec / 1000.0))
	print("METRIC batch_remove_ms=%.3f" % (remove_usec / 1000.0))
	print("METRIC total_ms=%.3f" % (total_usec / 1000.0))
	quit(0)
