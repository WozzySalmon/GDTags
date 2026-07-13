# Gameplay Tags for Godot

Godot 4.6+ addon for Unreal-style hierarchical gameplay tags.

## What it adds

- `GameplayTags` autoload: central database and gameplay helper API.
- `GameplayTagDatabase`: global registry saved at `res://gameplay_tags_database.tres` by default.
- Gameplay Tags dock: browse nested tags and add, describe, rename, search, or remove them.
- Inspector picker: select single or multiple tags from the same nested central database tree.
- CSV import/export from the Gameplay Tags dock.
- Generated `GameplayTagIds` constants for autocomplete-safe script checks.
- `GameplayTagComponent`: attach to nodes that own tags.
- Optional direct node tags stored in metadata and the `gameplay_tagged_nodes` group.
- `GameplayTagTrigger3D`: Area3D helper for tag-gated overlap events.

## Basic usage

Add a `GameplayTagComponent` child to your player/enemy/item node and pick `owned_tags` in
the Inspector.

```gdscript
if GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM_ENEMY):
	attack(enemy)

if GameplayTags.target_has_tag(player, GameplayTagIds.STATE_STUNNED):
	return
```

For quick prototypes, tag a node directly:

```gdscript
GameplayTags.add_tag_to_node(enemy, GameplayTagIds.TEAM_ENEMY)
```

When you add/remove tags in the dock, the addon regenerates `res://gameplay_tag_ids.gd`.
Type `GameplayTagIds.` in the script editor to get autocomplete for valid tags.

Hierarchical matching is enabled by default:

```gdscript
# Enemy owns Team.Enemy.
GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM) # true
GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM, true) # false, exact check
```

## Trigger example

```gdscript
func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, GameplayTagIds.TEAM_ENEMY):
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

Generated constants setting:

```text
gameplay_tags/generated_tag_ids_path
```

Default:

```text
res://gameplay_tag_ids.gd
```

## Tests

```bash
tools/linux/check_gdscript.sh
```
