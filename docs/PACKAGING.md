# Packaging the Gameplay Tags Addon

The clean restart is GDScript-only. Do not package native build caches or development files.

A user package should contain:

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

## Windows package script

```bat
tools\windows\package_addon.cmd
```

Output:

```text
dist/gameplay_tags-<version>-gdscript.zip
```

## Install test

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
