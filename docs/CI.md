# CI

The addon uses a GDScript/editor workflow; native GDExtension code remains deferred.

GitHub Actions runs `.github/workflows/gdscript.yml` for pushes to `main`, pull requests, and
manual dispatches. Its matrix validates both supported Godot versions:

- Godot 4.6.3
- Godot 4.7

Each matrix job downloads the matching official Linux editor and runs:

```bash
tools/linux/check_gdscript.sh
```

`check_gdscript.sh` delegates to the complete compatibility-named `test_native.sh` suite, which
runs:

1. `tests/test_gameplay_tags.gd` headlessly.
2. `tests/test_editor_workflows.gd` headlessly for dock/autoload regressions.
3. `tests/test_runtime_edge_cases.gd` headlessly for CSV, mutation, trigger, and overlap paths.
4. A headless editor/plugin load check.
5. A packaged-addon installation smoke test in a fresh temporary Godot project.

Script-test output is scanned for parser, compile, and runtime script errors even when Godot exits
with status 0. Each matrix job also runs the 10,000-tag performance regression smoke test. The Godot
4.7 job builds, validates, and uploads the GDScript addon package. Failed Godot logs are uploaded as
workflow artifacts when available.

## Local validation

Run the same complete suite with the default Godot executable:

```bash
tools/linux/check_gdscript.sh
```

Run it against both configured local versions:

```bash
tools/linux/test_all_godot_versions.sh
```

Run the performance regression smoke test or build the addon package:

```bash
tools/linux/benchmark.sh
tools/linux/package_addon.sh
tools/linux/test_package_install.sh
```

The benchmark fails above a deliberately generous 5,000 ms regression ceiling. Override it for a
known slower runner with `BENCHMARK_MAX_TOTAL_MS=<milliseconds>`.

Override an executable when needed:

```bash
GODOT_BIN=/path/to/godot tools/linux/check_gdscript.sh
```

## Hosted runner note

If GitHub Actions reports `startup_failure` with no job logs, hosted runners may be blocked by
account/billing state. Treat that as infrastructure blocked rather than a gameplay-tags failure.
