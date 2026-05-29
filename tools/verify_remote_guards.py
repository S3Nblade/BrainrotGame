#!/usr/bin/env python3
"""Lightweight guardrail for server RemoteEvent/RemoteFunction handlers."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "src" / "ServerScriptService"

HANDLER_RE = re.compile(r"(OnServerEvent|OnServerInvoke)\s*[:.]Connect\s*\(\s*function|OnServerInvoke\s*=\s*function")
GUARD_WORDS = (
    "cooldown",
    "rate",
    "typeof(",
    "type(",
    "IsA(",
    "Distance",
    "Magnitude",
    "Owner",
    "owns",
    "alive",
    "Health",
    "canRequest",
    "validate",
    "clamp",
)

KNOWN_PASSIVE = {
    "CaptureRevealAnnouncements.server.lua.server.lua",  # test/admin-style announcement hook; no economy mutation.
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def line_number(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def main() -> int:
    failures: list[str] = []
    checked = 0

    for path in SERVER.rglob("*.lua*"):
        if path.name in KNOWN_PASSIVE:
            continue

        text = read(path)
        for match in HANDLER_RE.finditer(text):
            checked += 1
            window_start = max(0, match.start() - 2600)
            window = text[window_start:match.start() + 1800]
            if not any(word in window for word in GUARD_WORDS):
                rel = path.relative_to(ROOT).as_posix()
                failures.append(f"{rel}:{line_number(text, match.start())} has a remote handler with no obvious guard")

    if failures:
        print("Remote guard verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print(f"OK: checked {checked} server remote handlers for obvious validation/rate-limit guards.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
