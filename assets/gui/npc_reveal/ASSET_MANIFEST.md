# NPC Reveal GUI Asset Manifest

These assets are decorative layers only. Do not bake dynamic text, buttons, NPC names, rarity labels, or click logic into these images. The current style is a full-screen cinematic simulator reveal: dark vignette, purple rarity rays, shadow NPC silhouettes, big real Roblox text, and a separate green Continue button.

The reveal client now supports two asset setup styles:
- Put uploaded `ImageLabel`, `ImageButton`, `Decal`, `Texture`, or `StringValue` objects anywhere under `ReplicatedStorage/GUI` and name them with either the manifest key or PNG filename, such as `RevealBurst` or `reveal_burst.png`.
- Or paste IDs into `ReplicatedStorage/GUI/NPCRevealAssets/AssetIds`.

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
| `cinematic_energy_beams.png` | Wide purple light beam field matching the reference reward explosion | `ImageLabel` | Full-screen center, around 112% x 112% | Yes | Persistent cinematic beams behind silhouettes and final NPC | Transparent between beams |
| `cinematic_confetti_field.png` | Floating purple/white rectangular shard field | `ImageLabel` | Full-screen overlay, around 105% x 105% | Optional | Lightweight confetti layer during reveal | Transparent outside shards |
| `cinematic_floor_glow.png` | Purple oval floor/base glow under the NPC lineup | `ImageLabel` | Lower center, around 86% x 32% | Yes | Grounds the silhouette row and final NPC | Soft transparent edges |
| `silhouette_rim_glow.png` | Generic purple rim glow for mystery silhouettes | `ImageLabel` | Over each roll silhouette/card | Yes | Adds the screenshot-like purple outline to unknown NPCs | Transparent outside generic aura |
| `rolling_card_frame.png` | Purple glowing card frame for side roll slots | `ImageLabel` | Same as each roll card | Yes | Rolling phase mystery card frames | Transparent outside frame |
| `rolling_center_card_frame.png` | Brighter purple frame for the center roll slot | `ImageLabel` | Same as center roll card | Yes | Center card highlight while rolling | Transparent outside frame |
| `rarity_badge_bg.png` | Decorative badge behind rarity text | `ImageLabel` | Center under roll card | Yes | Rolling phase rarity badge; text stays real Roblox text | Transparent outside badge |
| `rolling_bar_bg.png` | Decorative progress bar track | `ImageLabel` | Lower center footer | Yes | Rolling phase progress bar background | Transparent outside rounded bar |
| `rolling_bar_fill.png` | Glowing rolling progress fill | `ImageLabel` | Cropped/scaled over bar track | Yes | Rolling phase progress fill | Transparent outside rounded bar |
| `rolling_chevrons.png` | Purple chevron decoration | `ImageLabel` | Beside `ROLLING...` text | Yes | Rolling footer directional accents | Transparent outside chevrons |
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
2. Put the uploaded image objects under `ReplicatedStorage/GUI`. The code searches this folder recursively.
3. Name each uploaded image object using either the key-style name or the original filename, for example `CinematicEnergyBeams` or `cinematic_energy_beams.png`.
4. Optional fallback: in Studio, create this structure if it is not already present:
   - `ReplicatedStorage`
   - `GUI`
   - `NPCRevealAssets`
   - `AssetIds` ModuleScript
5. Paste the returned image IDs into `AssetIds` using the matching keys if you prefer a ModuleScript lookup.
6. Keep all labels and buttons as real Roblox UI objects. The images are visual layers only.

## Runtime Notes

The reveal controller first tries `ReplicatedStorage.GUI.NPCRevealAssets.AssetIds`. If IDs are placeholders, it searches `ReplicatedStorage.GUI` recursively for matching uploaded image instances. If no asset is found, it falls back to the existing Roblox UI frame/gradient layers so the reveal remains functional while you upload assets.
