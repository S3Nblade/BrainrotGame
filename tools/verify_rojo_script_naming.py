#!/usr/bin/env python3
"""Catch Rojo script suffix mistakes that change where code runs."""

from __future__ import annotations

import sys
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
STARTER_PLAYER_SCRIPTS = SRC / "StarterPlayer" / "StarterPlayerScripts"
SERVER_SCRIPT_SERVICE = SRC / "ServerScriptService"
MANIFEST = SRC / ".place-scripts.json"


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> int:
    failures: list[str] = []

    if STARTER_PLAYER_SCRIPTS.exists():
        for path in STARTER_PLAYER_SCRIPTS.rglob("*.lua*"):
            name = path.name.lower()
            if name.endswith(".server.lua"):
                failures.append(f"{rel(path)} is under StarterPlayerScripts but ends with .server.lua")

    if SERVER_SCRIPT_SERVICE.exists():
        for path in SERVER_SCRIPT_SERVICE.rglob("*.lua*"):
            name = path.name.lower()
            if name.endswith(".client.lua"):
                failures.append(f"{rel(path)} is under ServerScriptService but ends with .client.lua")

    for path in SRC.rglob("*.lua*"):
        name = path.name.lower()
        if ".client.lua.server.lua" in name or ".server.lua.client.lua" in name:
            failures.append(f"{rel(path)} has conflicting Rojo script suffixes")

    if MANIFEST.exists():
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for entry in manifest.get("scripts", []):
            file_name = str(entry.get("file", "")).lower()
            class_name = entry.get("class")
            if file_name.startswith("starterplayer/starterplayerscripts/") and file_name.endswith(".client.lua"):
                if class_name != "LocalScript":
                    failures.append(f"{entry.get('file')} is a client script in manifest but class is {class_name}")
            if file_name.startswith("serverscriptservice/") and file_name.endswith(".server.lua"):
                if class_name != "Script":
                    failures.append(f"{entry.get('file')} is a server script in manifest but class is {class_name}")

    if failures:
        print("Rojo script naming verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("OK: Rojo script suffixes match their source containers.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
