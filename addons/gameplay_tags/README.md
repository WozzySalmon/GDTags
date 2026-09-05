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

Enabling the plugin creates the `GameplayTags` autoload, tag database, and generated constants
script when they are missing. It leaves an existing `GameplayTagDatabase` at the configured path
untouched and refuses to replace a different resource or autoload.

## Runnable example

A runnable script lives at `addons/gameplay_tags/examples/basic_usage.gd`. It registers the
tags it needs from code, so it also runs in a freshly installed project before any tags or
generated constants exist. Attach it to any node in your scene, run the project, and watch
the Output panel: it prints a target check, a hierarchical match, and an ALL/ANY check.
After you have created your own tags, run **Tools > Regenerate IDs** and switch gameplay
code to the generated `GameplayTagIds` constants, as the example's closing comment shows.

Use `GameplayTags` as the singleton name in gameplay code. Its script class is
`GameplayTagRegistry`, which exists for typed references to that singleton.

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

Tag names are normalized before storage. The database trims surrounding whitespace, converts `/`
and `\` to `.`, removes spaces inside segments, and drops empty segments. Segments may use
`A-Z a-z 0-9 _ -`.

An empty list satisfies `has_all()` and `target_has_all()`. Entries that normalize to an empty name,
such as a whitespace-only string, are ignored by these `ALL` checks. They do not satisfy
`has_any()`.

## Generated constants

The dock regenerates `res://gameplay_tag_ids.gd` when you add, rename, remove, paste, or
import tags, and via **Tools > Regenerate IDs**. Runtime `GameplayTags` calls do not
regenerate it. Type `GameplayTagIds.` in the script editor for autocomplete over valid
tags; renames and typos become compile-time problems instead of silent runtime misses.

## Owning tags

A node owns tags through direct `GameplayTagComponent` children. Target checks do not inspect
arbitrary methods, properties, metadata, or nested descendants. You can also check a component
or `GameplayTagContainer` directly.

When upgrading from an earlier version, move tags assigned through `set_node_tags()` or
`add_tag_to_node()` onto a component; the direct metadata APIs have been removed.

At runtime, change a component through `add_tag()`, `add_tags()`, `remove_tag()`,
`remove_tags()`, or `set_owned_gameplay_tags()`. Do not mutate `owned_tags` with `append()`, `erase()`,
or `clear()`. In-place Array changes bypass validation, signals, and the tag lookup index.

A component emits `owned_tags_changed(tags)` after an effective tag or stack update. Batch add and
remove calls emit at most once for the whole batch. Replacing the tags with the same filtered set
emits nothing.

## Stacking

When the same state applies more than once, stack it so the tag stays until the last
source releases it:

```gdscript
component.add_tag_stack(GameplayTagIds.STATE_STUNNED)     # depth 1
component.add_tag_stack(GameplayTagIds.STATE_STUNNED)     # depth 2
component.remove_tag_stack(GameplayTagIds.STATE_STUNNED)  # depth 1, still stunned
component.get_tag_count(GameplayTagIds.STATE_STUNNED)
```

Depth is tracked per exact tag, so a parent never reports a child's stacks. It is
runtime state and is not saved.

## Area triggers

Gate a `body_entered` signal on a tag check, in 2D or 3D:

```gdscript
func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, GameplayTagIds.TEAM_ENEMY):
		return
	start_combat(body)
```

## Renaming tags safely

Renaming a tag in the dock records a redirect from the old name to the new one, for
the tag and every child it moved. Scenes authored before the rename keep working.
The retired name resolves to its replacement instead of being dropped.

`GameplayTagDatabase.has_tag()` answers whether a name is in the current catalog, so
it returns `false` for a retired name. `GameplayTags.is_valid_tag()` is the authored-data
check: it follows redirects and returns `true` when the retired name has a valid replacement.

When you are ready to finish the job, **Tools > Migrate Renamed Tags** rewrites references in
scripts and scenes. Only whole tag names are replaced, so renaming `State` will not corrupt
`StateMachine`. Commit before running it.

`GameplayTagDatabase.validate()` reports missing parents and redirect problems. Empty, duplicate,
and malformed names cannot survive the database setter, so validation does not report those
unreachable states.

## Finding unused tags

**Tools > Scan Tag References** reports where each tag is used and which are unused,
reading file text without loading any scene. A tag that exists only to parent a used
child is not counted as unused, so the list stays short enough to act on. The scan is
conservative: an unrelated quoted string equal to a tag may count as a reference, so
review the reported locations before removing or migrating tags.

## Building and debugging queries

Build query resources with `GameplayTags.make_query_all()`, `make_query_any()`, or
`make_query_none()`. `matches()` accepts a container, component, or node with direct tag component
children.

```gdscript
var required_tags: Array[StringName] = [
	GameplayTagIds.STATE_STUNNED,
	GameplayTagIds.DAMAGE_FIRE,
]
var vulnerable: GameplayTagQuery = GameplayTags.make_query_all(required_tags)

if vulnerable.matches(target):
	apply_bonus_damage(target)
```

Queries also provide the static factory methods `GameplayTagQuery.all()`,
`GameplayTagQuery.any()`, `GameplayTagQuery.none()`, and `GameplayTagQuery.compose()`.
`compose()` builds one query from others:

```gdscript
var fire_or_ice: GameplayTagQuery = GameplayTagQuery.any([
	GameplayTagIds.DAMAGE_FIRE,
	GameplayTagIds.DAMAGE_ICE,
])
var guard: GameplayTagQuery = GameplayTagQuery.compose(
	GameplayTagQuery.Mode.ALL,
	[fire_or_ice, GameplayTagQuery.none([GameplayTagIds.STATE_INVULNERABLE])]
)
```

Use `add_sub_query()` to nest conditions such as "Fire or Ice, and not Immune." Batch tag
changes through `add_tags()` and `remove_tags()` emit at most one `changed` notification.

When a query gives an unexpected answer, print its trace:

```gdscript
print(vulnerable.explain(target))
```

The trace prints one line per clause, the responsible tags, and the verdict. `validate()` reports
unregistered tags, queries that can never match, tags that are both required and forbidden, cycles,
and trees deeper than 16 query nodes. Empty `ALL` and `NONE` queries match by vacuous truth. An empty
`ANY` never matches and is reported by `validate()`.

## Settings

| Setting | Default |
|---|---|
| `gameplay_tags/database_path` | `res://gameplay_tags_database.tres` |
| `gameplay_tags/generated_tag_ids_path` | `res://gameplay_tag_ids.gd` |

Per-platform overrides such as `gameplay_tags/database_path.mobile` are honoured.

## Not included

No multiplayer replication layer. Replicate tag state with your project's own
networking. No visual query builder. The Inspector picker cannot yet be restricted to
one branch of the hierarchy.
