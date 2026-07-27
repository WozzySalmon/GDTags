# Project Map

Use this file to locate the smallest relevant context for a task. Start with the routed entry point
and nearest test, then follow only evidence-relevant imports, callers, and dependencies. This map is
navigation guidance; current source and tests are authoritative.

## Task routing

| Task | Start here | Closest validation |
|---|---|---|
| Addon startup, project settings, autoload ownership, database/ID setup | `addons/gameplay_tags/plugin.gd`, `addons/gameplay_tags/plugin.cfg` | `tests/test_editor_workflows.gd`, `tools/linux/test_package_install.sh` |
| Public runtime API, database access, CSV, target checks, node tagging, overlap helpers | `addons/gameplay_tags/runtime/gameplay_tags.gd` | `tests/test_gameplay_tags.gd`, `tests/test_runtime_edge_cases.gd` |
| Tag hierarchy, descriptions, rename/removal, search, and change signals | `addons/gameplay_tags/resources/gameplay_tag_database.gd`, `addons/gameplay_tags/runtime/gameplay_tag.gd` | `tests/test_gameplay_tags.gd`, `tests/test_runtime_edge_cases.gd` |
| Containers and query matching | `addons/gameplay_tags/runtime/gameplay_tag_container.gd`, `addons/gameplay_tags/runtime/gameplay_tag_query.gd` | `tests/test_gameplay_tags.gd` |
| Target-owned tags and reusable node components | `addons/gameplay_tags/runtime/gameplay_tag_component.gd`, `addons/gameplay_tags/runtime/gameplay_tag_utils.gd` | `tests/test_gameplay_tags.gd` |
| Physics trigger behavior | `addons/gameplay_tags/runtime/gameplay_tag_trigger_3d.gd`, `addons/gameplay_tags/runtime/gameplay_tags.gd` | `tests/test_runtime_edge_cases.gd` |
| Dock tree, search, tag mutations, CSV, and undo/redo | `addons/gameplay_tags/editor/tag_editor_dock.gd` | `tests/test_editor_workflows.gd` |
| Tag redirects, stack depth, query diagnostics | `addons/gameplay_tags/resources/gameplay_tag_database.gd`, `addons/gameplay_tags/runtime/gameplay_tag_query.gd` | `tests/test_tag_lifecycle.gd` |
| Finding where tags are used, dead tags, rename migration | `addons/gameplay_tags/editor/tag_reference_index.gd` | `tests/test_tag_lifecycle.gd` |
| Inspector detection and tag pickers | `addons/gameplay_tags/editor/gameplay_tag_inspector_plugin.gd`, `addons/gameplay_tags/editor/gameplay_tag_property.gd`, `addons/gameplay_tags/editor/gameplay_tag_array_property.gd` | `tests/test_editor_picker_interactions.gd` |
| Generated `GameplayTagIds` constants and collision handling | `addons/gameplay_tags/editor/gameplay_tag_code_generator.gd`, `addons/gameplay_tags/plugin.gd` | `tests/test_gameplay_tags.gd`, `tests/test_editor_workflows.gd` |
| Formatting, linting, compatibility, benchmarks, packaging, or release readiness | `docs/VALIDATION.md`, `docs/PACKAGING.md`, `tools/linux/` | The matching script documented in those files |

## System boundaries

- `addons/gameplay_tags/plugin.gd` owns editor-time setup: project settings, the `GameplayTags`
  autoload, the central database resource, generated IDs, inspector integration, and the tag dock.
- `addons/gameplay_tags/runtime/gameplay_tags.gd` is the public autoload facade for database
  operations, containers, queries, target-owned tags, node lookup, CSV helpers, and physics overlap helpers.
- `GameplayTagDatabase` owns canonical tag mutation, hierarchy maintenance, lookup caches, and
  `tags_changed` notification. Do not bypass its mutation methods.
- Containers and queries represent runtime-owned tags and matching rules; components expose owned
  tags from nodes; the trigger applies query gates to physics overlaps.
- Editor tools must operate through the same database and public mutation boundaries as runtime code.
- Generated root resources such as `gameplay_tags_database.tres` and `gameplay_tag_ids.gd` are project
  outputs; the installable addon source remains under `addons/gameplay_tags/`.

## Validation routes

- `tests/test_gameplay_tags.gd`: primary runtime API, database, containers, queries, targets, and IDs.
- `tests/test_runtime_edge_cases.gd`: mutation, reload, autoload, and physics edge cases.
- `tests/test_editor_workflows.gd`: dock/plugin workflows and editor-facing state changes.
- `tests/test_tag_lifecycle.gd`: owner-level stack depth, tag redirects, reference scanning, migration, and query diagnostics.
- `tests/test_editor_picker_interactions.gd`: `EditorProperty` interactions; requires editor script mode.
- `benchmarks/bench_10000_tags.gd`: large-tag-set performance.
- `docs/VALIDATION.md`: canonical local commands and supported Godot versions.
- `docs/PACKAGING.md`: release ZIP contents and clean-install expectations.

## Documentation ownership

- `README.md`: concise user-facing overview and public API entry points.
- `docs/PLUGIN_GUIDE.md`: detailed behavior and usage reference.
- `docs/GDSCRIPT_STYLE.md`: canonical GDScript and project style rules.
- `docs/VALIDATION.md`: validation commands and compatibility matrix.
- `docs/PACKAGING.md`: package construction and installation rules.

Update this map only when file responsibilities, entry points, or validation ownership changes. Do not
copy implementation details here that are likely to drift.
