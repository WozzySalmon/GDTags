# Audit gameplay-tags review findings before the next release

> **Status: closed.** Every confirmed defect and coverage gap below has since been
> implemented. This file is kept as the evidence trail for that work, not as a to-do
> list — read it as history. Individual items carry follow-up notes where later work
> changed the conclusion.

## Context

A first-pass AI review reported several runtime, editor, and test concerns. A second independent pass checked those claims against the current code, documentation, tests, and Godot 4.7 behavior.

This issue separates reproducible defects from intentional/documented behavior so later reviewers can agree or disagree against concrete evidence rather than the original review wording.

## Confirmed defects

### 1. `validate_with_database = false` is lost through the autoload target helpers

**Files:**

- `addons/gameplay_tags/runtime/gameplay_tags.gd`, `get_owned_gameplay_tags()` and `_filter_container_to_database()`
- `addons/gameplay_tags/runtime/gameplay_tag_component.gd`, `validate_with_database`

Both the component and direct-node APIs explicitly allow callers to opt out of database validation:

```gdscript
component.validate_with_database = false
component.add_tag(&"Custom.Unregistered")

GameplayTags.set_node_tags(node, [&"Custom.Unregistered"], false)
```

The raw holders retain these tags, but `GameplayTags.get_owned_gameplay_tags()` always passes the result through `_filter_container_to_database()`. Consequently, the recommended target helpers report a different answer from the component/container:

```text
component.has_tag(&"Custom")                         -> true
GameplayTags.target_has_tag(component, &"Custom")   -> false
```

This makes the public validation opt-out ineffective when callers use the documented `GameplayTags.target_has_*` API.

**Expected:** validation occurs on writes when requested. Reads and target checks preserve tags accepted through an explicit `validate_with_database = false`/`validate_with_database: false` path.

**Suggested fix:** stop filtering resolved target containers in `get_owned_gameplay_tags()`. Keep database filtering in write APIs whose validation argument is `true`. Add regression coverage for both a component with validation disabled and direct node metadata written with validation disabled.

### 2. Generated-ID output can overwrite an unrelated script

**Files:**

- `addons/gameplay_tags/editor/gameplay_tag_code_generator.gd`, `save_tag_ids()`
- `addons/gameplay_tags/plugin.gd`, `_ensure_tag_ids_script()`

`gameplay_tags/generated_tag_ids_path` is configurable. `save_tag_ids()` opens that path with `FileAccess.WRITE` without checking the existing file. Enabling the plugin, opening it, or selecting **Regenerate IDs** can therefore truncate a hand-written script if the setting points to it.

Observed with Godot 4.7:

```text
save_error=0
sentinel_preserved=false
```

The database path already refuses to overwrite an incompatible resource. Generated code needs an equivalent ownership check.

**Expected:** an existing file is overwritten only when it is recognizably owned by this generator.

**Suggested fix:** add a stable generated-file marker and refuse replacement unless the existing file contains that marker and the expected generated class declaration. Return a clear error/status message. Add tests for a generated file that may be updated and an unrelated file that must remain byte-for-byte unchanged.

### 3. Dock search advertises description matching but only searches names

**Files:**

- `addons/gameplay_tags/editor/tag_editor_dock.gd`, search tooltip and `_refresh()`
- `addons/gameplay_tags/resources/gameplay_tag_database.gd`, `find_tags()`

The search box tooltip says `Filter tags by name or description`, but `GameplayTagDatabase.find_tags()` checks only `String(tag).to_lower().contains(needle)`.

**Expected:** either include the lowercased description in `find_tags()` or change the UI text to promise name-only matching. Description search is the more useful behavior and matches the current UI contract.

## Confirmed consistency and coverage improvements

These are not data-loss/runtime correctness defects, but they are concrete gaps.

### 4. Adding a tag bypasses editor undo/redo

`tag_editor_dock.gd::_on_add_pressed()` mutates the database directly. Description edits, renames, and removals use `EditorUndoRedoManager`; additions do not.

**Suggested fix:** build the post-add database state and commit it through `_apply_database_state()` when an undo manager is available. Keep the direct path for contexts without an editor undo manager.

### 5. Picker interaction tests do not assert the selected value

`tests/test_editor_picker_interactions.gd` invokes the single- and multi-picker selection callbacks, but only asserts that the `Tree` root was not rebuilt. A regression that stops the picker from emitting `State.Stunned` would still pass.

**Suggested fix:** observe `EditorProperty.property_changed`/the relevant change signal and assert the emitted single value and multi-value array, including deselection.

### 6. Physics overlap test relies on exactly two frames

`tests/test_runtime_edge_cases.gd::_test_overlap_helpers_and_trigger_once()` waits for exactly two `physics_frame` signals before checking overlaps.

**Suggested fix:** poll for the expected overlap for a small bounded number of physics frames, then fail with a diagnostic naming the missing body/area. This keeps the test deterministic while tolerating engine/physics-backend scheduling differences.

### 7. Empty query semantics lack query-level tests

Container semantics imply:

- `ALL([])` matches a valid target.
- `ANY([])` does not match.
- `NONE([])` matches.

`GameplayTagQuery.matches()` delegates to those operations, but its public constructors are not directly covered for empty lists.

**Suggested fix:** add explicit assertions for all three modes against a real `GameplayTagContainer`.

### 8. Package-install smoke script violates the repository typing rule

`tools/linux/test_package_install.sh` generates:

```gdscript
var registry := root.get_node_or_null("GameplayTags")
```

The project requires explicit types and prohibits `:=`, including validation scripts.

**Suggested fix:** use:

```gdscript
var registry: Node = root.get_node_or_null("GameplayTags")
```

## Claims checked and not accepted as defects

The following first-pass findings should not be treated as confirmed issues without a deliberate API/design change:

1. **Autosave defaults are a bug:** rejected. `save_now = true` is documented; `add_tags()` and CSV import save once per batch, and callers can pass `false` when batching individual operations.
2. **Property-based target discovery is accidental:** not established. `TAG_PROPERTY_NAMES` and the plain-object tests show this is an intentional adapter, though the common `tags` name is an API-collision risk worth documenting separately if desired.
3. **Database rename/removal must rewrite scenes and scripts:** rejected as a bug. `docs/PLUGIN_GUIDE.md` explicitly states that existing scene/resource values and script constant names are not rewritten automatically.
   - *Superseded.* Still correct that this was not a defect, but it was later shipped as a feature: renames record a redirect so retired names keep resolving, and **Tools > Migrate Renamed Tags** rewrites the references on request. Rewriting is opt-in, never automatic.
4. **`GameplayTagQuery.matches()` must not use the autoload:** rejected. Accepting object targets is part of the documented API; raw containers remain directly matchable without resolution.
5. **Generated output path is fixed:** incorrect. The path is configurable through `gameplay_tags/generated_tag_ids_path`; only the generated global class name is fixed.
6. **Missing `_exit_tree()` group removal is a leak:** rejected. Godot removes node group membership on tree exit.
7. **Refresh skips `_refresh()` when the registry exists:** incorrect. `_refresh()` is outside the `if`/`else` and runs after either reload path.
8. **Removing a node tag should validate against the database:** rejected. Removal must remain able to clean up stale or deliberately unregistered values.
9. **Spaces should be rejected rather than normalized:** rejected. Space removal is an explicit normalization rule in `docs/PLUGIN_GUIDE.md`.
10. **Constant-name collisions must roll back valid database imports/adds:** not established. The documented design permits a database update to succeed while generated-ID regeneration reports a collision, then asks the user to resolve it. Changing this would be a product decision, not a straightforward bug fix.
11. **Generated IDs rewrite on every database change signal:** incorrect. Generation is called by plugin setup and explicit dock mutation/regeneration paths; there is no database `tags_changed` connection that regenerates on every signal.

## Acceptance criteria

- Unregistered tags intentionally accepted through validation opt-out paths remain visible to `GameplayTags.get_owned_gameplay_tags()` and `target_has_*`.
- Generated-ID writes refuse to alter unrelated existing files and clearly report the refusal.
- Dock searches find matching descriptions or stop advertising description matching.
- Tag creation participates in editor undo/redo.
- Picker tests assert emitted values, overlap tests use bounded condition polling, and empty query semantics are covered.
- Generated package smoke GDScript uses explicit types and contains no `:=`.
- Focused runtime/editor tests and package-install validation pass on the configured Godot versions.
