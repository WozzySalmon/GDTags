extends SceneTree
## Shared harness for every gameplay tag test script.
##
## Each test file extends this and implements [method _run_tests], calling
## [method run_test] once per case. Assertion helpers, registry setup, database
## save/restore, and the pass/fail reporting all live here so no test file
## reimplements them. The copies used to drift, and one of them was missing the
## guard that fails a test which asserts nothing.

const GameplayTagsScript: Script = preload("res://addons/gameplay_tags/runtime/gameplay_tags.gd")


class ScriptErrorLogger:
	extends Logger

	var script_error_count: int = 0
	var last_script_error: String = ""

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace],
	) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		script_error_count += 1
		last_script_error = rationale if not rationale.is_empty() else code


var registry: Node
var _assertion_count: int = 0
var _failed: bool = false
var _skipped_count: int = 0
var _previous_database: GameplayTagDatabase
var _previous_database_path: String
var _script_error_logger: ScriptErrorLogger


func _init() -> void:
	_script_error_logger = ScriptErrorLogger.new()
	OS.add_logger(_script_error_logger)
	call_deferred("_run_all_tests")


## Implemented by each test file: call [method run_test] once per case.
func _run_tests() -> void:
	push_error("%s does not implement _run_tests()" % get_script().resource_path)


## Name printed on success, and the label used if the suite reports a failure.
func _suite_name() -> String:
	return "GDSCRIPT_GAMEPLAY_TAGS_TEST"


## Overridden by files that need specific tags registered.
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


## Runs one case, then reports it. A case fails when it records no assertions or emits
## a script runtime error, including an error after one or more successful assertions.
func run_test(test_name: String, test_callable: Callable) -> void:
	if _failed:
		_skipped_count += 1
		return
	var assertions_before: int = _assertion_count
	var script_errors_before: int = _script_error_logger.script_error_count
	test_callable.call()
	if _failed:
		return
	if _script_error_logger.script_error_count > script_errors_before:
		_fail(
			(
				"%s raised a script runtime error: %s"
				% [test_name, _script_error_logger.last_script_error]
			)
		)
		return
	if _assertion_count == assertions_before:
		_fail("%s ran no assertions, so it aborted before verifying anything" % test_name)
		return
	print("PASS %s" % test_name)


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


## Marks the suite failed. Remaining cases are counted as skipped; cleanup and the
## nonzero exit happen after the suite returns so every failure uses the same path.
func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)


func _run_all_tests() -> void:
	registry = _get_or_create_registry()
	_previous_database = registry.get_database()
	_previous_database_path = registry.get_database_path()
	registry.set_database(_make_test_database())

	# Awaited so a suite containing an async case still finishes before reporting.
	# Awaiting a non-coroutine simply continues.
	await _run_tests()

	registry.set_database_path(_previous_database_path)
	registry.set_database(_previous_database)
	_remove_script_error_logger()
	if _failed:
		print(
			(
				"%s failed (%d assertions, %d skipped cases)"
				% [_suite_name(), _assertion_count, _skipped_count]
			)
		)
		quit(1)
		return
	print("%s passed (%d assertions)" % [_suite_name(), _assertion_count])
	quit(0)


func _remove_script_error_logger() -> void:
	if _script_error_logger == null:
		return
	OS.remove_logger(_script_error_logger)
	_script_error_logger = null


func _get_or_create_registry() -> Node:
	var existing: Node = root.get_node_or_null("GameplayTags")
	if existing != null:
		return existing

	var new_registry: Node = GameplayTagsScript.new()
	new_registry.name = "GameplayTags"
	root.add_child(new_registry)
	return new_registry
