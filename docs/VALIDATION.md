# Local Validation

The addon uses a pure GDScript runtime and editor workflow.

Validation runs locally with the scripts under `tools/linux/`.

## Complete smoke suite

Run the complete suite with the default Godot executable:

```bash
tools/linux/check_gdscript.sh
```

`check_gdscript.sh` delegates to the complete `test_addon.sh` suite, which runs:

1. `tests/test_gameplay_tags.gd` headlessly.
2. `tests/test_editor_workflows.gd` headlessly for dock/autoload regressions.
3. `tests/test_runtime_edge_cases.gd` headlessly for CSV, mutation, trigger, and overlap paths.
4. `tests/test_editor_picker_interactions.gd` in a headless editor for Inspector picker interactions.
5. A headless editor/plugin load check.

Script-test output is scanned for parser, compile, and runtime script errors even when Godot exits
with status 0.

## Supported versions

Run the suite against both configured local Godot versions:

```bash
tools/linux/test_all_godot_versions.sh
```

The supported versions are Godot 4.6.3 and Godot 4.7.

## Performance and packaging

Run the performance regression smoke test, build the addon package, and test it in a clean project:

```bash
tools/linux/benchmark.sh
tools/linux/package_addon.sh
tools/linux/test_package_install.sh
```

The benchmark fails above a deliberately generous 5,000 ms regression ceiling. Override it for a
known slower machine with `BENCHMARK_MAX_TOTAL_MS=<milliseconds>`.

Override the Godot executable when needed:

```bash
GODOT_BIN=/path/to/godot tools/linux/check_gdscript.sh
```
