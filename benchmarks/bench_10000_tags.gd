extends SceneTree

const TAG_COUNT := 10000
const RNG_SEED := 0xC0FFEE


func _init() -> void:
	var database := GameplayTagDatabase.new()
	var tag_names: Array[String] = []
	tag_names.resize(TAG_COUNT)

	for index in range(TAG_COUNT):
		tag_names[index] = "Perf.Group%03d.Tag%05d" % [index % 100, index]

	var add_start := Time.get_ticks_usec()
	database.add_tags(tag_names)
	var add_usec := Time.get_ticks_usec() - add_start

	for tag_name in tag_names:
		if not database.has_tag(tag_name):
			push_error("Missing added tag: %s" % tag_name)
			quit(1)
			return

	var container := GameplayTagContainer.new(tag_names)
	var match_start := Time.get_ticks_usec()
	for index in range(TAG_COUNT):
		container.has_tag("Perf.Group%03d" % [index % 100])
	var match_usec := Time.get_ticks_usec() - match_start

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var removal_order: Array[String] = tag_names.duplicate()
	for index in range(removal_order.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: String = removal_order[index]
		removal_order[index] = removal_order[swap_index]
		removal_order[swap_index] = temporary

	var remove_start := Time.get_ticks_usec()
	database.remove_tags(removal_order)
	var remove_usec := Time.get_ticks_usec() - remove_start

	for tag_name in tag_names:
		if database.has_tag(tag_name):
			push_error("Expected removed leaf tag: %s" % tag_name)
			quit(1)
			return

	var total_usec := add_usec + match_usec + remove_usec
	print("METRIC count=%d" % TAG_COUNT)
	print("METRIC database_tags_with_parents=%d" % database.tags.size())
	print("METRIC add_ms=%.3f" % (add_usec / 1000.0))
	print("METRIC hierarchical_match_ms=%.3f" % (match_usec / 1000.0))
	print("METRIC remove_random_ms=%.3f" % (remove_usec / 1000.0))
	print("METRIC total_ms=%.3f" % (total_usec / 1000.0))
	quit(0)
