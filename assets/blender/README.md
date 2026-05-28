# BrainrotGame Blender Asset Pipeline

This folder is the asset-ready pipeline for the 12 starter Brainrots and simulator props.

## Folders

- `scripts/`: Blender Python scripts.
- `exports/models/`: exported Brainrot models and props.
- `exports/animations/`: exported idle/run/stun/showcase animation files.
- `exports/icons/`: rendered thumbnails or icon captures.
- `exports/vfx/`: rarity glow, reveal platform, and VFX source exports.
- `exports/sounds/`: placeholder sound list and future processed audio.

## Starter Brainrots

Model names must match `src/ReplicatedStorage/Shared/BrainrotConfig.lua`:

- `BR_WobbleNugget`
- `BR_GoofyCone`
- `BR_TinyBloop`
- `BR_SneakyPickle`
- `BR_DizzyDonut`
- `BR_BananaGoblin`
- `BR_ShyToaster`
- `BR_TurboMeatball`
- `BR_GlitchyCapybara`
- `BR_BubbleLizard`
- `BR_GoldenSpaghettiKing`
- `BR_CosmicBrainFrog`

## Export Flow

1. Open Blender.
2. Run `scripts/create_starter_brainrots.py`.
3. Export generated GLB/FBX assets from `exports/models/` and `exports/animations/`.
4. Import into Roblox Studio.
5. Put final model assets in a Roblox folder that the game can use for NPC templates.
6. Paste all uploaded asset IDs into `src/ReplicatedStorage/Shared/AssetIds.lua`.

The generator creates one placeholder model per Brainrot plus `idle`, `run`, `stun`, and `showcase` animation exports for each starter character. It also exports a small props pack with a reveal platform, plot stand, zone gate, and hiding prop placeholders.

This pipeline uses placeholder geometry and animation timing. Replace or polish meshes later while preserving object/model names and asset registry keys.
