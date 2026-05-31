extends SceneTree

const TAG_COUNT := 10000
const RNG_SEED := 0xC0FFEE


func _init() -> void:
	var database := GameplayTagDatabase.new()
	var tag_names: Array[String] = []
	tag_names.resize(TAG_COUNT)

	for i in range(TAG_COUNT):
		tag_names[i] = "Perf.Group%03d.Tag%05d" % [i % 100, i]

	var add_start := Time.get_ticks_usec()
	for tag_name in tag_names:
		database.add_tag(tag_name)
	var add_usec := Time.get_ticks_usec() - add_start

	if database.tags.size() != TAG_COUNT:
		push_error("Expected %d added tags, got %d" % [TAG_COUNT, database.tags.size()])
		quit(1)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var removal_order: Array[String] = tag_names.duplicate()
	for i in range(removal_order.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, i)
		var tmp: String = removal_order[i]
		removal_order[i] = removal_order[swap_index]
		removal_order[swap_index] = tmp

	var remove_start := Time.get_ticks_usec()
	for tag_name in removal_order:
		database.remove_tag(tag_name, false)
	var remove_usec := Time.get_ticks_usec() - remove_start

	if database.tags.size() != 0:
		push_error("Expected 0 remaining tags, got %d" % database.tags.size())
		quit(1)
		return

	var total_usec := add_usec + remove_usec
	print("METRIC count=%d" % TAG_COUNT)
	print("METRIC add_ms=%.3f" % (add_usec / 1000.0))
	print("METRIC remove_random_ms=%.3f" % (remove_usec / 1000.0))
	print("METRIC total_ms=%.3f" % (total_usec / 1000.0))
	print("METRIC add_ops_per_sec=%.1f" % (TAG_COUNT / (add_usec / 1000000.0)))
	print("METRIC remove_ops_per_sec=%.1f" % (TAG_COUNT / (remove_usec / 1000000.0)))
	quit(0)
