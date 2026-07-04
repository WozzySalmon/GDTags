# Native Gameplay Tags GDExtension

This project has a Godot 4.6+ C++ GDExtension runtime alongside the existing GDScript editor/prototype addon.

The native classes use a `Native` prefix so the prototype keeps working while the extension is built and tested:

- `NativeGameplayTag`
- `NativeGameplayTagDatabase`
- `NativeGameplayTagContainer`
- `NativeGameplayTagQuery`
- `NativeGameplayTagRegistry`

## Documentation baseline

The build follows Godot's C++ GDExtension guide and the official `godot-cpp-template` layout:

- `godot-cpp/` is expected beside `src/` and `SConstruct`.
- `SConstruct` delegates to `godot-cpp/SConstruct`.
- The compiled library is created under `bin/<platform>/` and installed into `addons/gameplay_tags/bin/<platform>/`.
- `addons/gameplay_tags/gameplay_tags.gdextension` uses relative paths so the addon can be moved inside another Godot project.

## Build setup on Linux

Prerequisites:

- Godot 4.6+ available on `PATH` or through `GODOT_BIN`
- C++ build tools, Python, and SCons
- `godot-cpp` linked at `godot-cpp/`

Compatibility note: upstream did not publish a `godot-cpp` 4.6 tag. For binaries that must load in both Godot 4.6 and 4.7, use the verified `godot-4.5-stable` baseline until a better 4.6 baseline exists. Do not assume `godot-cpp` master is compatible with Godot 4.6.

If the local setup provides `.devbox.env`, source it when opening a fresh shell:

```bash
source .devbox.env
```

Useful shortcuts:

```bash
tools/linux/build_native.sh                 # debug/editor .so
tools/linux/build_native_release.sh         # release .so
tools/linux/build_native.sh -c              # clean native build output
tools/linux/build_native.sh -j1 verbose=yes # single-threaded verbose build
tools/linux/dev_native.sh                   # build + smoke tests
tools/linux/test_all_godot_versions.sh      # smoke-test Godot 4.6 and 4.7
```

Manual equivalent:

```bash
scons platform=linux target=template_debug -j$(nproc)
```

Expected debug shared library:

```text
addons/gameplay_tags/bin/linux/libgameplay_tags.linux.template_debug.x86_64.so
```

### Cross-build Windows DLLs from Linux

Linux can build the Windows x86_64 DLLs with MinGW. This is useful for local packaging when a real Windows runner is not available; final confidence still comes from loading the package in Godot on Windows.

Prerequisites:

```bash
apt-get install mingw-w64 zip
```

Build debug + release DLLs and package the addon folder:

```bash
tools/linux/build_windows_cross.sh
```

On low-memory machines, reduce parallel compile jobs:

```bash
JOBS=1 tools/linux/build_windows_cross.sh
```

Outputs:

```text
addons/gameplay_tags/bin/windows/gameplay_tags.windows.template_debug.x86_64.dll
addons/gameplay_tags/bin/windows/gameplay_tags.windows.template_release.x86_64.dll
dist/gameplay_tags-<version>-windows-crossbuild.zip
```

The MinGW build is statically linked against the C++ runtime by default. The expected imported DLLs are only Windows system libraries such as `KERNEL32.dll` and `msvcrt.dll`.

Use `GODOT_BIN` to choose a specific Godot executable for tests:

```bash
GODOT_BIN=godot4.6 tools/linux/test_native.sh
GODOT_BIN=godot4.7 tools/linux/test_native.sh
```

## Build setup on Windows

Prerequisites:

- Godot 4.6.x executable
- Visual Studio C++ tools
- Python + SCons (`python -m pip install --user scons`)
- `godot-cpp` checkout in the project root

The Godot docs say to use the `godot-cpp` branch matching the Godot minor version, but upstream did not publish a `4.6` tag. Do **not** use current `godot-cpp` master for 4.6-compatible release builds: it can produce binaries marked as Godot 4.7, which Godot 4.6 refuses to load. Until a better 4.6 baseline is available, use the verified `godot-4.5-stable` tag if the binary must load in both Godot 4.6 and 4.7.

```powershell
git clone --branch godot-4.5-stable https://github.com/godotengine/godot-cpp.git
git -C godot-cpp submodule update --init --recursive
tools\windows\build_native.cmd
```

The Windows build script now defaults to the normal editor/debug build and uses all CPU cores:

```text
platform=windows target=template_debug -j%NUMBER_OF_PROCESSORS%
```

Useful shortcuts:

```powershell
tools\windows\build_native.cmd                 # debug/editor DLL
tools\windows\build_native_release.cmd         # release DLL
tools\windows\build_native.cmd -c              # clean native build output
tools\windows\build_native.cmd -j1 verbose=yes # single-threaded verbose build
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

## GDExtension boundary performance

GDExtension calls still cross the Godot/native API boundary, so hot paths should avoid many tiny calls from GDScript into native code. Prefer the batch/query APIs that move the loop to one side of the boundary:

- `add_tags(...)` / `remove_tags(...)` for databases, containers, registries, and queries.
- `set_tags(...)` when replacing an entire native database or container.
- `has_any(...)`, `has_all(...)`, and `matches_query(...)` instead of looping over `has(...)` in GDScript.
- `GameplayTags.make_container(...)` and `GameplayTags.make_query_*()` to construct native objects in one call.

Use `benchmarks/bench_10000_tags_native.gd` to compare per-call native operations with the batched equivalents.

## Fast local workflow

After changing C++ under `src/`, close the Godot editor if it has the native library loaded, then run the platform workflow:

```bash
tools/linux/dev_native.sh
```

```powershell
tools\windows\dev_native.cmd
```

Both workflows build the native extension and then run the GDScript, native, and autoload smoke tests. If Godot is not on `PATH`, set `GODOT_BIN` before running tests.

## Tests and benchmarks

All smoke tests:

```bash
tools/linux/test_native.sh
```

```powershell
tools\windows\test_native.cmd
```

Individual tests and benchmarks can also be run directly:

```bash
$GODOT_BIN --headless --path . --script res://tests/test_gameplay_tags.gd
$GODOT_BIN --headless --path . --script res://tests/test_native_gameplay_tags_headless.gd
$GODOT_BIN --headless --path . --script res://tests/test_gameplay_tags_autoload_native_headless.gd
$GODOT_BIN --headless --path . --script res://benchmarks/bench_10000_tags.gd
$GODOT_BIN --headless --path . --script res://benchmarks/bench_10000_tags_native.gd
```
