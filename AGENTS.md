# Gameplay Tags Project Instructions

When editing this project, follow these rules.

## GDScript style

- Follow `docs/GDSCRIPT_STYLE.md` and Godot's official GDScript style guide:
  https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Write explicit types on every variable, constant, function parameter, and return value; do not use `:=`.
- Use `Variant` only in narrow adapters for dynamic Godot engine values, then validate and convert immediately.
- Keep code readable as simple gameplay-tag gates where possible: "has tag -> yes/no -> continue/stop".

## Gameplay Tags conventions

- Use the `GameplayTags` autoload for target checks, containers, queries, and database operations.
- Do not directly mutate `GameplayTagDatabase.tags` from editor/runtime code. Use `add_tag()`, `remove_tag()`, and `ensure_parent_tags()`.
- Editor plugin scripts are `@tool`; any Resource/RefCounted script whose methods are called by editor tool code must also be `@tool`.
- Keep the addon implementation pure GDScript.

## Project layout

- `addons/gameplay_tags/` - addon files that users install.
- `tests/` and `benchmarks/` - validation and performance scripts.
- `docs/` - usage, style, and packaging notes.
- `tools/linux/` - Linux build/test/lint commands.
- `tools/windows/` - Windows test/lint/package commands.

## Validation

- After GDScript edits, run:

```bash
tools/linux/check_gdscript.sh
```

- To smoke-test the configured Godot versions, run:

```bash
tools/linux/test_all_godot_versions.sh
```

- To validate the packaged release ZIP in a clean temporary project, run:

```bash
tools/linux/test_package_install.sh
```

- Optional style tools if `gdtoolkit` is installed:

```bash
tools/linux/format_gdscript.sh
tools/linux/lint_gdscript.sh
```

- Windows validation/packaging uses the Windows scripts:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_addon.cmd
tools\windows\package_addon.cmd
```
