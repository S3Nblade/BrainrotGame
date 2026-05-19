# Brainrot Pro UI Generated Assets

Generated upload pack for the professional cartoon GUI.

## Recommended Upload

Upload `brainrot-pro-ui-spritesheet.png` to Roblox as one image asset, then give Codex the asset id.

The UI scripts are already wired to use that single id through:

```lua
ASSET_CONFIG.SpriteSheet = "rbxassetid://YOUR_ID"
```

or, without editing code, create:

`ReplicatedStorage.GUI.ProUIAssets.SpriteSheet`

as a `StringValue` containing the Roblox image id.

## Optional Individual Uploads

You can also upload the individual icon PNGs and map them by name:

- `brainrot-pro-icon-shop.png` -> `ShopIcon`
- `brainrot-pro-icon-index.png` -> `IndexIcon`
- `brainrot-pro-icon-rebirth.png` -> `RebirthIcon`
- `brainrot-pro-icon-catch.png` -> `CatchIcon`
- `brainrot-pro-icon-forest.png` -> `ForestIcon`
- `brainrot-pro-icon-money.png` -> `MoneyIcon`

The individual ids can be added in `ASSET_CONFIG` or as `StringValue`s under
`ReplicatedStorage.GUI.ProUIAssets`.
