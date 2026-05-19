# NPC Reveal GUI Asset Manifest

These assets are decorative layers only. Do not bake dynamic text, buttons, NPC names, rarity labels, or click logic into these images. The current style is a full-screen cinematic simulator reveal: dark vignette, purple rarity rays, shadow NPC silhouettes, big real Roblox text, and a separate green Continue button. Upload the PNGs to Roblox, then paste the IDs into `ReplicatedStorage/GUI/NPCRevealAssets/AssetIds`.

| Filename | Purpose | Roblox object | Suggested size/scale | Tintable | Reveal usage | Transparency notes |
|---|---|---|---|---|---|---|
| `reveal_panel_bg.png` | Subtle purple stage plate, not a full UI panel | `ImageLabel` | Center screen, around 78% x 46% | No | Low-opacity cinematic stage depth | Transparent corners/edges |
| `reveal_panel_shadow.png` | Wide purple shadow/glow behind the stage | `ImageLabel` | Around 95% x 62% screen | Yes, black/rarity tint optional | Behind the silhouettes and final NPC | Transparent fade edges |
| `npc_card_bg.png` | Semi-transparent glossy silhouette card base | `ImageLabel` | Each carousel card | No | Light backing for roll silhouettes | Transparent corners |
| `npc_card_outline.png` | Decorative card outline layer | `ImageLabel` | Same as card | Yes | Rarity-colored outline overlay | Mostly transparent except outline |
| `npc_card_shadow.png` | Soft oval card/silhouette floor shadow | `ImageLabel` | Slightly larger than card | Yes, black tint | Behind every roll silhouette | Soft transparent edges |
| `silhouette_overlay.png` | Generic mystery silhouette aura | `ImageLabel` | Over shadow ViewportFrames | Yes, dark tint | Roll phase unknown NPC overlay | Transparent outside aura |
| `question_mark_glow.png` | Glowing mystery question mark | `ImageLabel` | Center of shadow cards | Yes | Roll phase unknown marker | Transparent background |
| `center_spotlight.png` | Bright white/purple center glow behind final NPC | `ImageLabel` | Center screen, around 92% x 92% | Yes | Final selection glow build-up | Radial transparent edge |
| `reveal_burst.png` | Large purple radial rays like a reward explosion | `ImageLabel` | Full-screen center burst | Yes | Ambient roll energy and final burst, rotate/tween | Transparent between rays |
| `sparkle_particle_1.png` | Diamond shard particle | `ImageLabel` | 12-34 px | Yes | Animated reveal confetti/sparkles | Transparent background |
| `sparkle_particle_2.png` | Tilted rectangle shard particle | `ImageLabel` | 10-32 px | Yes | Animated reveal confetti/sparkles | Transparent background |
| `sparkle_particle_3.png` | Triangle shard particle | `ImageLabel` | 10-32 px | Yes | Animated reveal confetti/sparkles | Transparent background |
| `rarity_glow_common.png` | Common rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Common final reveal glow | Radial transparent edge |
| `rarity_glow_rare.png` | Rare rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Rare final reveal glow | Radial transparent edge |
| `rarity_glow_epic.png` | Epic rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Epic final reveal glow | Radial transparent edge |
| `rarity_glow_legendary.png` | Legendary rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Legendary final reveal glow | Radial transparent edge |
| `rarity_glow_mythic.png` | Mythic rarity glow layer | `ImageLabel` | Behind final NPC/card | Optional | Mythic final reveal glow | Radial transparent edge |
| `rarity_glow_secret.png` | Secret/Godly cosmic glow layer | `ImageLabel` | Behind final NPC/card | Optional | Secret/Godly final reveal glow | Radial transparent edge |
| `continue_button_bg.png` | Chunky green Continue button background only | `ImageButton` or child `ImageLabel` | Continue button bounds | No | Button visual layer; real button text remains Roblox text | Transparent outside pill |
| `continue_button_hover_glow.png` | Continue hover/press glow | `ImageLabel` | Slightly larger than button | Yes | Hover/press feedback layer | Soft transparent edge |
| `title_banner_bg.png` | Soft purple title glow plate, no text | `ImageLabel` | Behind title text | Yes | Entry/title area | Transparent outside glow |
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
