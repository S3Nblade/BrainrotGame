#!/usr/bin/env python3
"""Verify consolidated DefaultData stays aligned with config modules."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "src" / "ReplicatedStorage" / "Shared"
DEFAULT_DATA = SHARED / "DefaultData.lua"
UPGRADE_CONFIG = SHARED / "UpgradeConfig.lua"
ZONE_CONFIG = SHARED / "ZoneConfig.lua"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_lua_table_block(text: str, key: str) -> str:
    match = re.search(rf"\b{re.escape(key)}\s*=\s*{{", text)
    if not match:
        return ""

    start = match.end()
    depth = 1
    i = start

    while i < len(text):
        char = text[i]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start:i]
        i += 1

    return ""


def extract_top_level_table_keys(block: str) -> list[str]:
    keys: list[str] = []
    depth = 0

    for line in block.splitlines():
        if depth == 0:
            match = re.match(r"\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*{", line)
            if match:
                keys.append(match.group(1))

        for char in line:
            if char == "{":
                depth += 1
            elif char == "}":
                depth = max(0, depth - 1)

    return keys


def main() -> int:
    default_text = read(DEFAULT_DATA)
    upgrade_text = read(UPGRADE_CONFIG)
    zone_text = read(ZONE_CONFIG)

    upgrade_block = extract_lua_table_block(default_text, "Upgrades")
    zone_block = extract_lua_table_block(default_text, "UnlockedZones")
    upgrade_definition_block = extract_lua_table_block(upgrade_text, "Definitions")

    failures: list[str] = []

    schema_match = re.search(r"\bSchemaVersion\s*=\s*(\d+)", default_text)
    schema_version = int(schema_match.group(1)) if schema_match else 0
    if schema_version < 4:
        failures.append(f"DefaultData.SchemaVersion should be at least 4, got {schema_version}")

    upgrade_keys = extract_top_level_table_keys(upgrade_definition_block)
    for key in upgrade_keys:
        if not re.search(rf"\b{re.escape(key)}\s*=", upgrade_block):
            failures.append(f"DefaultData.Upgrades missing {key}")

    zone_ids = re.findall(r'\bId\s*=\s*"([^"]+)"', zone_text)
    for zone_id in zone_ids:
        if not re.search(rf"\b{re.escape(zone_id)}\s*=", zone_block):
            failures.append(f"DefaultData.UnlockedZones missing {zone_id}")

    for required in ("Inventory", "Discovered", "Plot", "Quests", "Daily", "Settings", "Multipliers"):
        if not re.search(rf"\b{re.escape(required)}\s*=", default_text):
            failures.append(f"DefaultData missing {required} table")

    if failures:
        print("Default data verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print(f"OK: DefaultData schema {schema_version} covers {len(upgrade_keys)} upgrades and {len(zone_ids)} zones.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
