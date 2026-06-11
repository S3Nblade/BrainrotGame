#!/usr/bin/env python3
"""Generate original pixel-art PNG assets for Pixel Brainrot Simulator."""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "generated"
MANIFEST = ROOT / "assets" / "manifest.json"
SCALE = 4
SIZE = 16
TRANSPARENT = (0, 0, 0, 0)
INK = (28, 29, 42, 255)
WHITE = (245, 247, 255, 255)

RARITIES = {
    "common": (196, 206, 214, 255),
    "rare": (64, 157, 255, 255),
    "epic": (179, 86, 255, 255),
    "legendary": (255, 183, 47, 255),
    "mythic": (255, 72, 121, 255),
    "divine": (76, 255, 217, 255),
    "secret": (255, 255, 255, 255),
}

BRAINROTS = {
    "byte_bunny": ((127, 225, 255, 255), "ears"),
    "toast_ghost": ((255, 225, 163, 255), "ghost"),
    "puddle_pup": ((76, 164, 255, 255), "ears"),
    "cactus_cat": ((93, 196, 102, 255), "cat"),
    "dune_duck": ((255, 188, 75, 255), "beak"),
    "frost_frog": ((113, 246, 236, 255), "frog"),
    "chill_chinchilla": ((190, 182, 255, 255), "round"),
    "magma_moth": ((255, 107, 55, 255), "wings"),
    "ember_eel": ((255, 68, 105, 255), "eel"),
    "glitch_gloop": ((68, 255, 159, 255), "gloop"),
    "null_narwhal": ((77, 48, 120, 255), "horn"),
    "pixel_prime": ((245, 247, 255, 255), "crown"),
}

ZONES = {
    "grass": ((92, 193, 91, 255), (56, 142, 70, 255)),
    "desert": ((235, 194, 101, 255), (196, 131, 67, 255)),
    "ice": ((146, 224, 242, 255), (82, 159, 210, 255)),
    "lava": ((91, 55, 61, 255), (244, 89, 48, 255)),
    "glitch": ((48, 38, 73, 255), (68, 255, 169, 255)),
}

manifest: list[dict[str, object]] = []


def canvas(size: int = SIZE) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (size, size), TRANSPARENT)
    return image, ImageDraw.Draw(image)


def save(image: Image.Image, category: str, name: str, use: str, frames: int = 1) -> None:
    folder = OUTPUT / category
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{name}.png"
    image = image.resize((image.width * SCALE, image.height * SCALE), Image.Resampling.NEAREST)
    image.save(path, optimize=True)
    manifest.append(
        {
            "path": path.relative_to(ROOT).as_posix(),
            "category": category,
            "name": name,
            "robloxUse": use,
            "pixelSize": [image.width, image.height],
            "frames": frames,
            "assetId": "rbxassetid://0",
        }
    )


def brainrot_sprite(name: str, color: tuple[int, ...], shape: str) -> None:
    image, draw = canvas()
    shade = tuple(max(0, value - 45) for value in color[:3]) + (255,)
    light = tuple(min(255, value + 45) for value in color[:3]) + (255,)
    if shape == "eel":
        draw.rectangle((3, 5, 12, 11), fill=INK)
        draw.rectangle((2, 7, 4, 10), fill=INK)
        draw.rectangle((4, 6, 11, 10), fill=color)
        draw.rectangle((11, 4, 13, 8), fill=color)
    else:
        draw.rectangle((3, 4, 12, 13), fill=INK)
        draw.rectangle((4, 3, 11, 13), fill=INK)
        draw.rectangle((4, 5, 11, 12), fill=color)
        draw.rectangle((5, 4, 10, 12), fill=color)
    if shape in {"ears", "cat"}:
        draw.rectangle((4, 1, 6, 5), fill=INK)
        draw.rectangle((9, 1, 11, 5), fill=INK)
        draw.rectangle((5, 2, 5, 4), fill=light)
        draw.rectangle((10, 2, 10, 4), fill=light)
    elif shape == "ghost":
        draw.rectangle((4, 12, 5, 14), fill=color)
        draw.rectangle((7, 12, 8, 14), fill=color)
        draw.rectangle((10, 12, 11, 14), fill=color)
    elif shape == "beak":
        draw.rectangle((11, 7, 14, 9), fill=(255, 135, 45, 255))
    elif shape == "frog":
        draw.rectangle((3, 3, 6, 6), fill=color)
        draw.rectangle((9, 3, 12, 6), fill=color)
    elif shape == "round":
        draw.rectangle((2, 6, 4, 10), fill=shade)
        draw.rectangle((11, 6, 13, 10), fill=shade)
    elif shape == "wings":
        draw.rectangle((1, 5, 4, 11), fill=shade)
        draw.rectangle((11, 5, 14, 11), fill=shade)
    elif shape == "gloop":
        draw.rectangle((2, 11, 4, 13), fill=color)
        draw.rectangle((7, 12, 9, 14), fill=color)
        draw.rectangle((11, 11, 13, 13), fill=color)
        draw.rectangle((2, 4, 3, 5), fill=(255, 45, 187, 255))
        draw.rectangle((12, 8, 14, 9), fill=(76, 174, 255, 255))
    elif shape == "horn":
        draw.polygon([(7, 4), (9, 0), (10, 5)], fill=(129, 255, 244, 255))
    elif shape == "crown":
        draw.polygon([(4, 5), (4, 1), (7, 4), (9, 1), (11, 5)], fill=(255, 218, 72, 255))
    draw.rectangle((5, 7, 6, 8), fill=INK)
    draw.rectangle((9, 7, 10, 8), fill=INK)
    draw.rectangle((7, 10, 8, 10), fill=shade)
    draw.rectangle((5, 5, 6, 5), fill=light)
    save(image, "brainrots", name, f"World BillboardGui sprite, inventory card, index card, and reveal for {name}")


def egg_sprite(zone: str, base: tuple[int, ...], accent: tuple[int, ...]) -> None:
    image, draw = canvas()
    draw.rectangle((5, 2, 10, 13), fill=INK)
    draw.rectangle((3, 6, 12, 11), fill=INK)
    draw.rectangle((4, 5, 11, 11), fill=base)
    draw.rectangle((5, 3, 10, 12), fill=base)
    draw.rectangle((5, 6, 7, 7), fill=accent)
    draw.rectangle((9, 9, 11, 10), fill=accent)
    draw.rectangle((6, 4, 7, 4), fill=WHITE)
    save(image, "eggs", f"{zone}_egg", f"Reveal animation egg for the {zone.title()} Zone")


def rarity_frame(name: str, color: tuple[int, ...]) -> None:
    image, draw = canvas()
    draw.rectangle((0, 0, 15, 15), fill=color)
    draw.rectangle((2, 2, 13, 13), fill=(38, 43, 62, 255))
    draw.rectangle((1, 1, 2, 2), fill=WHITE)
    draw.rectangle((13, 13, 14, 14), fill=INK)
    save(image, "rarity_frames", f"{name}_frame", f"Nine-slice style frame for {name.title()} cards")


def mutation_overlay(name: str, color: tuple[int, ...], pattern: str) -> None:
    image, draw = canvas()
    if pattern == "spark":
        for x, y in [(2, 3), (12, 2), (4, 12), (11, 11)]:
            draw.line((x - 1, y, x + 1, y), fill=color)
            draw.line((x, y - 1, x, y + 1), fill=color)
    elif pattern == "diamond":
        for x, y in [(3, 4), (12, 3), (5, 12), (11, 10)]:
            draw.polygon([(x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)], fill=color)
    elif pattern == "shadow":
        draw.arc((1, 1, 14, 14), 20, 310, fill=color, width=2)
        draw.rectangle((2, 11, 13, 13), fill=(color[0], color[1], color[2], 130))
    else:
        for index in range(7):
            y = 1 + index * 2
            x = (index * 5) % 12
            draw.rectangle((x, y, min(15, x + 4), y), fill=color)
    save(image, "mutations", f"{name}_overlay", f"Transparent sprite overlay for the {name.title()} mutation")


def icon(name: str, primary: tuple[int, ...], symbol: str) -> None:
    image, draw = canvas()
    draw.rectangle((2, 2, 13, 13), fill=INK)
    draw.rectangle((3, 3, 12, 12), fill=primary)
    if symbol == "coin":
        draw.rectangle((6, 4, 9, 11), fill=WHITE)
        draw.rectangle((5, 6, 10, 9), fill=WHITE)
    elif symbol == "gem":
        draw.polygon([(8, 3), (13, 7), (8, 13), (3, 7)], fill=WHITE)
        draw.polygon([(8, 5), (10, 7), (8, 10), (6, 7)], fill=primary)
    elif symbol == "rebirth":
        draw.arc((4, 4, 12, 12), 40, 320, fill=WHITE, width=2)
        draw.polygon([(3, 5), (7, 4), (5, 8)], fill=WHITE)
    elif symbol == "bag":
        draw.rectangle((4, 6, 11, 12), fill=WHITE)
        draw.arc((6, 2, 9, 8), 180, 360, fill=WHITE, width=1)
    elif symbol == "book":
        draw.rectangle((3, 4, 7, 12), fill=WHITE)
        draw.rectangle((9, 4, 13, 12), fill=WHITE)
    elif symbol == "cart":
        draw.rectangle((4, 5, 12, 9), fill=WHITE)
        draw.point((6, 12), fill=WHITE)
        draw.point((11, 12), fill=WHITE)
    save(image, "icons", name, f"HUD and menu icon for {name}")


def zone_icon(name: str, base: tuple[int, ...], accent: tuple[int, ...]) -> None:
    image, draw = canvas()
    draw.rectangle((1, 1, 14, 14), fill=INK)
    draw.rectangle((2, 2, 13, 13), fill=base)
    for y in range(3, 14, 3):
        offset = (y // 3) % 2
        for x in range(2 + offset * 2, 14, 4):
            draw.rectangle((x, y, min(13, x + 1), y + 1), fill=accent)
    save(image, "zone_icons", f"{name}_zone", f"Zone selector icon for {name.title()} Zone")


def ui_button(name: str, color: tuple[int, ...], use: str) -> None:
    image, draw = canvas(24)
    draw.rectangle((1, 2, 22, 21), fill=INK)
    draw.rectangle((2, 1, 21, 20), fill=color)
    draw.rectangle((4, 3, 19, 5), fill=tuple(min(255, value + 35) for value in color[:3]) + (255,))
    draw.rectangle((4, 17, 19, 19), fill=tuple(max(0, value - 40) for value in color[:3]) + (255,))
    save(image, "ui", name, use)


def tile(name: str, base: tuple[int, ...], accent: tuple[int, ...]) -> None:
    image, draw = canvas()
    draw.rectangle((0, 0, 15, 15), fill=base)
    rng = random.Random(name)
    for _ in range(18):
        x, y = rng.randrange(16), rng.randrange(16)
        draw.point((x, y), fill=accent)
        if rng.random() > 0.65:
            draw.point(((x + 1) % 16, y), fill=accent)
    save(image, "tiles", f"{name}_tile", f"Repeating floor texture for {name.title()} Zone")


def reveal_frames() -> None:
    for frame in range(1, 7):
        image, draw = canvas()
        offset = int(round(math.sin(frame * 2.1) * 2))
        draw.rectangle((5 + offset, 2, 10 + offset, 13), fill=INK)
        draw.rectangle((4 + offset, 5, 11 + offset, 12), fill=(242, 239, 220, 255))
        if frame >= 3:
            draw.line((8 + offset, 5, 7 + offset, 8, 9 + offset, 10, 8 + offset, 13), fill=(75, 66, 72, 255))
        save(image, "reveal", f"egg_shake_{frame}", f"Reveal animation egg shake frame {frame}", 6)
    for frame in range(1, 5):
        image, draw = canvas()
        radius = frame * 2
        draw.rectangle((8 - radius, 8 - radius, 8 + radius, 8 + radius), outline=(255, 255, 255, max(40, 255 - frame * 45)), width=1)
        save(image, "reveal", f"flash_{frame}", f"Reveal animation flash frame {frame}", 4)


def capture_frames() -> None:
    for frame in range(1, 7):
        image, draw = canvas()
        radius = frame + 1
        color = (77, 255, 172, max(30, 255 - frame * 30))
        draw.rectangle((8 - radius, 8 - radius, 8 + radius, 8 + radius), outline=color)
        for angle in range(0, 360, 90):
            x = round(8 + math.cos(math.radians(angle)) * radius)
            y = round(8 + math.sin(math.radians(angle)) * radius)
            draw.rectangle((x, y, x + 1, y + 1), fill=WHITE)
        save(image, "capture", f"capture_burst_{frame}", f"World capture burst frame {frame}", 6)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for old in OUTPUT.rglob("*.png"):
        old.unlink()
    for name, (color, shape) in BRAINROTS.items():
        brainrot_sprite(name, color, shape)
    for name, (base, accent) in ZONES.items():
        egg_sprite(name, base, accent)
        zone_icon(name, base, accent)
        tile(name, base, accent)
    for name, color in RARITIES.items():
        rarity_frame(name, color)
        ui_button(f"inventory_slot_{name}", color, f"Inventory slot background for {name.title()} rarity")
        ui_button(f"index_card_{name}", color, f"Index card background for {name.title()} rarity")
    mutation_overlay("golden", (255, 210, 56, 255), "spark")
    mutation_overlay("diamond", (88, 235, 255, 255), "diamond")
    mutation_overlay("shadow", (91, 62, 133, 190), "shadow")
    mutation_overlay("glitched", (82, 255, 120, 255), "glitch")
    icon("coin", (255, 190, 45, 255), "coin")
    icon("gem", (75, 205, 255, 255), "gem")
    icon("rebirth", (178, 86, 255, 255), "rebirth")
    icon("inventory", (77, 166, 255, 255), "bag")
    icon("shop", (70, 225, 126, 255), "cart")
    icon("index", (255, 218, 72, 255), "book")
    ui_button("shop_luck", (177, 92, 255, 255), "Shop button for Luck Boost")
    ui_button("shop_speed", (77, 166, 255, 255), "Shop button for Speed Boost")
    ui_button("shop_storage", (255, 183, 47, 255), "Shop button for Storage Upgrade")
    ui_button("shop_money", (70, 225, 126, 255), "Shop button for Money Boost")
    ui_button("upgrade_normal", (255, 218, 72, 255), "Brainrot upgrade button")
    ui_button("upgrade_max", (170, 180, 204, 255), "Disabled max-level upgrade button")
    reveal_frames()
    capture_frames()
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(
        json.dumps(
            {
                "game": "Pixel Brainrot Simulator",
                "generator": "tools/generate_pixel_assets.py",
                "license": "Original project-generated artwork",
                "count": len(manifest),
                "assets": sorted(manifest, key=lambda item: str(item["path"])),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Generated {len(manifest)} PNG files in {OUTPUT}")
    print(f"Wrote {MANIFEST}")


if __name__ == "__main__":
    main()
