from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "generated_assets" / "reveal_gui"


def save(img: Image.Image, name: str) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(OUT_DIR / name)


def blank(size: int) -> Image.Image:
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def radial_glow(size: int, color: tuple[int, int, int]) -> Image.Image:
    img = blank(size)
    px = img.load()
    cx = cy = size / 2
    radius = size * 0.46
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x - cx, y - cy) / radius
            if distance <= 1:
                alpha = int(max(0, (1 - distance) ** 2.2) * 220)
                px[x, y] = (*color, alpha)
    return img.filter(ImageFilter.GaussianBlur(size * 0.025))


def draw_rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def star_points(cx, cy, outer, inner, points=5, rotation=-90):
    pts = []
    for i in range(points * 2):
        angle = math.radians(rotation + i * 180 / points)
        r = outer if i % 2 == 0 else inner
        pts.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    return pts


def make_soft_glow() -> None:
    save(radial_glow(1024, (255, 190, 48)), "soft_glow.png")


def make_burst_ring() -> None:
    size = 1024
    img = blank(size)
    draw = ImageDraw.Draw(img, "RGBA")
    cx = cy = size // 2
    for i in range(24):
        angle = math.radians(i * 15)
        length = 250 if i % 2 == 0 else 170
        width = 18 if i % 2 == 0 else 12
        x1 = cx + math.cos(angle) * 250
        y1 = cy + math.sin(angle) * 250
        x2 = cx + math.cos(angle) * (250 + length)
        y2 = cy + math.sin(angle) * (250 + length)
        draw.line((x1, y1, x2, y2), fill=(255, 203, 62, 135), width=width)
    for radius, color, width in [
        (340, (255, 179, 38, 230), 42),
        (258, (255, 255, 224, 210), 24),
        (392, (255, 242, 142, 100), 16),
    ]:
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=color, width=width)
    save(img.filter(ImageFilter.GaussianBlur(0.25)), "burst_ring.png")


def make_sparkle_star() -> None:
    size = 512
    img = blank(size)
    draw = ImageDraw.Draw(img, "RGBA")
    glow = blank(size)
    glow_draw = ImageDraw.Draw(glow, "RGBA")
    glow_draw.polygon(star_points(256, 256, 210, 82), fill=(255, 224, 82, 140))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(22)))
    draw.polygon(star_points(256, 256, 188, 74), fill=(255, 238, 137, 245))
    draw.polygon(star_points(256, 256, 92, 36), fill=(255, 255, 255, 235))
    save(img, "sparkle_star.png")


def make_shine_streak() -> None:
    size = 512
    img = blank(size)
    layer = blank(size)
    draw = ImageDraw.Draw(layer, "RGBA")
    draw_rounded(draw, (214, 28, 286, 486), 36, (255, 255, 255, 190))
    draw_rounded(draw, (294, 72, 318, 444), 12, (104, 218, 255, 120))
    layer = layer.rotate(-24, resample=Image.Resampling.BICUBIC)
    img.alpha_composite(layer)
    save(img.filter(ImageFilter.GaussianBlur(0.4)), "shine_streak.png")


def make_card_glow() -> None:
    size = 1024
    img = blank(size)
    draw = ImageDraw.Draw(img, "RGBA")
    glow = blank(size)
    glow_draw = ImageDraw.Draw(glow, "RGBA")
    draw_rounded(glow_draw, (154, 90, 870, 934), 86, (255, 191, 56, 110))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(34)))
    draw_rounded(draw, (190, 132, 834, 892), 72, (255, 255, 220, 66), (255, 255, 255, 92), 8)
    save(img, "reveal_card_glow.png")


def make_new_badge() -> None:
    size = 512
    img = blank(size)
    layer = blank(size)
    draw = ImageDraw.Draw(layer, "RGBA")
    draw_rounded(draw, (64, 148, 448, 332), 58, (255, 67, 92, 250), (255, 255, 255, 190), 10)
    draw_rounded(draw, (100, 184, 410, 222), 19, (255, 255, 255, 70))
    layer = layer.rotate(-8, resample=Image.Resampling.BICUBIC)
    img.alpha_composite(layer)
    save(img, "new_badge.png")


def make_tap_panel() -> None:
    size = 1024
    img = blank(size)
    draw = ImageDraw.Draw(img, "RGBA")
    shadow = blank(size)
    shadow_draw = ImageDraw.Draw(shadow, "RGBA")
    draw_rounded(shadow_draw, (196, 380, 828, 644), 132, (0, 0, 0, 90))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(20)))
    draw_rounded(draw, (180, 360, 844, 620), 130, (18, 24, 38, 188), (255, 255, 255, 85), 8)
    draw_rounded(draw, (236, 412, 788, 466), 27, (255, 255, 255, 32))
    save(img, "tap_panel.png")


def make_burst_spritesheet() -> None:
    frame = 256
    sheet = Image.new("RGBA", (frame * 6, frame), (0, 0, 0, 0))
    for i in range(6):
        cell = blank(frame)
        draw = ImageDraw.Draw(cell, "RGBA")
        cx = cy = frame // 2
        progress = (i + 1) / 6
        radius = int(28 + progress * 88)
        alpha = int((1 - progress * 0.55) * 230)
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(255, 202, 62, alpha), width=max(3, int(14 * (1 - progress * 0.5))))
        for ray in range(12):
            angle = math.radians(ray * 30)
            start = radius + 12
            end = radius + 26 + progress * 30
            draw.line(
                (
                    cx + math.cos(angle) * start,
                    cy + math.sin(angle) * start,
                    cx + math.cos(angle) * end,
                    cy + math.sin(angle) * end,
                ),
                fill=(255, 240, 150, max(0, alpha - 40)),
                width=4,
            )
        sheet.alpha_composite(cell, (i * frame, 0))
    save(sheet, "burst_spritesheet.png")


def write_readme() -> None:
    (OUT_DIR / "README.md").write_text(
        """# Reveal GUI PNG Assets

Generated by `tools/reveal-ui-lab/export_assets.py`. These are transparent PNGs for the Roblox NPC egg reveal GUI.

Upload these PNGs to Roblox:

- soft_glow.png
- burst_ring.png
- sparkle_star.png
- shine_streak.png
- reveal_card_glow.png
- new_badge.png
- tap_panel.png
- burst_spritesheet.png (optional)

Paste the Roblox image IDs into `src/StarterPlayer/StarterPlayerScripts/NPCRevealAssets.lua`.
The game still runs with fallback UI shapes while IDs are placeholders.
""",
        encoding="utf-8",
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    make_soft_glow()
    make_burst_ring()
    make_sparkle_star()
    make_shine_streak()
    make_card_glow()
    make_new_badge()
    make_tap_panel()
    make_burst_spritesheet()
    write_readme()


if __name__ == "__main__":
    main()
