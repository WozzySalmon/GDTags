# Gameplay Tags for Godot

A Godot 4.6 addon for hierarchical gameplay tags, inspired by Unreal Gameplay Tags.

## Runtime shape

The addon currently ships both:

- GDScript editor/prototype runtime:
  - `GameplayTag`
  - `GameplayTagDatabase`
  - `GameplayTagContainer`
  - `GameplayTagQuery`
  - `GameplayTags` autoload singleton
  - Editor dock for adding/removing tags
- C++ GDExtension runtime:
  - `NativeGameplayTag`
  - `NativeGameplayTagDatabase`
  - `NativeGameplayTagContainer`
  - `NativeGameplayTagQuery`
  - `NativeGameplayTagRegistry`

The native classes use a `Native` prefix while the editor UI remains GDScript, matching the planned hybrid architecture.

## Quick usage

```gdscript
var tags := GameplayTags.make_container([
    "State.Stunned",
    "Team.Enemy",
])

print(tags.has("State")) # true, hierarchical match
print(tags.has_exact("State")) # false

var query := GameplayTags.make_query_all(["State", "Team.Enemy"])
print(tags.matches_query(query)) # true
```

`GameplayTags` automatically uses the native C++ runtime when the GDExtension is available, and falls back to the GDScript runtime when it is not:

```gdscript
print(GameplayTags.get_runtime_backend()) # "native" or "gdscript"

var container := GameplayTags.make_container(["State.Stunned"])
print(container.has("State")) # true
```

Native classes can also be used directly after the GDExtension is built/loaded:

```gdscript
var container := NativeGameplayTagContainer.new()
container.add("State.Stunned")
print(container.has("State")) # true
```

The plugin stores its database path in `ProjectSettings` at:

```text
gameplay_tags/database_path
```

Default database path:

```text
res://gameplay_tags_database.tres
```

## Tests

From the project root, run the pure GDScript runtime smoke test headlessly:

```powershell
& "C:\Users\Big-Boi\Desktop\Game develpoment Programs\Godot_v4.6.3-stable_win64.exe" --headless --path "C:\Users\Big-Boi\PI projects\gameplay-tags" --script res://tests/test_gameplay_tags.gd
```

## Native C++ runtime

Build instructions and native benchmark commands live in the project-root `NATIVE.md`.

The build follows the Godot 4.6 GDExtension guide and the official `godot-cpp-template` layout: `SConstruct` builds into `bin/<platform>/`, installs into `addons/gameplay_tags/bin/<platform>/`, and `gameplay_tags.gdextension` uses relative library paths.

The editor database stays as a GDScript resource for easy editing/saving; the autoload mirrors it into a native database at runtime when native classes are available.
