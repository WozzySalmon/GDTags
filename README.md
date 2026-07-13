# GDTags

Gameplay Tags addon for Godot 4.6+, rebuilt around the Unreal Gameplay Tags workflow:
central registry, inspector picker, tag components on nodes, optional direct node tags, and simple yes/no gameplay checks.

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
5. Optionally import/export simple CSV tag lists from the dock.
6. Check tags in gameplay code using generated constants:

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
- `GameplayTags.target_has_tag(target: Object, tag: StringName, exact: bool = false)`.
- `GameplayTags.get_owned_gameplay_tags(target: Object)`.
- `GameplayTags.target_has_any(target: Object, tags: Array[StringName], exact: bool = false)`.
- `GameplayTags.target_has_all(target: Object, tags: Array[StringName], exact: bool = false)`.
- `GameplayTags.set_tag_description(tag: StringName, description: String, save_now: bool = true)`.
- `GameplayTags.rename_tag(tag: StringName, new_tag: StringName, save_now: bool = true)`.
- `GameplayTags.add_tag_to_node(node, tag)` - optional metadata/group tagging.
- `GameplayTags.get_tagged_nodes(root)`.
- `GameplayTags.get_nodes_with_tag(root: Node, tag: StringName, exact: bool = false)`.
- `GameplayTags.import_tags_from_csv(path)` / `export_tags_to_csv(path)`.
- `GameplayTags.get_overlapping_bodies_with_tag(area: Area3D, tag: StringName, exact: bool = false)`.
- `GameplayTagComponent` - attach to nodes to own tags.
- `GameplayTagTrigger3D` - Area3D helper that emits only for matching tagged targets.

The runtime API is deliberately strict: use `StringName` for individual tags and explicitly
written `Array[StringName]` variables for tag collections. Arbitrary values are not converted
into tag strings.

## Project layout

```text
addons/gameplay_tags/   Addon files users install into Godot projects
docs/                   Packaging and style notes
tests/                  Headless Godot smoke tests
benchmarks/             Runtime benchmark scripts
tools/linux/            Linux lint/test/benchmark/package helpers
tools/windows/          Windows test/package helpers
```

Native GDExtension code is intentionally deferred in this clean restart. The workflow is
GDScript-first until the editor/runtime UX is solid.

## Development commands

```bash
tools/linux/check_gdscript.sh
tools/linux/test_native.sh      # compatibility name; runs GDScript/editor smoke tests
```

Smoke-test configured Godot versions, run the benchmark, and build a package:

```bash
tools/linux/test_all_godot_versions.sh
tools/linux/benchmark.sh
tools/linux/package_addon.sh
```

Windows:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_native.cmd
tools\windows\package_addon.cmd
```

## Docs

- `docs/PLUGIN_GUIDE.md` - full plugin behavior and usage guide.
- `addons/gameplay_tags/README.md` - addon usage notes.
- `docs/PACKAGING.md` - release/package notes.
- `docs/CI.md` - CI automation and local validation notes.
- `docs/GDSCRIPT_STYLE.md` - GDScript style guide for this repo.
