# Gameplay Tags for Godot

Godot 4.6+ addon for Unreal-style hierarchical gameplay tags.

## What it adds

- `GameplayTags` autoload: central database and gameplay helper API.
- `GameplayTagDatabase`: global registry saved at `res://gameplay_tags_database.tres` by default.
- Gameplay Tags dock: add/remove/search global tags.
- Inspector picker: tag arrays are selected from the central database, not typed freeform.
- `GameplayTagComponent`: attach to nodes that own tags.
- `GameplayTagTrigger3D`: Area3D helper for tag-gated overlap events.

## Basic usage

Add a `GameplayTagComponent` child to your player/enemy/item node and pick `owned_tags` in
the Inspector.

```gdscript
if GameplayTags.target_has_tag(enemy, "Team.Enemy"):
	attack(enemy)

if GameplayTags.target_has_tag(player, "State.Stunned"):
	return
```

Hierarchical matching is enabled by default:

```gdscript
# Enemy owns Team.Enemy.
GameplayTags.target_has_tag(enemy, "Team") # true
GameplayTags.target_has_tag(enemy, "Team", true) # false, exact check
```

## Trigger example

```gdscript
func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, "Team.Enemy"):
		return
	print("Enemy entered")
```

Or add `GameplayTagTrigger3D`, set `required_tags`, and listen for:

```gdscript
func _on_tagged_body_entered(body: Node) -> void:
	print("Matching body entered: ", body.name)
```

## Database path

Project setting:

```text
gameplay_tags/database_path
```

Default:

```text
res://gameplay_tags_database.tres
```

## Tests

```bash
tools/linux/check_gdscript.sh
tools/linux/test_native.sh
```

`test_native.sh` is kept as a compatibility script name; native C++ is deferred in this clean
restart and the script runs GDScript/editor workflow smoke tests.
