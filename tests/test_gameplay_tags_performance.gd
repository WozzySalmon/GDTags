@tool
extends McpTestSuite

func suite_name() -> String:
	return "gameplay_tags_performance"

func test_database_10000_benchmark_is_headless_only() -> void:
	skip("Disabled in the editor MCP test runner. Use res://benchmarks/bench_10000_tags.gd headless so a slow benchmark cannot freeze/crash the editor.")
