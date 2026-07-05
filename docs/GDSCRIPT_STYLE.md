# GDScript Style Guide

Project baseline: Godot's official GDScript style guide.

- Official guide: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Keep this file as the short project checklist. If this file and the official guide disagree, prefer the official guide unless this project has a specific reason not to.

## Formatting

- Use tabs for indentation, matching Godot's script editor default.
- Keep lines under 100 characters. Try for 80 when it stays readable.
- Use one statement per line.
- Use spaces around operators:

```gdscript
var damage := base_damage + bonus_damage
```

- Use trailing commas in multi-line arrays, dictionaries, and enums:

```gdscript
var blocked_tags := [
	"State.Stunned",
	"State.Dead",
]
```

## Naming

- Files: `snake_case.gd`
- Classes: `PascalCase`
- Nodes: `PascalCase`
- Functions: `snake_case()`
- Variables: `snake_case`
- Signals: `snake_case`
- Constants: `CONSTANT_CASE`
- Enum names: `PascalCase`
- Enum members: `CONSTANT_CASE`

## Code order

Use this order for GDScript files:

1. `@tool`, `@icon`, `@static_unload`
2. `class_name`
3. `extends`
4. class doc comments
5. signals
6. enums
7. constants
8. static variables
9. `@export` variables
10. regular variables
11. `@onready` variables
12. `_static_init()` and static methods
13. built-in callbacks: `_init()`, `_enter_tree()`, `_ready()`, `_process()`, `_physics_process()`, etc.
14. public methods
15. private methods
16. inner classes

## Static typing

- Prefer typed function parameters and return values:

```gdscript
func can_move() -> bool:
	return not tags.has("State.Stunned")
```

- Use `:=` when the type is obvious on the same line:

```gdscript
var direction := Vector3.FORWARD
```

- Write the type explicitly when inference would be unclear:

```gdscript
var health: int = 100
@onready var health_bar: ProgressBar = get_node("UI/HealthBar")
```

## Gameplay Tags project rules

- Use the `GameplayTags` autoload for runtime checks and database operations.
- Do not mutate `GameplayTagDatabase.tags` directly from editor/runtime code; use `add_tag()`, `remove_tag()`, and `ensure_parent_tags()`.
- Scripts used by editor plugin/tool code must be `@tool`. This includes resources whose methods are called by the editor dock.
- Prefer tag checks that read like simple yes/no gates:

```gdscript
if GameplayTags.target_has_tag(actor, "State.Stunned"):
	return
```

- Use `GameplayTagComponent` on gameplay nodes instead of freeform node groups.

## Checks

Run these before considering GDScript changes done:

```bash
tools/linux/check_gdscript.sh
tools/linux/test_native.sh # compatibility name; runs GDScript/editor smoke tests
```

On Windows, use the equivalent scripts:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_native.cmd
```

Optional formatter/linter if `gdtoolkit` is installed:

```bash
tools/linux/format_gdscript.sh
tools/linux/lint_gdscript.sh
```

```bat
tools\windows\format_gdscript.cmd
tools\windows\lint_gdscript.cmd
```
