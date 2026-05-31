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
- `tools/windows/` - Windows build/test/lint/package commands.

## Validation

- After GDScript edits, run:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_native.cmd
```

- After C++ edits, close Godot if the DLL is loaded, then run:

```bat
tools\windows\dev_native.cmd
```

- Optional style tools if `gdtoolkit` is installed:

```bat
tools\windows\format_gdscript.cmd
tools\windows\lint_gdscript.cmd
```
