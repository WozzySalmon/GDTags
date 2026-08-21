# Gameplay Tags project instructions

## Authority

`docs/GDSCRIPT_STYLE.md` is Godot's official style guide and is not negotiable.
`gdlint` and `gdformat` enforce it. A lint failure is a defect in your code, not in
the config. Do not edit `gdlintrc` to make your change pass.

Current source and tests outrank every document here.

## Use this, not that

| Use | Not | Why |
|---|---|---|
| `var x: int = 1` | `var x := 1` | Explicit types everywhere: variables, constants, parameters, returns. |
| `GameplayTags` autoload | `GameplayTagDatabase` directly | The autoload is the public facade for target checks, containers, queries, and database operations. |
| `add_tag()`, `add_tags()`, `remove_tag()`, `rename_tag()`, `ensure_parent_tags()` | assigning `GameplayTagDatabase.tags` | Direct assignment skips hierarchy maintenance and change signals. |
| component/query `add_tags()` and `remove_tags()` | repeated single-tag loops | Batch methods filter once and send at most one change notification. |
| `GameplayTagIds.TEAM_ENEMY` | `&"Team.Enemy"` | Generated constants survive renames and are found by the reference index. |
| `GameplayTagComponent` | node groups | Groups support the internal tag index. Do not use them to author tags. |
| `has_tag()`, `has_any()`, `has_all()`, `has_none()` | short aliases like `has()`, `any()`, `all()` | One name per operation. `GameplayTagComponent`, `GameplayTagDatabase`, and the autoload all use the long form, so aliases only add more API to document and test. |
| `GameplayTagUtils.DATABASE_SETTING` and friends | repeating `"gameplay_tags/database_path"` | Setting names and default paths live in one place. |
| `GameplayTagUtils.resolve_setting_path()` | `ProjectSettings.get_setting()` | The latter silently ignores per-platform feature-tag overrides. |
| `GameplayTagUtils.ensure_parent_directory()` and `database_path_conflicts()` | local editor copies | File creation and conflict rules must agree across plugin, dock, and code generation. |
| `TagDockTree.populate()` and `include_ancestor_tags()` | separate picker tree builders | The dock and Inspector must display the same hierarchy and search ancestors. |
| `resolve_tag()` on authored tag names | assuming the name is current | A tag renamed earlier resolves through its redirect instead of being dropped. |
| stack methods on `GameplayTagComponent` | stack methods on a resolved container | `get_owned_gameplay_tags()` returns a fresh copy; stacking it changes nothing. |
| `FileAccess.file_exists()` | `ResourceLoader.exists()` as proof of a file | `exists()` also returns true for a cache-only resource with no file behind it. |
| `tools/linux/query_godot_api.py` | the online class reference | The project targets Godot 4.6; the web docs show whatever is current. |
| `get_child_count()` with `get_child(index)` | `get_children()` in target-check loops | Indexed traversal avoids allocating a child Array for each check. |

`Variant` is for engine boundaries only. It flows through `EditorProperty` values, `Object.call`
returns, and undo/redo parameters. Convert to a concrete type at the boundary and never
propagate it into helper signatures.

`@tool` is required on editor plugin scripts *and* on every Resource or RefCounted
they call. Missing it fails silently in the editor.

The addon implementation stays pure GDScript.

## Working method

1. Start from `docs/PROJECT_MAP.md`, take the smallest matching route, and expand only
   through relevant callers.
2. State the observable behaviour and the invariant before editing. For a behavioural
   bug, reproduce it first, then write the regression test, then fix.
3. Make the smallest coherent change.
4. Validate narrow to broad against a stable snapshot. Never edit files while a check
   is running.

`docs/VALIDATION.md` and `docs/PACKAGING.md` are the canonical command references.
Run ZIP packaging and clean-install validation only for a final release candidate.

## Tests

Every test file extends `tests/tag_test_case.gd`. Do not hand-roll assertion helpers
or a runner. A test that asserts nothing must fail, and that guard lives in the base
class so it cannot be forgotten.

Add a test to the file matching its subject; add a new file only for a genuinely new
subject, and register it in `tools/linux/test_addon.sh` and `docs/VALIDATION.md`.

## Cleanup

Remove generated or ignored artifacts only. Preserve untracked drafts and backlogs
unless explicitly told to delete them.
