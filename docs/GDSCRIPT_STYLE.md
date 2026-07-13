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
var damage: int = base_damage + bonus_damage
```

- Use trailing commas in multi-line arrays, dictionaries, and enums:

```gdscript
var blocked_tags: Array[StringName] = [
	&"State.Stunned",
	&"State.Dead",
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

- **Always write explicit types on variables.** Do not use `:=` inference in project code.

```gdscript
var direction: Vector3 = Vector3.FORWARD
var health: int = 100
@onready var health_bar: ProgressBar = get_node("UI/HealthBar")
```

- Write explicit types on all function parameters and return values, not just return types:

```gdscript
func can_move() -> bool:
	return not tags.has(&"State.Stunned")

func add_tag(tag: StringName) -> bool:
	...
```

- **Tag parameters:** Use `StringName` for single tags and `Array[StringName]` for collections. Use `Object` for APIs that accept Node, Resource, or custom RefCounted gameplay targets.

- **Reserve `Variant` for engine boundary code only:** EditorProperty value handling, Object.call/get return values, undo-redo manager parameter passing, and other places where Godot itself supplies or requires dynamic values. At each such `Variant`, prefer an inline comment noting the reason. Do not propagate `Variant` into internal helper signatures; convert to concrete types at the boundary.

- Explicitly type constants where GDScript allows:

```gdscript
const AUTOLOAD_NAME: String = "GameplayTags"
const TAG_COUNT: int = 10000
```

## Gameplay Tags project rules

- Use the `GameplayTags` autoload for runtime checks and database operations.
- Do not mutate `GameplayTagDatabase.tags` directly from editor/runtime code; use `add_tag()`, `remove_tag()`, and `ensure_parent_tags()`.
- Scripts used by editor plugin/tool code must be `@tool`. This includes resources whose methods are called by the editor dock.
- Prefer tag checks that read like simple yes/no gates:

```gdscript
if GameplayTags.target_has_tag(actor, GameplayTagIds.STATE_STUNNED):
	return
```

- Use `GameplayTagComponent` on gameplay nodes instead of freeform node groups.

## Checks

Run these before considering GDScript changes done:

```bash
tools/linux/check_gdscript.sh
```

On Windows, use the equivalent scripts:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_addon.cmd
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
