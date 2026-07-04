# Gameplay Tags Project Instructions

When editing this project, follow these rules.

## GDScript style

- Follow `docs/GDSCRIPT_STYLE.md` and Godot's official GDScript style guide:
  https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Use typed function signatures and typed variables when inference is unclear.
- Keep code readable as simple gameplay-tag gates where possible: "has tag -> yes/no -> continue/stop".

## Gameplay Tags conventions

- Use the `GameplayTags` autoload for containers, queries, and database operations.
- Do not directly mutate `GameplayTagDatabase.tags` from editor/runtime code. Use `add_tag()`, `remove_tag()`, and `ensure_parent_tags()`.
- Editor plugin scripts are `@tool`; any Resource/RefCounted script whose methods are called by editor tool code must also be `@tool`.
- Keep native C++ runtime and GDScript runtime behavior in parity. If normalization or query behavior changes, update both sides and add/adjust tests.

## Project layout

- `addons/gameplay_tags/` - addon files that users install.
- `src/` - C++ GDExtension source.
- `tests/` and `benchmarks/` - validation and performance scripts.
- `docs/` - style, packaging, and native build docs.
- `tools/linux/` - Linux build/test/lint commands.
- `tools/windows/` - Windows build/test/lint/package commands.

## Validation

- After GDScript edits, run:

```bash
tools/linux/check_gdscript.sh
tools/linux/test_native.sh
```

- After C++ edits, run:

```bash
tools/linux/dev_native.sh
```

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
