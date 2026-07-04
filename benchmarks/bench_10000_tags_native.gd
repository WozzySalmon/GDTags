extends SceneTree

const TAG_COUNT := 10000
const RNG_SEED := 0xC0FFEE
const EXTENSION_PATH := "res://addons/gameplay_tags/gameplay_tags.gdextension"


func _init() -> void:
	if not ClassDB.class_exists("NativeGameplayTagDatabase"):
		var load_result := GDExtensionManager.load_extension(EXTENSION_PATH)
		if load_result != OK:
			push_error("Failed to load %s: error %s" % [EXTENSION_PATH, load_result])
			quit(1)
			return

	if not ClassDB.class_exists("NativeGameplayTagDatabase"):
		push_error("NativeGameplayTagDatabase is not available after loading %s." % EXTENSION_PATH)
		quit(1)
		return

	var tag_names: Array[String] = []
	tag_names.resize(TAG_COUNT)

	for i in range(TAG_COUNT):
		tag_names[i] = "Perf.Group%03d.Tag%05d" % [i % 100, i]

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var removal_order: Array[String] = tag_names.duplicate()
	for i in range(removal_order.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, i)
		var tmp: String = removal_order[i]
		removal_order[i] = removal_order[swap_index]
		removal_order[swap_index] = tmp

	var per_call_database = ClassDB.instantiate("NativeGameplayTagDatabase")
	var per_call_add_start := Time.get_ticks_usec()
	for tag_name in tag_names:
		per_call_database.add_tag(tag_name)
	var per_call_add_usec := Time.get_ticks_usec() - per_call_add_start
	_assert_tag_count(per_call_database, TAG_COUNT, "per-call add")

	var per_call_remove_start := Time.get_ticks_usec()
	for tag_name in removal_order:
		per_call_database.remove_tag(tag_name, false)
	var per_call_remove_usec := Time.get_ticks_usec() - per_call_remove_start
	_assert_tag_count(per_call_database, 0, "per-call remove")

	var batch_database = ClassDB.instantiate("NativeGameplayTagDatabase")
	var batch_add_start := Time.get_ticks_usec()
	var batch_added := int(batch_database.add_tags(tag_names))
	var batch_add_usec := Time.get_ticks_usec() - batch_add_start
	if batch_added != TAG_COUNT:
		push_error("Expected batch add count %d, got %d" % [TAG_COUNT, batch_added])
		quit(1)
		return
	_assert_tag_count(batch_database, TAG_COUNT, "batch add")

	var batch_remove_start := Time.get_ticks_usec()
	var batch_removed := int(batch_database.remove_tags(removal_order, false))
	var batch_remove_usec := Time.get_ticks_usec() - batch_remove_start
	if batch_removed != TAG_COUNT:
		push_error("Expected batch remove count %d, got %d" % [TAG_COUNT, batch_removed])
		quit(1)
		return
	_assert_tag_count(batch_database, 0, "batch remove")

	_print_metrics("native_per_call", per_call_add_usec, per_call_remove_usec)
	_print_metrics("native_batch", batch_add_usec, batch_remove_usec)
	if batch_add_usec > 0:
		var add_speedup := per_call_add_usec / float(batch_add_usec)
		print("METRIC native_batch_add_speedup=%.2f" % add_speedup)
	if batch_remove_usec > 0:
		var remove_speedup := per_call_remove_usec / float(batch_remove_usec)
		print("METRIC native_batch_remove_speedup=%.2f" % remove_speedup)
	quit(0)


func _assert_tag_count(database: Variant, expected: int, label: String) -> void:
	var actual := int(database.get_tags().size())
	if actual != expected:
		push_error("Expected %d tags after %s, got %d" % [expected, label, actual])
		quit(1)


func _print_metrics(prefix: String, add_usec: int, remove_usec: int) -> void:
	var total_usec := add_usec + remove_usec
	print("METRIC %s_count=%d" % [prefix, TAG_COUNT])
	print("METRIC %s_add_ms=%.3f" % [prefix, add_usec / 1000.0])
	print("METRIC %s_remove_random_ms=%.3f" % [prefix, remove_usec / 1000.0])
	print("METRIC %s_total_ms=%.3f" % [prefix, total_usec / 1000.0])
	print("METRIC %s_add_ops_per_sec=%.1f" % [prefix, TAG_COUNT / (add_usec / 1000000.0)])
	print("METRIC %s_remove_ops_per_sec=%.1f" % [prefix, TAG_COUNT / (remove_usec / 1000000.0)])
