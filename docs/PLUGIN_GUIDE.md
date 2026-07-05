# Gameplay Tags Plugin Guide

This document explains what the Gameplay Tags plugin does, how to use it, and how the pieces fit together.

The addon is a GDScript-first, Unreal-style gameplay tag workflow for Godot 4.6+:

- One central tag database for the whole project.
- Inspector pickers backed by that database.
- `GameplayTagComponent` nodes that own tags.
- `GameplayTags` autoload helpers for gameplay checks.
- Generated `GameplayTagIds` constants so gameplay code does not depend on typo-prone strings.
- `GameplayTagTrigger3D` for Area3D tag-gated overlap events.

Native C++/GDExtension code is intentionally deferred. The current plugin is pure GDScript.

## Core idea

Gameplay tags are hierarchical names:

```text
Entity
Entity.Player
Entity.Enemy
State.Stunned
Damage.Fire
```

If a node owns `Entity.Player`, it also matches `Entity` unless you request an exact match.

```gdscript
GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY) # true if body owns Entity.Player
GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY, true) # exact only
```

This gives you simple gameplay checks:

```gdscript
func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY_PLAYER):
		return

	print("Player entered")
```

Examples that use constants like `GameplayTagIds.ENTITY_PLAYER` assume the matching tag, such as
`Entity.Player`, exists in your central database. Your constants are generated from your project's
actual tags.

## Project files the plugin manages

By default the addon uses these project files:

```text
res://gameplay_tags_database.tres
res://gameplay_tag_ids.gd
```

`gameplay_tags_database.tres` is the central registry of all valid tags.

`gameplay_tag_ids.gd` is generated from the database and contains constants such as:

```gdscript
@tool
class_name GameplayTagIds
extends RefCounted

const ENTITY := &"Entity"
const ENTITY_PLAYER := &"Entity.Player"
const STATE_STUNNED := &"State.Stunned"
```

Use those constants in scripts instead of raw strings:

```gdscript
GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY_PLAYER)
```

That gives Godot script autocomplete after typing:

```gdscript
GameplayTagIds.
```

## Project settings

The plugin uses these project settings:

```text
gameplay_tags/database_path
gameplay_tags/generated_tag_ids_path
```

Defaults:

```text
gameplay_tags/database_path = res://gameplay_tags_database.tres
gameplay_tags/generated_tag_ids_path = res://gameplay_tag_ids.gd
```

Most projects can leave these alone.

## Enabling the plugin

1. Copy/install the addon so the project has:

   ```text
   addons/gameplay_tags/plugin.cfg
   ```

2. Enable it in Godot:

   ```text
   Project > Project Settings > Plugins > Gameplay Tags
   ```

3. The plugin adds:

   - `GameplayTags` autoload.
   - Gameplay Tags dock.
   - Inspector tag picker for supported tag properties.
   - Generated `GameplayTagIds` constants.

## Gameplay Tags dock

The dock is where you manage the global tag database.

It lets you:

- Search existing tags.
- Add tags.
- Remove tags and their children.
- Save the central database.
- Regenerate `GameplayTagIds` constants.

When you add a child tag, missing parents are created automatically.

Example: adding this tag:

```text
Entity.Player.Local
```

also creates:

```text
Entity
Entity.Player
```

The database prevents duplicate tags and invalid tag names.

## Tag naming rules

Tags are normalized before storage/checks.

Normalization does this:

- Trims leading/trailing whitespace.
- Converts `/` and `\` to `.`.
- Removes leading/trailing dots.
- Removes spaces inside tag segments.
- Sorts/deduplicates tag arrays.

Valid tag segments use:

```text
A-Z a-z 0-9 _ -
```

Recommended project convention:

```text
Entity.Player
Entity.Enemy
State.Stunned
State.Invulnerable
Damage.Fire
Ability.Cooldown
```

## Inspector tag picker

The plugin adds a picker button for supported tag arrays. The picker reads from the central database, so you select valid tags instead of typing freeform strings.

Supported Inspector properties:

```text
GameplayTagComponent.owned_tags
GameplayTagTrigger3D.required_tags
GameplayTagContainer.tags
GameplayTagQuery.tags
```

The picker gives you:

- Search.
- Multi-select.
- Clear button.
- Status text showing known/invalid tags.
- Tooltips from tag descriptions when present.

The picker intentionally does not hijack every random `Array[StringName]` in the project. It only appears on known gameplay tag types/properties.

## GameplayTagComponent

Add `GameplayTagComponent` as a child of any node that should own tags.

Common setup:

```text
Player
└── GameplayTagComponent
```

Pick the component's `owned_tags` in the Inspector.

Important exported properties:

```gdscript
@export var owned_tags: Array[StringName]
@export var validate_with_database: bool = true
```

When `validate_with_database` is true, the component rejects tags that are not in the central database.

Useful methods:

```gdscript
component.add_tag(GameplayTagIds.STATE_STUNNED)
component.remove_tag(GameplayTagIds.STATE_STUNNED)
component.has_tag(GameplayTagIds.STATE)
component.has_any([GameplayTagIds.STATE_STUNNED, GameplayTagIds.STATE_ROOTED])
component.has_all([GameplayTagIds.ENTITY_PLAYER, GameplayTagIds.STATE_INVULNERABLE])
component.get_owned_gameplay_tags()
```

Signal:

```gdscript
owned_tags_changed(tags: Array[StringName])
```

## GameplayTags autoload

`GameplayTags` is the main runtime API. Use it from gameplay scripts.

### Check a target for one tag

```gdscript
if GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY_PLAYER):
	print("player")
```

Exact match only:

```gdscript
if GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY_PLAYER, true):
	print("exact player tag")
```

### Get all tags from a target

```gdscript
var tags := GameplayTags.get_owned_gameplay_tags(body)

if tags.has_tag(GameplayTagIds.STATE_STUNNED):
	return
```

### Check any/all

```gdscript
if GameplayTags.target_has_any(body, [GameplayTagIds.ENTITY_PLAYER, GameplayTagIds.ENTITY_ALLY]):
	print("friendly")

if GameplayTags.target_has_all(body, [GameplayTagIds.ENTITY_PLAYER, GameplayTagIds.STATE_INVULNERABLE]):
	print("invulnerable player")
```

### Area3D helpers

```gdscript
var enemies := GameplayTags.get_overlapping_bodies_with_tag(area, GameplayTagIds.ENTITY_ENEMY)
var first_player := GameplayTags.get_first_overlapping_target_with_tag(area, GameplayTagIds.ENTITY_PLAYER)
```

Available helpers:

```gdscript
GameplayTags.get_overlapping_bodies_with_tag(area, tag, exact := false)
GameplayTags.get_overlapping_areas_with_tag(area, tag, exact := false)
GameplayTags.get_first_overlapping_target_with_tag(area, tag, exact := false)
```

### Database helpers

```gdscript
GameplayTags.get_database()
GameplayTags.reload_database()
GameplayTags.save_database()
GameplayTags.add_tag(tag, description := "", save_now := true)
GameplayTags.remove_tag(tag, remove_children := false, save_now := true)
GameplayTags.get_all_tags()
GameplayTags.find_tags("player")
GameplayTags.is_valid_tag(tag)
GameplayTags.request_tag(tag)
```

## How `GameplayTags` finds tags on a target

You can pass a `Node`, `GameplayTagComponent`, `GameplayTagContainer`, `GameplayTag`, or array of tags.

For nodes, `GameplayTags` looks for tags in this order:

1. The object is a `GameplayTagComponent`.
2. The object has `get_owned_gameplay_tags()`.
3. The object has `get_gameplay_tags()`.
4. The object has a known property:
   - `owned_tags`
   - `gameplay_tags`
   - `tags`
5. The object has metadata named `gameplay_tags`.
6. The node has a child `GameplayTagComponent` somewhere under it.

This means the recommended pattern is simple:

```text
ActorRoot
└── GameplayTagComponent
```

Then any script receiving `ActorRoot` can check:

```gdscript
GameplayTags.target_has_tag(actor_root, GameplayTagIds.ENTITY_PLAYER)
```

## GameplayTagContainer

`GameplayTagContainer` stores a set of tags and performs fast hierarchical checks.

Example:

```gdscript
var tags := GameplayTagContainer.new([GameplayTagIds.ENTITY_PLAYER])

tags.has_tag(GameplayTagIds.ENTITY) # true
tags.has_tag(GameplayTagIds.ENTITY, true) # false
tags.has_exact(GameplayTagIds.ENTITY_PLAYER) # true
```

Useful methods:

```gdscript
container.add_tag(tag)
container.add_tags(tags)
container.remove_tag(tag)
container.remove_tags(tags)
container.clear()
container.has_tag(tag, exact := false)
container.has_exact(tag)
container.has_any(tags, exact := false)
container.has_all(tags, exact := false)
container.is_empty()
container.get_tags()
container.to_array()
container.duplicate_container()
```

## GameplayTagQuery

`GameplayTagQuery` represents reusable tag requirements.

Modes:

```text
ALL
ANY
NONE
```

Examples:

```gdscript
var must_be_player := GameplayTagQuery.all([GameplayTagIds.ENTITY_PLAYER])
var hostile_or_neutral := GameplayTagQuery.any([GameplayTagIds.ENTITY_ENEMY, GameplayTagIds.ENTITY_NEUTRAL])
var not_stunned := GameplayTagQuery.none([GameplayTagIds.STATE_STUNNED])

if must_be_player.matches(body):
	print("player")
```

Exact query:

```gdscript
var exact_player := GameplayTagQuery.exact_all([GameplayTagIds.ENTITY_PLAYER])
```

## GameplayTagTrigger3D

`GameplayTagTrigger3D` is an `Area3D` that only emits tagged overlap signals when the entering body/area matches required tags.

Exported properties:

```gdscript
@export var required_tags: Array[StringName]
@export var match_mode: MatchMode # ALL or ANY
@export var exact_match: bool = false
@export var trigger_once: bool = false
```

Signals:

```gdscript
tagged_body_entered(body: Node)
tagged_area_entered(area: Area3D)
```

Example:

```gdscript
func _on_tagged_body_entered(body: Node) -> void:
	print("Matching body entered: ", body.name)
```

You can also query overlaps manually:

```gdscript
var matching_bodies := trigger.get_matching_overlapping_bodies()
var matching_areas := trigger.get_matching_overlapping_areas()
```

## Generated constants and autocomplete

Godot cannot autocomplete inside arbitrary strings:

```gdscript
GameplayTags.target_has_tag(body, "Entity.Player") # typo-prone
```

The plugin handles this by generating real GDScript constants:

```gdscript
GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY_PLAYER)
```

This mirrors the same general idea Unreal uses in C++: gameplay tags are central data, but code usually references native symbols/constants instead of raw strings.

If autocomplete does not immediately show a new tag:

1. Click **Regenerate IDs** in the Gameplay Tags dock.
2. Save the project.
3. Wait for Godot's filesystem scan, or reopen the script/project.

## Runtime examples

### Body entered trigger

```gdscript
func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not GameplayTags.target_has_tag(body, GameplayTagIds.ENTITY_PLAYER):
		return

	print("Player entered")
```

### Damage gate

```gdscript
func can_damage(target: Node) -> bool:
	if GameplayTags.target_has_tag(target, GameplayTagIds.STATE_INVULNERABLE):
		return false
	if GameplayTags.target_has_tag(target, GameplayTagIds.STATE_DEAD):
		return false
	return true
```

### Team check

```gdscript
func is_enemy(target: Node) -> bool:
	return GameplayTags.target_has_tag(target, GameplayTagIds.TEAM_ENEMY)
```

### Temporary runtime tag

```gdscript
@onready var tags: GameplayTagComponent = $GameplayTagComponent

func stun() -> void:
	tags.add_tag(GameplayTagIds.STATE_STUNNED)

func clear_stun() -> void:
	tags.remove_tag(GameplayTagIds.STATE_STUNNED)
```

## What the plugin does not do yet

Current intentional limits:

- No native C++/GDExtension backend.
- No visual graph/query builder beyond simple `GameplayTagQuery` resources/code.
- Inspector picker is limited to known gameplay tag classes/properties.
- No multiplayer replication layer; replicate your gameplay state using your project's networking approach.
- No automatic migration from Godot groups; tags are their own central database.

## Recommended workflow

1. Define global tags in the Gameplay Tags dock.
2. Use the Inspector picker to assign tags to `GameplayTagComponent` nodes and trigger/query resources.
3. Use `GameplayTagIds.*` constants in code.
4. Use `GameplayTags.target_has_tag()` / `target_has_any()` / `target_has_all()` for gameplay gates.
5. Use `GameplayTagTrigger3D` for Area3D overlap gates.
6. Keep tags centralized; do not directly edit database arrays from gameplay code.
