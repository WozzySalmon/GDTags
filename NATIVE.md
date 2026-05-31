# Native Gameplay Tags GDExtension

This project has a Godot 4.6 C++ GDExtension runtime alongside the existing GDScript editor/prototype addon.

The native classes use a `Native` prefix so the prototype keeps working while the extension is built and tested:

- `NativeGameplayTag`
- `NativeGameplayTagDatabase`
- `NativeGameplayTagContainer`
- `NativeGameplayTagQuery`
- `NativeGameplayTagRegistry`

## Documentation baseline

The build now follows the Godot 4.6 C++ GDExtension guide and the official `godot-cpp-template` layout:

- `godot-cpp/` is expected beside `src/` and `SConstruct`.
- `SConstruct` delegates to `godot-cpp/SConstruct`.
- The compiled library is created under `bin/<platform>/` and installed into `addons/gameplay_tags/bin/<platform>/`.
- `addons/gameplay_tags/gameplay_tags.gdextension` uses relative paths so the addon can be moved inside another Godot project.

## Build setup on Windows

Prerequisites:

- Godot 4.6.x executable
- Visual Studio C++ tools
- Python + SCons (`python -m pip install --user scons`)
- `godot-cpp` checkout in the project root

The Godot docs say to use the `godot-cpp` branch matching the Godot minor version. At the time this project was rebuilt, `godot-cpp` did not publish a `4.6` branch/tag, so the local checkout uses `master` for Godot 4.6.3.

```powershell
git clone https://github.com/godotengine/godot-cpp.git
git -C godot-cpp submodule update --init --recursive
.\build_native_windows.cmd
```

The Windows build script now defaults to the normal editor/debug build and uses all CPU cores:

```text
platform=windows target=template_debug -j%NUMBER_OF_PROCESSORS%
```

Useful shortcuts:

```powershell
.\build_native_windows.cmd                 # debug/editor DLL
.\build_native_release_windows.cmd         # release DLL
.\build_native_windows.cmd -c              # clean native build output
.\build_native_windows.cmd -j1 verbose=yes # single-threaded verbose build
```

Manual equivalent from a Visual Studio x64 Developer Command Prompt:

```powershell
python -m SCons platform=windows target=template_debug -j%NUMBER_OF_PROCESSORS%
```

Expected debug DLL:

```text
addons/gameplay_tags/bin/windows/gameplay_tags.windows.template_debug.x86_64.dll
```

## Enabling/loading the extension

The extension file is:

```text
addons/gameplay_tags/gameplay_tags.gdextension
```

Godot editor projects normally discover this through `.godot/extension_list.cfg`. The `GameplayTags` autoload, headless native test, and native benchmark also call `GDExtensionManager.load_extension()` as a fallback, so they can run before the editor cache is generated.

At runtime, `GameplayTags` keeps the GDScript database as the editable source of truth and mirrors it into a `NativeGameplayTagDatabase` when the GDExtension is available. Calls such as `GameplayTags.make_container()` and `GameplayTags.make_query_all()` then return native objects automatically. If the native DLL is absent, the same API falls back to GDScript objects.

## Fast local workflow

After changing C++ under `src/`, close the Godot editor if it has the DLL loaded, then run:

```powershell
.\dev_native_windows.cmd
```

That performs a parallel debug build and then runs the GDScript, native, and autoload smoke tests. If Godot moves, set `GODOT_BIN` before running tests:

```powershell
$env:GODOT_BIN = "C:\Path\To\Godot_v4.6.x-stable_win64.exe"
.\test_native_windows.cmd
```

## Tests and benchmarks

All smoke tests:

```powershell
.\test_native_windows.cmd
```

Pure GDScript runtime smoke test:

```powershell
& "C:\Users\Big-Boi\Desktop\Game develpoment Programs\Godot_v4.6.3-stable_win64.exe" --headless --path "C:\Users\Big-Boi\PI projects\gameplay-tags" --script res://tests/test_gameplay_tags.gd
```

Native smoke test:

```powershell
& "C:\Users\Big-Boi\Desktop\Game develpoment Programs\Godot_v4.6.3-stable_win64.exe" --headless --path "C:\Users\Big-Boi\PI projects\gameplay-tags" --script res://tests/test_native_gameplay_tags_headless.gd
```

Autoload native-selection smoke test:

```powershell
& "C:\Users\Big-Boi\Desktop\Game develpoment Programs\Godot_v4.6.3-stable_win64.exe" --headless --path "C:\Users\Big-Boi\PI projects\gameplay-tags" --script res://tests/test_gameplay_tags_autoload_native_headless.gd
```

Prototype GDScript benchmark:

```powershell
& "C:\Users\Big-Boi\Desktop\Game develpoment Programs\Godot_v4.6.3-stable_win64.exe" --headless --path "C:\Users\Big-Boi\PI projects\gameplay-tags" --script res://benchmarks/bench_10000_tags.gd
```

Native benchmark:

```powershell
& "C:\Users\Big-Boi\Desktop\Game develpoment Programs\Godot_v4.6.3-stable_win64.exe" --headless --path "C:\Users\Big-Boi\PI projects\gameplay-tags" --script res://benchmarks/bench_10000_tags_native.gd
```

Recent local Godot 4.6.3 results:

- GDScript total: ~287 ms for 10,000 add/remove operations
- Native total: ~27 ms for 10,000 add/remove operations
- Native speedup: about 10x on this benchmark
