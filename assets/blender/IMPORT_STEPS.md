# Roblox And Blender Import Steps

This repo is script-first Rojo. Do not expect Rojo to sync `.glb`, meshes, terrain, or Roblox model instances yet.

1. Open Blender 4.x.
2. Run `assets/blender/scripts/create_starter_brainrots.py`.
3. Confirm `assets/blender/asset_manifest.json` is created.
4. Import each `exports/models/BR_*.glb` into Roblox Studio.
5. Rename the Roblox model exactly to its `modelName`, for example `BR_WobbleNugget`.
6. Put NPC templates in the Studio folder used by the current NPC spawner/template system.
7. Import prop placeholders:
   - `PROP_PlotStand`
   - `PROP_ZoneGate`
   - `PROP_HideBush`
   - `PROP_HideCrate`
   - `PROP_RevealPlatform`
8. Import rarity VFX placeholders from `exports/vfx/VFX_*Glow.glb`.
9. Import gameplay VFX placeholders from `exports/vfx/VFX_HitSpark.glb`, `VFX_StunStars.glb`, `VFX_CaptureBurst.glb`, `VFX_MoneyPop.glb`, `VFX_QuestComplete.glb`, `VFX_RebirthBurst.glb`, and `VFX_ZoneUnlockBurst.glb`.
10. Upload generated icons from `exports/icons/*.png` and generated sound placeholders from `exports/sounds/*.wav`, or replace them with final art/audio before upload.
11. Paste every uploaded Roblox asset ID into `src/ReplicatedStorage/Shared/AssetIds.lua`.
12. Run `python tools/verify_asset_pipeline.py`.

Keep these names stable. `BrainrotConfig.ModelName` and the reveal/placement systems depend on matching names.
