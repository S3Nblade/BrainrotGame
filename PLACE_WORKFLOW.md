# Roblox Place Workflow

`places/main.rbxlx` is the tracked full Roblox place. It preserves Workspace, map,
model, and UI data that cannot be represented safely by the current Rojo project.

## Import The Current Studio Place

1. Export or save the Studio place as an `.rbxlx`.
2. Replace `places/main.rbxlx` with that file.
3. Extract scripts into readable source files:

```powershell
python tools\extract_rbxlx_scripts.py places\main.rbxlx src --clean
```

## Edit Scripts

Edit script files in `src/`. The extractor writes `src/.place-scripts.json`, which
maps each source file back to its Roblox instance referent in the place file.

## Inject Scripts Back Into The Place

After editing `src/`, inject the changed script sources into the tracked place:

```powershell
python tools\sync_rbxlx_scripts.py places\main.rbxlx src
```

The injector updates only script `Source` values. It does not rewrite Workspace,
map, model, or non-script place data.

## Verify Sync

Run these before opening or publishing the place:

```powershell
python tools\compare_place_scripts.py places\main.rbxlx src
rojo sourcemap default.project.json --output NUL
git diff --check
```

`compare_place_scripts.py` should report that all scripts match. Then open
`places/main.rbxlx` in Studio and test the changed gameplay.
