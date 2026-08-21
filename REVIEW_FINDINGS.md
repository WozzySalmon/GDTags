# Gameplay Tags review resolution record

This is a history of resolved review findings, not an active backlog. Current source and tests outrank
this snapshot.

## Resolved by `0dd9e00`

- `B1`, `B2`, and `H1`: fixed dock rename redirects, package-install hangs, and generated-ID
  collision checks. Regression tests cover each path.
- `M1` through `M7`, `M9`, `M14`, and `M15`: fixed editor null and failure paths, undoable bulk
  changes, stack and count invariants, database validation, facade coverage, and Windows suite
  parity.
- `L3`, `L4`, `L7`, `L8`, `L10` through `L13`, `L15`, and `L21` through `L23`: removed dead
  parameters and fixed generated formatting, no-op signals, editor failure reporting, file closing,
  plugin setup, picker canonicalization, API gaps, examples, and packaging scripts.

## Resolved by later commits

- `M8`: the shipping README distinguishes exact catalog membership from redirect-aware authored-data
  validation. Lifecycle tests assert both behaviors.
- `M10`: commit `7cd9ba4` removed method, property, and metadata adapters from target ownership.
  Nodes now own tags only through direct `GameplayTagComponent` children. Commit `2036540` made
  component, container, node, and query checks dispatch directly without temporary containers.
- `M11`: the shared test harness installs a Godot `Logger`, detects script runtime errors after prior
  assertions, exits nonzero, and never prints PASS. Both platform runners execute a deliberately
  failing fixture.
- `M12` and `M13`: picker tests cover Inspector write-back, synchronous `update_property()`
  re-entry, resource mode, clear, read-only behavior, array write-back, and the property-editor
  construction used by `_parse_property()`.
- `M16`: the intentional `max-public-methods: 40` lint exception is documented. No lints are
  disabled.
- `L1` and `L2`: query matching, explanation, and validation enforce the same 16-node depth limit
  without per-frame runtime-error spam.
- `L5`: redundant `GameplayTagUtils` aliases and `GameplayTagQuery.exact_all()` were removed. Tests
  cover the retained `GameplayTag` helpers.
- `L6`: the shipping README documents empty-query vacuous truth.
- `L9`: the shipping README documents the conservative reference scan and its possible false
  positives.
- `L14`: benchmark labels distinguish peak database size, the post-removal parent skeleton, cached
  hierarchy lookup, batch removal, target checks, bulk checks, and query matching.
- `L16`: the query change-signal test checks the exact signal count.
- `L18`, `L19`, and `L20`: failures use one cleanup path, later cases count as skipped, the registry
  is restored before exit, and execution stops after a failure. Test-only `ProjectSettings` changes
  remain process-local and are restored on successful paths.
- `L24`: Windows command and PowerShell scripts use CRLF line endings.
- The unused CSV import helper is gone. CSV import failure reporting now tracks database and
  generated-ID save stages directly instead of reading status-label text as control flow.

## Refactor simplifications

Commit `2036540` completed the architecture follow-up without changing the documented component
workflow:

- `GameplayTagQuery.matches()` evaluates containers, components, and nodes without building a
  throwaway container.
- Component and query batch mutations filter once and send at most one change notification.
  Replacing an existing filtered tag set with the same values sends none.
- `target_has_any()` and `target_has_all()` use direct component and container checks. Indexed node
  child traversal avoids allocating a child Array for each call.
- Node index refresh reads component tags directly.
- Database mutations canonicalize at the property boundary. Parent restoration collects all missing
  parents before one assignment, and `validate()` reports only reachable missing-parent and redirect
  problems.
- The `GameplayTags` autoload script registers `GameplayTagRegistry` as its concrete class. Internal
  fixed-autoload lookups use that type instead of probing methods.
- `GameplayTagUtils` owns directory creation and database path conflict checks. `TagDockTree` owns
  hierarchy population for the dock and Inspector pickers.
- Plugin startup preserves an existing database at the configured path. A regression test invokes
  the setup path directly.

## Expected validation noise

Godot may print ObjectDB, resource, or RID shutdown diagnostics after headless editor tests. The
platform runners reject parser, compiler, and script runtime errors. The deliberately failing harness
fixture proves that real script errors still produce a nonzero result.

## Validation snapshot

Godot 4.6.3 and 4.7 each pass all five suites with 450 assertions. The runtime-error fixture fails as
expected without printing PASS. Formatting, linting, Bash syntax, and `git diff --check` pass.

The expanded benchmark covers 300,000 single-tag target checks, 300,000 bulk checks, and 300,000
query matches, plus 10,000-tag database work. The final `2036540` run completed in 1836.354 ms on
Godot 4.6.3 and 1685.042 ms on Godot 4.7, below the 5,000 ms ceiling.

Package and clean-install checks passed before these refactor commits. They were not rerun afterward
because the project reserves ZIP and clean-install validation for final release candidates.
