# Gameplay Tags Project Instructions

When editing this project, follow these rules.

## GDScript style

- Follow `docs/GDSCRIPT_STYLE.md` and Godot's official GDScript style guide:
  https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Use typed function signatures and typed variables when inference is unclear.
- Keep code readable as simple gameplay-tag gates where possible: "has tag -> yes/no -> continue/stop".

## Gameplay Tags conventions

- Use the `GameplayTags` autoload for target checks, containers, queries, and database operations.
- Do not directly mutate `GameplayTagDatabase.tags` from editor/runtime code. Use `add_tag()`, `remove_tag()`, and `ensure_parent_tags()`.
- Editor plugin scripts are `@tool`; any Resource/RefCounted script whose methods are called by editor tool code must also be `@tool`.
- Native C++ is deferred in the clean restart. Do not restore the old backend-first implementation unless explicitly asked; build future native code from the current public API.

## Project layout

- `addons/gameplay_tags/` - addon files that users install.
- `tests/` and `benchmarks/` - validation and performance scripts.
- `docs/` - style, packaging, and restart notes.
- `tools/linux/` - Linux build/test/lint commands.
- `tools/windows/` - Windows test/lint/package commands.

## Validation

- After GDScript edits, run:

```bash
tools/linux/check_gdscript.sh
tools/linux/test_native.sh
```

- `tools/linux/test_native.sh` is a compatibility name; it now runs GDScript/editor smoke tests.

- To smoke-test the configured Godot versions, run:

```bash
tools/linux/test_all_godot_versions.sh
```

- Optional style tools if `gdtoolkit` is installed:

```bash
tools/linux/format_gdscript.sh
tools/linux/lint_gdscript.sh
```

- Windows validation/packaging uses the Windows scripts:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_native.cmd
tools\windows\dev_native.cmd
tools\windows\package_addon.cmd
```
