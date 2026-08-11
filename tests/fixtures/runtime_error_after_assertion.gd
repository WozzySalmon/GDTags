extends "res://tests/tag_test_case.gd"


func _suite_name() -> String:
	return "GDSCRIPT_GAMEPLAY_TAGS_HARNESS_PROBE"


func _run_tests() -> void:
	run_test("runtime_error_after_assertion", _test_runtime_error_after_assertion)


func _test_runtime_error_after_assertion() -> void:
	assert_true(true, "The probe must reach an assertion before its runtime error")
	var missing_object: Object
	missing_object.call("this_method_does_not_exist")
	assert_true(false, "A runtime error should abort before this assertion")
