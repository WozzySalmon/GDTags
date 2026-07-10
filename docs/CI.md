# CI

The previous Windows native GDExtension workflow was removed during the clean restart.
Native code is deferred; current validation is the GDScript/editor workflow smoke suite.

Recommended CI shape when runner access is available:

```bash
tools/linux/check_gdscript.sh
tools/linux/test_all_godot_versions.sh
```

`tools/linux/test_all_godot_versions.sh` runs the compatibility-named `test_native.sh` script
against configured Godot versions. That script now runs:

1. `tests/test_gameplay_tags.gd` headlessly.
2. `tests/test_editor_workflows.gd` headlessly for dock/autoload regressions.
3. A headless editor/plugin load check.

Script-test output is scanned for parser, compile, and runtime script errors even when Godot exits
with status 0.

## Hosted runner note

If GitHub Actions reports `startup_failure` with no job logs, hosted runners may be blocked by
account/billing state. Treat that as infrastructure blocked rather than a gameplay-tags failure.
