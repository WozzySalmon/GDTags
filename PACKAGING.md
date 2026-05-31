# Packaging the Gameplay Tags Addon

Do not send the whole development folder. The development folder contains local build caches, `godot-cpp`, tests, benchmarks, and temporary editor files.

For normal users, send a zip that contains the addon folder:

```text
addons/gameplay_tags/plugin.cfg
addons/gameplay_tags/plugin.gd
addons/gameplay_tags/editor/
addons/gameplay_tags/resources/
addons/gameplay_tags/runtime/
addons/gameplay_tags/gameplay_tags.gdextension       # native package only
addons/gameplay_tags/bin/windows/*.dll               # native package only
```

## Package options

### Windows native package

Use this when sending to Windows users who should get the fast C++ GDExtension runtime.

```bat
package_addon_windows.cmd
```

Output:

```text
dist/gameplay_tags-<version>-windows-native.zip
```

This package includes the Windows debug and release DLLs. It does not include linker files such as `.lib` or `.exp`.

### GDScript-only package

Use this for a simple package that works without native binaries. It is slower than the native runtime, but avoids platform-specific DLL issues.

```bat
package_addon_windows.cmd -Variant gdscript -SkipBuild
```

Output:

```text
dist/gameplay_tags-<version>-gdscript.zip
```

This package excludes `gameplay_tags.gdextension` and `bin/`, so Godot will use the GDScript runtime fallback.

## Installing the package

1. Unzip the package into another Godot project.
2. Confirm this file exists:

```text
addons/gameplay_tags/plugin.cfg
```

3. In Godot, open:

```text
Project > Project Settings > Plugins
```

4. Enable `Gameplay Tags`.
5. A `GameplayTags` autoload should be created automatically.
6. Use the `Gameplay Tags` dock to add tags.

## What not to include in user packages

Do not include:

```text
.godot/
godot-cpp/
bin/
src/
tests/
benchmarks/
*.obj
*.obj.import
*.lib
*.exp
*.pdb
~*.TMP
```

Those are for development/building, not for normal addon users.
