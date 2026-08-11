# Gameplay Tags for Godot

Unreal-style hierarchical gameplay tags for Godot 4.6+, in pure GDScript.

One central database defines every valid tag. Nodes own tags through a component,
and gameplay code asks simple yes/no questions using generated constants.

```gdscript
if GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM_ENEMY):
	attack(enemy)

if GameplayTags.target_has_tag(player, GameplayTagIds.STATE_STUNNED):
	return
```

## Getting started

1. Copy this folder so `res://addons/gameplay_tags/plugin.cfg` exists.
2. Enable it in **Project > Project Settings > Plugins > Gameplay Tags**.
3. Add tags in the **Gameplay Tags** dock. Select a tag and press **Add Child** to
   extend a branch without retyping the parent path.
4. Add a `GameplayTagComponent` child to any node that should own tags, and pick its
   `owned_tags` in the Inspector.

Enabling the plugin creates the `GameplayTags` autoload, the tag database, and the
generated constants script. It refuses to replace a different autoload of the same
name, or to overwrite a file it did not generate.

## Tags are hierarchical

```text
Team.Enemy.Boss
State.Stunned
Damage.Fire
```

Owning `Team.Enemy.Boss` satisfies a check for `Team.Enemy` and for `Team`. Pass
`true` as the last argument when only an exact match should count.

```gdscript
GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM)        # true
GameplayTags.target_has_tag(enemy, GameplayTagIds.TEAM, true)  # false
```

Parents are created for you: adding `State.Stunned.Heavy` also registers `State` and
`State.Stunned`.

Tag names are normalized before storage — surrounding whitespace trimmed, `/` and `\`
turned into `.`, spaces removed inside segments. Segments may use `A-Z a-z 0-9 _ -`.

## Generated constants

Every database change regenerates `res://gameplay_tag_ids.gd`. Type `GameplayTagIds.`
in the script editor for autocomplete over valid tags, and let renames and typos
become compile-time problems rather than silent runtime misses.

## Ways to own tags

A `GameplayTagComponent` beneath the node is the normal path. For quick prototypes you
can tag a node directly:

```gdscript
GameplayTags.add_tag_to_node(enemy, GameplayTagIds.TEAM_ENEMY)
```

Any object exposing `owned_tags`, `gameplay_tags`, or a `get_owned_gameplay_tags()`
method also resolves, so plain `RefCounted` game objects work without a scene tree.

## Stacking

When the same state applies more than once, use stacks so it survives until the last
source releases it:

```gdscript
component.add_tag_stack(GameplayTagIds.STATE_POISONED)     # depth 1
component.add_tag_stack(GameplayTagIds.STATE_POISONED)     # depth 2
component.remove_tag_stack(GameplayTagIds.STATE_POISONED)  # depth 1, still poisoned
component.get_tag_count(GameplayTagIds.STATE_POISONED)
```

Depth is tracked per exact tag, so a parent never reports a child's stacks. It is
runtime state and is not saved.

## Area triggers

Tag-gated volumes are a two-line filter on the signal you already connect, in 2D or 3D:

```gdscript
func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, GameplayTagIds.TEAM_ENEMY):
		return
	start_combat(body)
```

## Renaming tags safely

Renaming a tag in the dock records a redirect from the old name to the new one, for
the tag and every child it moved. Scenes authored before the rename keep working —
the retired name resolves to its replacement instead of being dropped.

`GameplayTagDatabase.has_tag()` answers whether a name is in the current catalog, so
it returns `false` for a retired name. `GameplayTags.is_valid_tag()` is the authored-data
check: it follows redirects and returns `true` when the retired name has a valid replacement.

When you are ready to finish the job, **Tools > Migrate Renamed Tags** rewrites the
references themselves, in both scripts and scenes. Only whole tag names are replaced,
so renaming `State` will not corrupt `StateMachine`. Commit before running it.

## Finding unused tags

**Tools > Scan Tag References** reports where each tag is used and which are unused,
reading file text without loading any scene. A tag that exists only to parent a used
child is not counted as unused, so the list stays short enough to act on. The scan is
conservative: an unrelated quoted string equal to a tag may count as a reference, so
review the reported locations before removing or migrating tags.

## Debugging a query

When a `GameplayTagQuery` gives an answer you did not expect, ask it why:

```gdscript
print(vulnerable.explain(target))
```

It prints a line per clause and the tags responsible, ending in the verdict.
`validate()` separately reports unregistered tags, queries that can never match, tags
that are both required and forbidden, cycles, and trees deeper than 16 query nodes.
Empty `ALL` and `NONE` queries match by vacuous truth; an empty `ANY` never matches and
is reported by `validate()`.

## Settings

| Setting | Default |
|---|---|
| `gameplay_tags/database_path` | `res://gameplay_tags_database.tres` |
| `gameplay_tags/generated_tag_ids_path` | `res://gameplay_tag_ids.gd` |

Per-platform overrides such as `gameplay_tags/database_path.mobile` are honoured.

## Not included

No multiplayer replication layer — replicate tag state using your project's own
networking. No visual query builder. The Inspector picker cannot yet be restricted to
one branch of the hierarchy.
