#!/usr/bin/env python3
"""Fast structural checks for the Pixel Brainrot Simulator project."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "default.project.json",
    "src/shared/AssetIds.lua",
    "src/shared/Config/Brainrots.lua",
    "src/server/Main.server.lua",
    "src/client/Main.client.lua",
    "tools/generate_pixel_assets.py",
    "assets/manifest.json",
    "README.md",
]

REGRESSION_SNIPPETS = {
    "src/server/DataService.lua": [
        "template.Money = context.Config.Economy.StartingMoney",
        "template.Gems = context.Config.Economy.StartingGems",
        "if loading[player] then",
        "loading[player] = nil",
    ],
    "src/server/BrainrotSpawnService.lua": [
        'model:SetAttribute("Stunned", false)',
        "record.StunnedUntil",
    ],
    "src/server/RebirthService.lua": [
        "context.PlotService.ResetAccrued(player)",
    ],
    "src/client/RevealController.lua": [
        "egg.BackgroundTransparency = 0",
        "table.insert(queue, item)",
        "buildCreature(item, definition, rarity, mutation)",
        "rarityBurst(rarity.Color)",
    ],
    "src/client/InputController.lua": [
        'model:GetAttribute("Stunned") == true',
        "context.PlayerGui:GetGuiObjectsAtPosition",
        'highlight.Name = "TargetHighlight"',
        "while attackHeld do",
        "context.Config.Economy.AttackCooldown * 0.9",
        'unlockedZones[model:GetAttribute("ZoneId")] == true',
        '"NEXT: HOLD ATTACK!"',
        '"NEXT: PRESS E TO CAPTURE!"',
        "ContextActionService:GetButton(actionName)",
        '"NEXT: OPEN BAG AND PLACE YOUR CREATURE"',
    ],
    "src/server/PlotService.lua": [
        "context.Remotes.UnplaceRequest.OnServerEvent",
        "context.Remotes.TravelPlotRequest.OnServerEvent",
        '"Plot collected! +$"',
    ],
    "src/server/QuestService.lua": [
        'QuestService.Progress(player, eventName, value, amount)',
        "function QuestService.Sync(player, notify)",
        '"Quest complete! +"',
    ],
    "src/server/OfflineEarningsService.lua": [
        "OfflineEarningsCapSeconds",
        "context.EconomyService.GetRebirthMultiplier(data)",
        "data.Money += reward",
    ],
    "src/server/DailyRewardService.lua": [
        "context.Remotes.ClaimDailyRequest.OnServerEvent",
        "data.Daily.LastClaimDay = day",
        "context.EconomyService.GetRebirthMultiplier(data)",
    ],
    "src/client/UIController.lua": [
        'context.Remotes.ClaimDailyRequest:FireServer()',
        '"7-DAY STREAK"',
        "context.Remotes.ComboChanged.OnClientEvent",
        'counters.Power.Text = "Power: "',
        'guideButton("Inventory")',
        'guideButton("Zones")',
        '"TAP AGAIN TO CONFIRM"',
        "itemIncome(item) * context.Config.Economy.UpgradeIncomeSeconds",
    ],
    "src/server/EconomyService.lua": [
        "function EconomyService.GetPlayerDamage(data)",
        "DamageRebirthGrowth",
        "DamageMultiplier",
        "context.Config.Economy.UpgradeIncomeSeconds",
        "math.max(baseCost, incomeCost)",
    ],
    "src/server/CaptureService.lua": [
        "local comboMultiplier = advanceCombo(player)",
        "context.Config.Economy.CriticalChance",
        "context.EconomyService.GetPlayerDamage(data)",
    ],
    "src/server/ZoneService.lua": [
        "context.MapService.GetZoneAt(root.Position)",
        "not data.UnlockedZones[zoneId]",
        '"That zone is locked. Unlock it from ZONES!"',
    ],
}


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


def main() -> None:
    for relative in REQUIRED:
        if not (ROOT / relative).exists():
            fail(f"Missing required file: {relative}")

    try:
        json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"default.project.json is invalid: {error}")

    for lua_path in (ROOT / "src").rglob("*.lua"):
        try:
            lua_path.read_text(encoding="ascii")
        except UnicodeDecodeError:
            fail(f"Source must remain ASCII-clean: {lua_path.relative_to(ROOT)}")

    for relative, snippets in REGRESSION_SNIPPETS.items():
        source = (ROOT / relative).read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in source:
                fail(f"Regression guard missing in {relative}: {snippet}")

    manifest = json.loads((ROOT / "assets/manifest.json").read_text(encoding="utf-8"))
    assets = manifest.get("assets", [])
    if manifest.get("count") != len(assets):
        fail("Manifest count does not match its asset list")
    if len(assets) < 60:
        fail(f"Expected a broad asset set; found only {len(assets)} assets")

    seen: set[str] = set()
    for entry in assets:
        relative = entry.get("path")
        if not isinstance(relative, str) or relative in seen:
            fail(f"Invalid or duplicate manifest path: {relative}")
        seen.add(relative)
        path = ROOT / relative
        if not path.exists():
            fail(f"Manifest references a missing file: {relative}")
        with Image.open(path) as image:
            if image.format != "PNG" or image.mode != "RGBA":
                fail(f"Asset is not a transparent-capable RGBA PNG: {relative}")
            if image.width % 4 or image.height % 4:
                fail(f"Asset is not nearest-neighbor scale aligned: {relative}")

    print(f"Validated project structure and {len(assets)} PNG assets.")
    return None


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
