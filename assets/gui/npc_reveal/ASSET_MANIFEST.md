# NPC Reveal GUI Asset Manifest

These assets are decorative layers only. Do not bake dynamic text, buttons, NPC names, rarity labels, or click logic into these images. Upload the PNGs to Roblox, then paste the IDs into `ReplicatedStorage/GUI/NPCRevealAssets/AssetIds`.

| Filename | Purpose | Roblox object | Suggested size/scale | Tintable | Reveal usage | Transparency notes |
|---|---|---|---|---|---|---|
| `reveal_panel_bg.png` | Premium rounded main reveal panel background | `ImageLabel` | Stage size, around 74% x 66% screen | No | Main reveal container decoration | Transparent corners |
| `reveal_panel_shadow.png` | Soft shadow behind the main panel | `ImageLabel` | Slightly larger than panel | Yes, black/rarity tint optional | Behind reveal panel | Transparent fade edges |
| `npc_card_bg.png` | Glossy rounded NPC roll card background | `ImageLabel` | Each carousel card | No | Card base behind ViewportFrame | Transparent corners |
| `npc_card_outline.png` | Decorative card outline layer | `ImageLabel` | Same as card | Yes | Rarity-colored outline overlay | Mostly transparent except outline |
| `npc_card_shadow.png` | Card drop shadow | `ImageLabel` | Slightly larger than card | Yes, black tint | Behind every NPC card | Soft transparent edges |
| `silhouette_overlay.png` | Generic mystery silhouette/glow | `ImageLabel` | Over shadow ViewportFrames | Yes, dark tint | Roll phase unknown NPC overlay | Transparent outside silhouette |
| `question_mark_glow.png` | Glowing mystery question mark | `ImageLabel` | Center of shadow cards | Yes | Roll phase unknown marker | Transparent background |
| `center_spotlight.png` | Soft radial glow behind final NPC | `ImageLabel` | Center stage, large | Yes | Final selection glow build-up | Radial transparent edge |
| `reveal_burst.png` | Radial rays for reveal burst | `ImageLabel` | Behind final card/NPC | Yes | Reveal burst, rotate/tween | Transparent between rays |
| `sparkle_particle_1.png` | Star sparkle particle | `ImageLabel` | 12-28 px | Yes | Animated reveal sparkles | Transparent background |
| `sparkle_particle_2.png` | Plus sparkle particle | `ImageLabel` | 10-24 px | Yes | Animated reveal sparkles | Transparent background |
| `sparkle_particle_3.png` | Soft oval sparkle particle | `ImageLabel` | 10-26 px | Yes | Animated reveal sparkles | Transparent background |
| `rarity_glow_common.png` | Common rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Common final reveal glow | Radial transparent edge |
| `rarity_glow_rare.png` | Rare rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Rare final reveal glow | Radial transparent edge |
| `rarity_glow_epic.png` | Epic rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Epic final reveal glow | Radial transparent edge |
| `rarity_glow_legendary.png` | Legendary rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Legendary final reveal glow | Radial transparent edge |
| `rarity_glow_mythic.png` | Mythic rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Mythic final reveal glow | Radial transparent edge |
| `rarity_glow_secret.png` | Secret/Godly cosmic glow layer | `ImageLabel` | Behind final NPC/card | Optional | Secret/Godly final reveal glow | Radial transparent edge |
| `continue_button_bg.png` | Continue button background only | `ImageButton` or child `ImageLabel` | Continue button bounds | No | Button visual layer; real button text remains Roblox text | Transparent outside pill |
| `continue_button_hover_glow.png` | Continue hover/press glow | `ImageLabel` | Slightly larger than button | Yes | Hover/press feedback layer | Soft transparent edge |
| `title_banner_bg.png` | Title banner decoration | `ImageLabel` | Behind title text | No | Entry/title area | Transparent outside banner |
| `white_flash.png` | Soft reveal flash | `ImageLabel` | Full screen or stage overlay | Yes | Reveal burst moment | Transparent radial edge |
| `dark_vignette.png` | Full-screen cinematic vignette | `ImageLabel` | Full screen | Yes, dark tint optional | Backdrop behind reveal | Transparent center/soft dark edges |

## Upload Instructions

1. Upload every PNG in `assets/gui/npc_reveal/` to Roblox.
2. In Studio, create this structure if it is not already present:
   - `ReplicatedStorage`
   - `GUI`
   - `NPCRevealAssets`
   - `AssetIds` ModuleScript
3. Paste the returned image IDs into `AssetIds` using the matching keys.
4. Keep all labels and buttons as real Roblox UI objects. The images are visual layers only.

## Runtime Notes

The reveal controller tries to require `ReplicatedStorage.GUI.NPCRevealAssets.AssetIds`. If IDs are still placeholders, it falls back to the existing Roblox UI frame/gradient layers so the reveal remains functional while you upload assets.
