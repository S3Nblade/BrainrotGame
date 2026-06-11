# Pixel Brainrot Simulator

An original top-down Roblox simulator built with Rojo and Luau. The project uses a flat pixel-tile world, sprite-ready brainrots, authoritative server gameplay, hold-to-attack combat, critical hits, capture combos, capture reveals, inventory placement, stand income, upgrades, rebirths, zones, boosts, a persistent starter quest chain, live next-step coaching, mobile-styled action controls, daily rewards, capped offline earnings, and a collection index.

No assets or code were copied from another Roblox experience. All included PNGs are generated locally by this repository.

## Requirements

- Roblox Studio
- [Rojo plugin for Roblox Studio](https://create.roblox.com/store/asset/13916111004/Rojo)
- [Aftman](https://github.com/LPGhatguy/aftman) for the pinned Rojo and StyLua tools
- Python 3.10+
- Pillow (`python -m pip install Pillow`)

## Project Layout

```text
default.project.json
src/
  shared/        Shared configuration, utilities, remotes, and asset IDs
  server/        Data, world, spawning, capture, plot, economy, zone, and shop services
  client/        Camera, input, UI, reveal, and effects controllers
  ui/            Reusable pixel-style UI components and theme
assets/
  generated/     Generated transparent PNG assets
  manifest.json  Asset upload and intended-use catalog
tools/
  generate_pixel_assets.py
  validate_project.py
```

## Open With Rojo

1. Install pinned tools:

   ```powershell
   aftman install
   ```

2. Start the Rojo server from the repository root:

   ```powershell
   rojo serve
   ```

3. Open a new baseplate in Roblox Studio.
4. Open the Rojo Studio plugin, connect to `localhost:34872`, and sync the project.
5. Save the resulting place to your Roblox experience.

You can also create a standalone Studio file:

```powershell
rojo build default.project.json -o PixelBrainrotSimulator.rbxlx
```

## Generate Pixel Assets

Install Pillow once:

```powershell
python -m pip install Pillow
```

Regenerate every PNG and the manifest:

```powershell
python tools/generate_pixel_assets.py
```

The generator currently creates 80 original assets: brainrot sprites, eggs, rarity frames, mutation overlays, currency/menu icons, zone icons, shop and upgrade buttons, inventory/index cards, reveal frames, capture frames, and zone tiles.

## Upload Images To Roblox

1. Open Creator Hub and select the experience.
2. Upload PNGs from `assets/generated/` as development assets.
3. Keep each asset private to the experience or owning group as appropriate.
4. Copy the resulting numeric image asset IDs.
5. Replace matching `rbxassetid://0` values in `src/shared/AssetIds.lua`.

`assets/manifest.json` lists every PNG, its category, intended Roblox use, dimensions, and placeholder ID. The current game deliberately renders colored pixel shapes when IDs are still zero, so gameplay does not depend on uploaded images.

To use uploaded sprites in additional surfaces, read `AssetIds` from `ReplicatedStorage.Shared` and set an `ImageLabel.Image` or `Decal.Texture` to the matching value. Keep the fallback frame visible when the value is `rbxassetid://0`.

## Studio Testing

Before Play testing:

1. In **Game Settings > Security**, enable **Studio Access to API Services** only for a dedicated test place if you want DataStore persistence.
2. Keep the setting off to exercise the built-in temporary Studio profile fallback.
3. Use **Test > Start** with two players to verify plot ownership and server validation.

Core smoke test:

1. Confirm the camera locks into a smooth top-down view.
2. Approach a colored brainrot and hold click, Space, **ATTACK**, or a controller trigger.
3. Reduce HP before the chase timer expires.
4. Press E, tap **CAPTURE**, or use controller X while near the stunned brainrot.
5. Confirm the reveal animation and inventory card appear.
6. Capture another creature within 45 seconds and confirm the combo reward indicator increases.
7. Open **BAG**, place the brainrot, wait for stand income, and press F at the stand to collect.
8. Upgrade the item from its inventory card.
9. Unlock zones from **ZONES** and confirm capture power rises enough to defeat the next zone.
10. Purchase each shop placeholder and verify money is charged server-side.
11. Reach the rebirth cost, rebirth, and confirm money and stands reset while inventory remains.
12. Open **DAILY**, claim the current reward, and confirm it cannot be claimed twice that day.
13. Leave with a creature on a stand, wait at least one minute, and rejoin to verify capped offline income.
14. Rejoin again to confirm saved inventory, levels, discovery, zones, daily streak, and rebirths.

## Validation

Run all local checks:

```powershell
python tools/validate_project.py
stylua --check src
rojo build default.project.json -o work/PixelBrainrotSimulator.rbxlx
```

`StyLua` parses every Luau source file while checking formatting. Rojo validates the project tree and produces a Studio-loadable model.

## Architecture And Security

- The server owns money, inventory, mutation rolls, capture eligibility, placement, upgrades, collections, purchases, zone unlocks, and rebirths.
- Remote payloads contain only requested targets or identifiers. The server recalculates distance, cost, ownership, capacity, and rewards.
- DataStore operations use `UpdateAsync`, retries with backoff, reconciliation, autosaves, and a job-based session lock.
- Client scripts own input, camera, UI rendering, reveal choreography, and cosmetic effects.
- Shared config modules are the single source of truth for balancing.

## Balancing

Edit these modules:

- `src/shared/Config/Brainrots.lua`: stats, zone assignments, and base income
- `src/shared/Config/Rarities.lua`: spawn weights and stat multipliers
- `src/shared/Config/Mutations.lua`: mutation odds and income multipliers
- `src/shared/Config/Zones.lua`: map positions, unlock costs, tiles, and rewards
- `src/shared/Config/Economy.lua`: combat, storage, stands, upgrades, rebirths, offline earnings, and timers
- `src/shared/Config/DailyRewards.lua`: seven-day reward values
- `src/shared/Config/Shop.lua`: placeholder boost products

Developer products are intentionally not enabled. `ShopService` is structured around product keys so MarketplaceService receipt handling can replace the soft-currency placeholder path later.
