# GDTags

Gameplay Tags addon for Godot 4.6+, rebuilt around the Unreal Gameplay Tags workflow:
central registry, inspector picker, tag components on nodes, and simple yes/no gameplay checks.

Tags are hierarchical:

```text
State.Stunned
Damage.Fire
Team.Enemy
```

Owning `State.Stunned` also satisfies checks for `State` unless exact matching is requested.

## Workflow

1. Enable **Project > Project Settings > Plugins > Gameplay Tags**.
2. Add global tags in the **Gameplay Tags** dock.
3. Add a `GameplayTagComponent` child to any gameplay node.
4. Pick the component's `owned_tags` from the central database in the Inspector.
5. Check tags in gameplay code using generated constants:

```gdscript
if GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM_ENEMY):
	attack(enemy)

if GameplayTags.target_has_tag(player, GameplayTagIds.STATE_STUNNED):
	return
```

The dock regenerates `res://gameplay_tag_ids.gd` from the central database so script autocomplete
can show valid constants after `GameplayTagIds.`.

Area trigger helper:

```gdscript
func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, GameplayTagIds.TEAM_ENEMY):
		return
	print("Enemy entered trigger")
```

Or use `GameplayTagTrigger3D` directly and set `required_tags` in the Inspector.

## Public API

- `GameplayTags.get_database()` - central `GameplayTagDatabase` resource.
- `GameplayTags.target_has_tag(target, tag, exact := false)`.
- `GameplayTags.get_owned_gameplay_tags(target)`.
- `GameplayTags.target_has_any(target, tags, exact := false)`.
- `GameplayTags.target_has_all(target, tags, exact := false)`.
- `GameplayTags.get_overlapping_bodies_with_tag(area, tag, exact := false)`.
- `GameplayTagComponent` - attach to nodes to own tags.
- `GameplayTagTrigger3D` - Area3D helper that emits only for matching tagged targets.

## Project layout

```text
addons/gameplay_tags/   Addon files users install into Godot projects
docs/                   Packaging and style notes
tests/                  Headless Godot smoke tests
benchmarks/             Runtime benchmark scripts
tools/linux/            Linux lint/test helpers
tools/windows/          Windows test/package helpers
```

Native GDExtension code is intentionally deferred in this clean restart. The workflow is
GDScript-first until the editor/runtime UX is solid.

## Development commands

```bash
tools/linux/check_gdscript.sh
tools/linux/test_native.sh      # compatibility name; runs GDScript/editor smoke tests
```

Smoke-test configured Godot versions:

```bash
tools/linux/test_all_godot_versions.sh
```

Windows:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_native.cmd
tools\windows\package_addon.cmd
```

## Docs

- `addons/gameplay_tags/README.md` - addon usage notes.
- `docs/PACKAGING.md` - release/package notes.
- `docs/CI.md` - CI status notes.
- `docs/GDSCRIPT_STYLE.md` - GDScript style guide for this repo.
