#!/usr/bin/env python3
"""Verify that Brainrot asset names stay aligned across config and pipeline files."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src" / "ReplicatedStorage" / "Shared" / "BrainrotConfig.lua"
ASSET_IDS = ROOT / "src" / "ReplicatedStorage" / "Shared" / "AssetIds.lua"
MANIFEST_TEMPLATE = ROOT / "assets" / "blender" / "asset_manifest.template.json"
BLENDER_GENERATOR = ROOT / "assets" / "blender" / "scripts" / "create_starter_brainrots.py"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def pascal_from_model(model_name: str) -> str:
    if model_name.startswith("BR_"):
        model_name = model_name[3:]
    return re.sub(r"[^A-Za-z0-9]", "", model_name)


def main() -> int:
    config_text = read(CONFIG)
    asset_text = read(ASSET_IDS)
    generator_text = read(BLENDER_GENERATOR)
    manifest = json.loads(read(MANIFEST_TEMPLATE))

    model_names = re.findall(r'ModelName\s*=\s*"([^"]+)"', config_text)
    if not model_names:
        print("FAIL: no BrainrotConfig ModelName entries found", file=sys.stderr)
        return 1

    required_models = manifest.get("requiredModelNames") or []
    failures: list[str] = []

    for model_name in model_names:
        if model_name not in required_models:
            failures.append(f"{model_name} is in BrainrotConfig but missing from asset_manifest.template.json")

        asset_key = pascal_from_model(model_name)
        if not re.search(rf"\b{re.escape(asset_key)}\s*=", asset_text):
            failures.append(f"{model_name} expects AssetIds.Models/Icons.{asset_key}, but key is missing")

    for model_name in required_models:
        if model_name not in model_names:
            failures.append(f"{model_name} is in asset_manifest.template.json but missing from BrainrotConfig")
        if model_name not in generator_text:
            failures.append(f"{model_name} is in asset_manifest.template.json but missing from create_starter_brainrots.py")

    for clip in manifest.get("requiredAnimationClips") or []:
        if not re.search(rf"[\"']{re.escape(clip)}[\"']", generator_text):
            failures.append(f"Animation clip '{clip}' is required but missing from create_starter_brainrots.py")

    for key in manifest.get("requiredSoundKeys") or []:
        if not re.search(rf"\b{re.escape(key)}\s*=", asset_text):
            failures.append(f"Sound key AssetIds.Sounds.{key} is missing")
        if not re.search(rf"[\"']{re.escape(key)}[\"']", generator_text):
            failures.append(f"Sound key '{key}' is required but missing from create_starter_brainrots.py")

    for vfx_name in manifest.get("requiredRarityVfx") or []:
        asset_key = vfx_name.removeprefix("VFX_")
        if not re.search(rf"\b{re.escape(asset_key)}\s*=", asset_text):
            failures.append(f"VFX key AssetIds.VFX.{asset_key} is missing")
        if asset_key.removesuffix("Glow") not in generator_text:
            failures.append(f"{vfx_name} is required but missing from create_starter_brainrots.py")

    for vfx_name in manifest.get("requiredGameplayVfx") or []:
        asset_key = vfx_name.removeprefix("VFX_")
        if not re.search(rf"\b{re.escape(asset_key)}\s*=", asset_text):
            failures.append(f"Gameplay VFX key AssetIds.VFX.{asset_key} is missing")
        if vfx_name not in generator_text:
            failures.append(f"{vfx_name} is required but missing from create_starter_brainrots.py")

    for prop_name in manifest.get("requiredProps") or []:
        asset_key = prop_name.removeprefix("PROP_")
        if not re.search(rf"\b{re.escape(asset_key)}\s*=", asset_text):
            failures.append(f"Prop key AssetIds.VFX.{asset_key} is missing")
        if prop_name not in generator_text:
            failures.append(f"{prop_name} is required but missing from create_starter_brainrots.py")

    if "render_icon(" not in generator_text:
        failures.append("create_starter_brainrots.py must render icon placeholders for every Brainrot")

    if "create_sound_placeholders(" not in generator_text:
        failures.append("create_starter_brainrots.py must create placeholder WAV files for required sounds")

    if failures:
        print("Asset pipeline verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print(f"OK: {len(model_names)} Brainrot models match BrainrotConfig, AssetIds, and Blender manifest template.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
