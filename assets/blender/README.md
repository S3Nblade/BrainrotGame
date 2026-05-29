# BrainrotGame Blender Asset Pipeline

This folder is the asset-ready pipeline for the 12 starter Brainrots and simulator props.

## Folders

- `scripts/`: Blender Python scripts.
- `exports/models/`: exported Brainrot models and props.
- `exports/animations/`: exported idle/run/stun/showcase animation files.
- `exports/icons/`: generated transparent PNG placeholders for inventory/index/reveal cards.
- `exports/vfx/`: rarity glows, reveal platform, and gameplay feedback VFX source exports.
- `exports/sounds/`: generated placeholder WAV files plus the upload checklist.

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
3. Check `asset_manifest.json` for the generated export paths and matching `AssetIds` keys.
4. Import generated GLB assets from `exports/models/`, `exports/animations/`, and `exports/vfx/`.
5. Put final model assets in the Roblox Studio folder that the game uses for NPC templates.
6. Paste all uploaded asset IDs into `src/ReplicatedStorage/Shared/AssetIds.lua`.
7. Run `python tools/verify_asset_pipeline.py` before committing asset registry changes.

The generator creates one placeholder model per Brainrot plus `idle`, `run`, `stun`, and `showcase` animation exports for each starter character. It also exports transparent icon renders, uploadable placeholder WAV files, a props pack with a reveal platform, plot stand, zone gate, hiding prop placeholders, rarity glows, and gameplay VFX placeholders for hit/stun/capture/money/quest/rebirth/zone feedback.

This pipeline uses placeholder geometry and animation timing. Replace or polish meshes later while preserving object/model names and asset registry keys.

See `IMPORT_STEPS.md` for the Studio-side checklist.
