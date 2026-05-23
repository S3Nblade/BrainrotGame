#!/usr/bin/env python3
"""Compare extracted src/ script files with the tracked .rbxlx place."""

from __future__ import annotations

import argparse
import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path


MANIFEST_NAME = ".place-scripts.json"


def prop_text(item: ET.Element, prop_name: str) -> str | None:
    props = item.find("Properties")
    if props is None:
        return None
    for child in props:
        if child.attrib.get("name") == prop_name:
            return child.text or ""
    return None


def source_text(item: ET.Element) -> str:
    return prop_text(item, "Source") or ""


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def index_by_referent(rbxlx_path: Path) -> dict[str, ET.Element]:
    root = ET.parse(rbxlx_path).getroot()
    result = {}
    for item in root.iter("Item"):
        referent = item.attrib.get("referent", "")
        if referent:
            result[referent] = item
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("rbxlx", type=Path)
    parser.add_argument("src_root", type=Path, nargs="?", default=Path("src"))
    args = parser.parse_args()

    manifest_path = args.src_root / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    by_ref = index_by_referent(args.rbxlx)

    mismatches = []
    missing = []
    for entry in manifest["scripts"]:
        file_path = args.src_root / entry["file"]
        item = by_ref.get(entry["referent"])
        if item is None:
            missing.append((entry["file"], entry["robloxPath"]))
            continue
        if not file_path.exists():
            missing.append((entry["file"], entry["robloxPath"]))
            continue
        place_hash = sha256_text(source_text(item))
        src_hash = sha256_text(file_path.read_text(encoding="utf-8"))
        if place_hash != src_hash:
            mismatches.append((entry["file"], entry["robloxPath"], src_hash[:12], place_hash[:12]))

    if missing:
        print("Missing scripts:")
        for file_path, roblox_path in missing:
            print(f"  {file_path} <- {roblox_path}")
    if mismatches:
        print("Script mismatches:")
        for file_path, roblox_path, src_hash, place_hash in mismatches:
            print(f"  {file_path} <- {roblox_path} src={src_hash} place={place_hash}")

    if missing or mismatches:
        print(f"FAILED: {len(missing)} missing, {len(mismatches)} mismatched")
        return 1

    print(f"OK: {len(manifest['scripts'])} scripts match {args.rbxlx}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
