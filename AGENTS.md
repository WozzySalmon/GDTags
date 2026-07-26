# Gameplay Tags Project Instructions

When editing this project, follow these rules.

## Always-on invariants

- Follow `docs/GDSCRIPT_STYLE.md` and Godot's official GDScript style guide.
- Write explicit types on every variable, constant, function parameter, and return value; do not use `:=`.
- Use the `GameplayTags` autoload for target checks, containers, queries, and database operations.
- Do not directly mutate `GameplayTagDatabase.tags`; use its mutation methods so hierarchy and signals stay correct.
- Editor plugin scripts are `@tool`; Resources and RefCounted scripts called by editor tool code must also be `@tool`.
- Keep the addon implementation pure GDScript.

## Context and workflow

- For non-trivial work, start with `docs/PROJECT_MAP.md`. Select the smallest matching task route,
  inspect its entry point and nearest tests, and expand only through relevant callers and dependencies.
  The map is a navigation aid; current source and tests are authoritative.
- Before editing, define the observable behavior, important boundaries, and invariant. For behavioral
  bugs, reproduce the failure and add a focused regression test first when practical.
- Implement the smallest coherent change. Validate from cheapest and narrowest to broadest, and let
  every check finish against a stable source snapshot; never edit files while a check is running.
- Load the matching project skill for detailed typing, editor, regression, or validation procedures.
  Treat `docs/VALIDATION.md` and `docs/PACKAGING.md` as the canonical command references.
- During cleanup, remove generated or ignored artifacts only. Preserve substantive untracked drafts
  and backlogs unless the user explicitly names them for deletion.
