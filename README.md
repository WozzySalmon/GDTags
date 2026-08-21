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
2. Add global tags in the **Gameplay Tags** dock. Select a parent and choose **Add Child**
   to extend its hierarchy.
3. Add a `GameplayTagComponent` child to any gameplay node.
4. Pick the component's `owned_tags` from the central database in the Inspector.
5. Check tags in gameplay code using generated constants:

```gdscript
if GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM_ENEMY):
	attack(enemy)

if GameplayTags.target_has_tag(player, GameplayTagIds.STATE_STUNNED):
	return
```

The dock regenerates `res://gameplay_tag_ids.gd` after each add, rename, remove, paste, or
import, so script autocomplete shows valid constants after `GameplayTagIds.`. CSV import and
export from the dock are optional, for moving tags between projects.

## Area triggers

Gate a `body_entered` signal on a tag check:

```gdscript
func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, GameplayTagIds.TEAM_ENEMY):
		return
	print("Enemy entered trigger")
```

## Public API

- `GameplayTags.get_database()` - central `GameplayTagDatabase` resource.
- `GameplayTags.target_has_tag(target: Object, tag: StringName, exact: bool = false)`.
- `GameplayTags.get_owned_gameplay_tags(target: Object)`.
- `GameplayTags.target_has_any(target: Object, tags: Array[StringName], exact: bool = false)`.
- `GameplayTags.target_has_all(target: Object, tags: Array[StringName], exact: bool = false)`.
- `GameplayTags.add_tag(...)`, `add_tags(...)`, `remove_tag(...)`, and `rename_tag(...)` mutate the central catalog.
- `GameplayTags.ensure_parent_tags(...)` restores missing hierarchy parents.
- `GameplayTags.set_tag_description(tag: StringName, description: String, save_now: bool = true)`.
- `GameplayTags.make_container(...)` and `make_query_all(...)` / `make_query_any(...)` / `make_query_none(...)` build runtime checks.
- `GameplayTags.get_tagged_nodes(root)`.
- `GameplayTags.get_nodes_with_tag(root: Node, tag: StringName, exact: bool = false)`.
- `GameplayTags.import_tags_from_csv(path)` / `export_tags_to_csv(path)`.
- `GameplayTagComponent` - the only way nodes own tags; attach it as a direct child.

Target resolution is explicit. Checks accept a `GameplayTagContainer`, a
`GameplayTagComponent`, or a node with direct component children. They do not inspect arbitrary
methods, properties, metadata, or nested descendants.

`GameplayTags` is the singleton used by gameplay code. The same script registers
`GameplayTagRegistry` as its class name so addon code and typed helpers can refer to the singleton's
concrete type.

Use `StringName` for individual tags and explicit `Array[StringName]` variables for collections.
The API does not convert arbitrary values into tag strings. Change component tags with `add_tag()`,
`add_tags()`, `remove_tag()`, `remove_tags()`, or `set_owned_gameplay_tags()` rather than mutating
`owned_tags` in place. Batch component and query mutations send one change notification. Replacing
an existing filtered tag set with the same values sends none.

An empty tag list satisfies `has_all()` and `target_has_all()`. Entries that normalize to an empty
name are ignored by these `ALL` checks and do not satisfy `has_any()`.

## Project layout

```text
addons/gameplay_tags/   Addon files users install into Godot projects
docs/                   Packaging and style notes
tests/                  Headless Godot smoke tests
benchmarks/             Runtime benchmark scripts
tools/linux/            Linux lint/test/benchmark/package helpers
tools/windows/          Windows test/package helpers
```


## Development commands

```bash
tools/linux/check_gdscript.sh
```

Test the configured Godot versions and run the performance benchmark:

```bash
tools/linux/test_all_godot_versions.sh
tools/linux/benchmark.sh
```

Windows development checks:

```bat
tools\windows\check_gdscript.cmd
tools\windows\test_addon.cmd
```

Build ZIPs and run clean-install checks only for a final release candidate. See
`docs/PACKAGING.md` for the Linux and Windows package commands.

## Docs

- `addons/gameplay_tags/README.md` - how to use the addon. It ships inside the package
  as the guide for installing users.
- `docs/VALIDATION.md` - local validation, compatibility matrix, benchmarks, and how to
  check an engine API against the supported Godot versions.
- `docs/PACKAGING.md` - release/package notes.
- `docs/GDSCRIPT_STYLE.md` - GDScript style guide for this repo.
- `docs/PROJECT_MAP.md` - where things live, for anyone changing the code.
- `AGENTS.md` - what to use and what not to use when editing this project.
- `REVIEW_FINDINGS.md` - resolved review history and its last recorded validation snapshot.
