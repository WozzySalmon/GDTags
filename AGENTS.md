# Gameplay Tags Project Instructions

When editing this project, follow these rules.

## GDScript style

- Follow `GDSCRIPT_STYLE.md` and Godot's official GDScript style guide:
  https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Use typed function signatures and typed variables when inference is unclear.
- Keep code readable as simple gameplay-tag gates where possible: "has tag -> yes/no -> continue/stop".

## Gameplay Tags conventions

- Use the `GameplayTags` autoload for containers, queries, and database operations.
- Do not directly mutate `GameplayTagDatabase.tags` from editor/runtime code. Use `add_tag()`, `remove_tag()`, and `ensure_parent_tags()`.
- Editor plugin scripts are `@tool`; any Resource/RefCounted script whose methods are called by editor tool code must also be `@tool`.
- Keep native C++ runtime and GDScript runtime behavior in parity. If normalization or query behavior changes, update both sides and add/adjust tests.

## Validation

- After GDScript edits, run:

```bat
check_gdscript_windows.cmd
test_native_windows.cmd
```

- After C++ edits, close Godot if the DLL is loaded, then run:

```bat
dev_native_windows.cmd
```

- Optional style tools if `gdtoolkit` is installed:

```bat
format_gdscript_windows.cmd
lint_gdscript_windows.cmd
```
