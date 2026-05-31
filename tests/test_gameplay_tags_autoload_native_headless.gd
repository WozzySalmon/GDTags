extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gameplay_tags := root.get_node_or_null("/root/GameplayTags")
	_assert(gameplay_tags != null, "GameplayTags autoload should exist")

	gameplay_tags.reload()
	_assert(
		gameplay_tags.is_native_runtime_enabled(),
		"GameplayTags should select native runtime when the GDExtension is available"
	)
	_assert(gameplay_tags.get_runtime_backend() == "native", "Runtime backend should report native")

	var container = gameplay_tags.make_container(["State.Stunned", "Team.Enemy"])
	_assert(container != null, "make_container should return a container")
	_assert(
		container.is_class("NativeGameplayTagContainer"),
		"make_container should return NativeGameplayTagContainer when native is enabled"
	)
	_assert(container.has("State"), "Native container should match parent tags hierarchically")
	_assert(container.has_exact("Team.Enemy"), "Native container should exact-match owned tags")

	var query = gameplay_tags.make_query_all(["State", "Team.Enemy"])
	_assert(query != null, "make_query_all should return a query")
	_assert(
		query.is_class("NativeGameplayTagQuery"),
		"make_query_all should return NativeGameplayTagQuery when native is enabled"
	)
	_assert(query.matches(container), "Native query should match native container")

	print("AUTOLOAD_NATIVE_RUNTIME_TEST passed")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
