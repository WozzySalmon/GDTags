# Native Runtime Status

Native GDExtension code was intentionally removed from the clean restart.

The project is now GDScript-first so the core Unreal-style Godot workflow can be correct before
any C++ parity work returns:

- central `GameplayTagDatabase`
- Inspector picker from that database
- `GameplayTagComponent` on nodes
- `GameplayTags.target_has_tag()` / `get_owned_gameplay_tags()` helpers
- `GameplayTagTrigger3D` Area3D helper

Compatibility script names such as `tools/linux/test_native.sh` and
`tools/windows/test_native.cmd` remain so old instructions keep working, but they now run the
GDScript/editor smoke suite.

If native performance work is reintroduced later, rebuild it from the public API in this restart
rather than restoring the removed backend-first implementation.
