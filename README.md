# GDTags

Gameplay Tags addon for Godot 4.6+, inspired by Unreal's Gameplay Tags.

GDTags gives you hierarchical tags such as:

```text
State.Stunned
Damage.Fire
Team.Enemy
```

Then gameplay logic can stay simple:

```gdscript
if target.tags.has("State.Stunned"):
	return
```

## Project layout

```text
addons/gameplay_tags/   Addon files users install into Godot projects
docs/                   Native build, packaging, and GDScript style notes
src/                    C++ GDExtension source
tests/                  Headless Godot smoke tests
benchmarks/             Runtime benchmark scripts
tools/linux/            Linux build, lint, and test scripts
tools/windows/          Windows build, lint, test, and packaging scripts
```

Ignored local/build folders such as `.godot/`, `godot-cpp/`, `bin/`, `dist/`, and `addons/gameplay_tags/bin/` are not part of the source package.

## Quick usage

Enable the plugin in Godot:

```text
Project > Project Settings > Plugins > Gameplay Tags
```

Then use the `GameplayTags` autoload:

```gdscript
var tags := GameplayTags.make_container([
	"State.Stunned",
	"Team.Enemy",
])

print(tags.has("State")) # true, because State.Stunned is a child of State
```

## Development commands

On Linux, check and test GDScript:

```bash
tools/linux/format_gdscript.sh
tools/linux/lint_gdscript.sh
tools/linux/check_gdscript.sh
tools/linux/test_native.sh
```

Build/test the native Linux GDExtension:

```bash
tools/linux/dev_native.sh
```

Smoke-test the configured Godot versions:

```bash
tools/linux/test_all_godot_versions.sh
```

Windows validation and shareable addon zips still use the Windows scripts:

```bat
tools\windows\dev_native.cmd
tools\windows\package_addon.cmd
tools\windows\package_addon.cmd -Variant gdscript -SkipBuild
```

## Docs

- `addons/gameplay_tags/README.md` - addon/user notes
- `docs/NATIVE.md` - C++ GDExtension build notes
- `docs/PACKAGING.md` - how to make release zips
- `docs/CI.md` - GitHub Actions Windows build/package workflow
- `docs/GDSCRIPT_STYLE.md` - GDScript style guide for this repo
