# Reveal UI Lab

This is a browser preview and asset exporter for the Roblox NPC egg reveal UI. It does not use Blender or video.

## Preview

From this folder:

```powershell
python -m http.server 4173 --directory ../..
```

Open:

```text
http://localhost:4173/tools/reveal-ui-lab/
```

Use the controls to replay the reveal, switch rarity colors, and toggle the NEW badge.

## Export PNG Assets

From this folder, using Python with Pillow:

```powershell
python export_assets.py
```

If your local Python does not have Pillow, use the Codex bundled Python path or install Pillow in your environment.

Output goes to:

```text
generated_assets/reveal_gui/
```

Upload these PNGs to Roblox and paste the IDs into:

```text
src/StarterPlayer/StarterPlayerScripts/NPCRevealAssets.lua
```

The Roblox reveal module falls back to code-created UI shapes if any placeholder ID is still present.
