# Gameplay Tags — Review Resolution Record

This file replaces the stale pre-`0dd9e00` review snapshot. It is a resolution record,
not an active backlog. The original review was performed before commit `0dd9e00`
(`Fix gameplay tags review findings`), so its blocker/high wording no longer described
HEAD.

## Resolved by `0dd9e00`

- **B1, B2, H1:** dock rename redirects, package-install hangs, and generated-ID
  collision checks were fixed and covered by regression tests.
- **M1–M7, M9, M14, M15:** editor null/failure paths, undoable bulk changes,
  stack/count invariants, database validation, facade coverage, and Windows suite
  parity were fixed.
- **L3, L4, L7, L8, L10–L13, L15, L21–L23:** dead parameters, generated formatting,
  no-op signals, editor failure refresh/status behavior, file closing/plugin setup,
  picker canonicalization, API gaps, examples, and packaging scripts were fixed.

## Resolved by the follow-up working tree

- **M8:** exact catalog membership versus redirect-aware authored-data validation is
  documented in the shipping README and asserted side by side in lifecycle tests.
- **M10:** component, container, node, and adapter target checks no longer construct a
  throwaway `GameplayTagContainer`; component checks scan owned tags and direct child
  components without allocating. The benchmark now measures 100,000 checks for
  component, node, and container targets.
- **M11:** the shared test harness installs a Godot `Logger`, detects script runtime
  errors even after earlier assertions, exits nonzero, and never prints PASS. Both
  platform runners execute a deliberately failing regression fixture.
- **M12/M13:** picker tests now cover Inspector-style write-back, synchronous
  `update_property()` re-entrancy, resource mode, clear, read-only behavior, array
  write-back, and the property-editor construction used by `_parse_property()`.
- **M16:** the intentional `max-public-methods: 40` lint exception is documented; no
  lints are disabled.
- **L1/L2:** query matching, explanation, and validation now enforce the same 16-node
  depth limit without emitting per-frame runtime-error spam.
- **L5:** redundant `GameplayTagUtils` aliases and `GameplayTagQuery.exact_all()` were
  removed. The retained `GameplayTag` value-object helpers have direct tests.
- **L6:** empty-query vacuous-truth semantics are documented.
- **L9:** the conservative text reference scan and its possible false positives are
  documented in the shipping README.
- **L14:** benchmark labels now distinguish peak database size, post-removal parent
  skeleton, cached hierarchy lookup, batch removal, and target-check throughput.
- **L16:** the weak query change-signal assertion now checks the exact signal count.
- **L18/L19/L20:** failures use one cleanup path, later cases are counted as skipped,
  the registry is restored before exit, and order-dependent follow-on execution stops
  after a failure. Test-only ProjectSettings changes remain process-local and are
  restored on successful paths.
- **L24:** Windows command and PowerShell scripts now check out with CRLF line endings.
- Post-review nits were also removed: the unused CSV import helper is gone and CSV
  import failure reporting tracks database-resource and generated-ID save stages
  explicitly instead of reading status-label text as control flow.

## Intentional validation noise

Godot may print ObjectDB/resource/RID shutdown diagnostics after headless editor tests.
The platform runners reject parser, compiler, and script runtime errors specifically;
shutdown diagnostics are engine/test-process cleanup noise rather than a gameplay-tags
failure. The deliberately failing harness fixture proves that real script errors still
produce a nonzero result.

## Validation status

Godot 4.6.3 and 4.7 each pass all five suites with **434 assertions**; the runtime-error
fixture fails as expected without printing PASS. Formatting, linting, Bash syntax,
and `git diff --check` pass. The 10,000-tag benchmark passes its 5,000 ms ceiling on
both versions (about 3.9 s on 4.6 and 3.6 s on 4.7), and clean packaged-addon installs
pass on both versions.
