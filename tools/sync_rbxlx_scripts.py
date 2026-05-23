#!/usr/bin/env python3
"""Inject src/ script files back into a tracked .rbxlx place.

The script updates only ProtectedString Source values for script instances
listed in src/.place-scripts.json. It preserves the rest of the place file.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


MANIFEST_NAME = ".place-scripts.json"


def cdata_source(source: str) -> str:
    # Roblox script sources should not contain this sequence, but split if they do.
    return "<![CDATA[" + source.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def replace_source_block(text: str, referent: str, source: str) -> tuple[str, bool]:
    escaped_ref = re.escape(referent)
    pattern = re.compile(
        rf'(<Item\b[^>]*\breferent="{escaped_ref}"[^>]*>.*?'
        rf'<ProtectedString name="Source">)(.*?)(</ProtectedString>)',
        re.DOTALL,
    )
    def replacement(match: re.Match[str]) -> str:
        return match.group(1) + cdata_source(source) + match.group(3)

    new_text, count = pattern.subn(replacement, text, count=1)
    return new_text, count == 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("rbxlx", type=Path)
    parser.add_argument("src_root", type=Path, nargs="?", default=Path("src"))
    args = parser.parse_args()

    manifest = json.loads((args.src_root / MANIFEST_NAME).read_text(encoding="utf-8"))
    text = args.rbxlx.read_text(encoding="utf-8")

    updated = 0
    missing = []
    for entry in manifest["scripts"]:
        src_file = args.src_root / entry["file"]
        if not src_file.exists():
            missing.append(entry["file"])
            continue
        source = src_file.read_text(encoding="utf-8")
        text, ok = replace_source_block(text, entry["referent"], source)
        if ok:
            updated += 1
        else:
            missing.append(entry["robloxPath"])

    if missing:
        print("Could not sync these scripts:")
        for item in missing:
            print(f"  {item}")
        return 1

    args.rbxlx.write_text(text, encoding="utf-8", newline="\n")
    print(f"Synced {updated} scripts into {args.rbxlx}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
