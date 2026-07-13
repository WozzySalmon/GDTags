# Packaging the Gameplay Tags Addon

The addon is GDScript-only. Packages must not contain native build caches or development files.

A user package contains:

```text
addons/gameplay_tags/plugin.cfg
addons/gameplay_tags/plugin.gd
addons/gameplay_tags/editor/
addons/gameplay_tags/resources/
addons/gameplay_tags/runtime/
addons/gameplay_tags/examples/
addons/gameplay_tags/README.md
LICENSE
```

## Linux package script

Linux is the canonical build environment. Create and validate the package with:

```bash
tools/linux/package_addon.sh
```

The script stages the addon, removes native/development leftovers, creates the archive, and verifies
that `addons/gameplay_tags/plugin.cfg` exists and forbidden artifacts are absent.

## Windows package script

```bat
tools\windows\package_addon.cmd
```

Both scripts write:

```text
dist/gameplay_tags-<version>-gdscript.zip
```

## Install test

Run the automated clean-project installation smoke test with:

```bash
tools/linux/test_package_install.sh
```

Set `GODOT_BIN` to test a specific editor version. The script builds the release ZIP, extracts it
outside the repository, enables the packaged plugin, verifies its generated database and IDs, and
checks the `GameplayTags` autoload from a separate runtime process.

For a manual install check:

1. Unzip into a clean Godot project.
2. Confirm this exists:

```text
addons/gameplay_tags/plugin.cfg
```

3. Enable **Project > Project Settings > Plugins > Gameplay Tags**.
4. Confirm the `GameplayTags` autoload exists.
5. Open the **Gameplay Tags** dock, add a tag, and pick it on a `GameplayTagComponent`.

## Do not include

```text
.godot/
.pi-subagents/
dist/
tests/
benchmarks/
*.obj
*.lib
*.exp
*.pdb
*.tmp
```

Native GDExtension files are intentionally absent until native parity is explicitly rebuilt later.
