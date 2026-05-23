#!/usr/bin/env python3
"""Extract script sources from an .rbxlx place into src/ deterministically.

This intentionally tracks script sources only. The full place remains in
places/main.rbxlx so Workspace/map/model data is preserved outside Rojo.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path


SCRIPT_EXTENSIONS = {
    "Script": ".server.lua",
    "LocalScript": ".client.lua",
    "ModuleScript": ".lua",
}

MANIFEST_NAME = ".place-scripts.json"


def clean_name(name: str | None) -> str:
    text = name or "Unnamed"
    text = re.sub(r'[<>:"/\\|?*]', "_", text).strip()
    return text or "Unnamed"


def prop_text(item: ET.Element, prop_name: str) -> str | None:
    props = item.find("Properties")
    if props is None:
        return None
    for child in props:
        if child.attrib.get("name") == prop_name:
            return child.text or ""
    return None


def item_name(item: ET.Element) -> str:
    return prop_text(item, "Name") or item.attrib.get("class", "Unnamed")


def item_source(item: ET.Element) -> str:
    return prop_text(item, "Source") or ""


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def unique_script_path(base: Path, used: set[Path]) -> Path:
    if base not in used:
        used.add(base)
        return base

    suffix = "".join(base.suffixes)
    stem = base.name[: -len(suffix)] if suffix else base.stem
    for index in range(2, 10000):
        candidate = base.with_name(f"{stem}__{index}{suffix}")
        if candidate not in used:
            used.add(candidate)
            return candidate
    raise RuntimeError(f"Could not allocate unique path for {base}")


def walk_scripts(item: ET.Element, path_parts: list[str], used: set[Path], entries: list[dict]) -> None:
    class_name = item.attrib.get("class", "")
    name = clean_name(item_name(item))

    if class_name in SCRIPT_EXTENSIONS:
        ext = SCRIPT_EXTENSIONS[class_name]
        rel_dir = Path(*path_parts) if path_parts else Path()
        rel_path = unique_script_path(rel_dir / f"{name}{ext}", used)
        source = item_source(item)
        entries.append(
            {
                "file": rel_path.as_posix(),
                "class": class_name,
                "name": item_name(item),
                "referent": item.attrib.get("referent", ""),
                "robloxPath": "/".join(path_parts + [item_name(item)]),
                "sha256": sha256_text(source),
            }
        )
        return

    next_parts = path_parts + [name]
    for child in item.findall("Item"):
        walk_scripts(child, next_parts, used, entries)


def extract(rbxlx_path: Path, output_root: Path, clean: bool) -> list[dict]:
    if clean and output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True, exist_ok=True)

    tree = ET.parse(rbxlx_path)
    root = tree.getroot()
    entries: list[dict] = []
    used: set[Path] = set()

    for item in root.findall("Item"):
        service_name = clean_name(item_name(item))
        for child in item.findall("Item"):
            walk_scripts(child, [service_name], used, entries)

    entries.sort(key=lambda row: row["file"].lower())

    for entry in entries:
        source_item = find_item_by_referent(root, entry["referent"])
        if source_item is None:
            raise RuntimeError(f"Missing item for referent {entry['referent']}")
        source = item_source(source_item)
        target = output_root / entry["file"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source, encoding="utf-8", newline="\n")

    manifest = {
        "place": rbxlx_path.as_posix(),
        "scriptCount": len(entries),
        "scripts": entries,
    }
    (output_root / MANIFEST_NAME).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return entries


def find_item_by_referent(root: ET.Element, referent: str) -> ET.Element | None:
    if not referent:
        return None
    for item in root.iter("Item"):
        if item.attrib.get("referent") == referent:
            return item
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("rbxlx", type=Path)
    parser.add_argument("output_root", type=Path, nargs="?", default=Path("src"))
    parser.add_argument("--clean", action="store_true", help="Delete output root before extraction.")
    args = parser.parse_args()

    entries = extract(args.rbxlx, args.output_root, args.clean)
    print(f"Extracted {len(entries)} scripts from {args.rbxlx} into {args.output_root}")
    print(f"Wrote manifest: {args.output_root / MANIFEST_NAME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
