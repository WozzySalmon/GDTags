#!/usr/bin/env python3
"""Compares a Godot class member across the Godot versions this addon supports.

Answers the question that documentation for "latest" cannot: is this member
available in the oldest version we claim to support, and is its signature the
same everywhere? Run tools/linux/dump_godot_api.sh first to generate the data.

The generated XML comes from release binaries, which ship without prose, so this
reports availability and signatures only. For semantics -- what a member actually
does, and any caveats -- read the online class reference for the matching version.

Usage:
  query_godot_api.py Tree                 list members, flagging version gaps
  query_godot_api.py PopupMenu add_item   show one member's signature per version
"""

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
API_ROOT = Path(os.environ.get("GODOT_API_DIR", REPO_ROOT / ".godot-api"))
DOCS_URL = "https://docs.godotengine.org/en/{version}/classes/class_{lower}.html"


def find_versions() -> list[str]:
    if not API_ROOT.is_dir():
        return []
    return sorted(p.name for p in API_ROOT.iterdir() if p.is_dir())


def load_class(version: str, class_name: str) -> ET.Element | None:
    matches = list((API_ROOT / version).rglob(f"{class_name}.xml"))
    if not matches:
        return None
    return ET.parse(matches[0]).getroot()


def method_signature(node: ET.Element) -> str:
    params = []
    for param in node.findall("param"):
        text = f"{param.get('name')}: {param.get('type')}"
        if param.get("default") is not None:
            text += f" = {param.get('default')}"
        params.append(text)
    ret_node = node.find("return")
    ret = ret_node.get("type") if ret_node is not None else "void"
    return f"{node.get('name')}({', '.join(params)}) -> {ret}"


def member_signature(node: ET.Element) -> str:
    default = node.get("default")
    text = f"{node.get('name')}: {node.get('type')}"
    if default is not None:
        text += f" = {default}"
    return text


def collect(root: ET.Element) -> dict[str, str]:
    found: dict[str, str] = {}
    for node in root.findall("./methods/method"):
        found[node.get("name")] = method_signature(node)
    for node in root.findall("./members/member"):
        found[node.get("name")] = member_signature(node)
    for node in root.findall("./signals/signal"):
        found[node.get("name")] = "signal " + method_signature(node)
    return found


def main() -> int:
    versions = find_versions()
    if not versions:
        print(f"No API data in {API_ROOT}. Run tools/linux/dump_godot_api.sh first.")
        return 1

    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    class_name = sys.argv[1]
    wanted = sys.argv[2] if len(sys.argv) > 2 else None

    per_version: dict[str, dict[str, str]] = {}
    for version in versions:
        root = load_class(version, class_name)
        if root is None:
            print(f"{version}: class {class_name} does not exist")
            continue
        per_version[version] = collect(root)

    if not per_version:
        return 1

    if wanted:
        print(f"{class_name}.{wanted}")
        for version in versions:
            signature = per_version.get(version, {}).get(wanted)
            print(f"  {version}: {signature if signature else 'NOT AVAILABLE'}")
    else:
        every = sorted(set().union(*(set(v) for v in per_version.values())))
        missing_somewhere = [
            name for name in every if any(name not in per_version[v] for v in per_version)
        ]
        print(f"{class_name}: {len(every)} members across {', '.join(versions)}")
        if missing_somewhere:
            print("\nNot present in every supported version:")
            for name in missing_somewhere:
                have = [v for v in versions if name in per_version.get(v, {})]
                print(f"  {name} -- only in {', '.join(have)}")
        else:
            print("\nEvery member is present in all supported versions.")

    oldest = versions[0]
    print(f"\nSemantics are not in this data. Read the {oldest} class reference:")
    print("  " + DOCS_URL.format(version=oldest, lower=class_name.lower()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
