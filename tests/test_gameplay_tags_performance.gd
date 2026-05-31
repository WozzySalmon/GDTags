extends SceneTree


func _init() -> void:
	var message := (
		"GDSCRIPT_PERFORMANCE_TEST skipped; use res://benchmarks/bench_10000_tags.gd "
		+ "headless for benchmark metrics."
	)
	print(message)
	quit(0)
