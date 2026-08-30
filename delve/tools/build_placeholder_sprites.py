"""Generate the missing-art placeholder enemy sprites.

Output: assets/sprites/enemies/placeholder_{small,medium,large}/idle_1.png..idle_8.png

The look is deliberately unmistakable: a magenta/black checkerboard body with a big white "?".
A rat on the board means rat art exists; a checkerboard means the creature needs art.
Size is baked into the PNG height because BillboardSpriteAnimator derives world height from
texture height (0.02 m per pixel): small ~0.7 m, medium ~1.6 m, large ~2.4 m.

The 8 idle frames bob the "?" on a small sine so the token reads as alive.
Run from anywhere: paths resolve relative to this file.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "enemies"

MAGENTA = (255, 0, 220, 255)
BLACK = (20, 10, 20, 255)
OUTLINE = (0, 0, 0, 255)
FRAMES = 8

# name -> (width, height, checker cell, glyph size)
SIZES = {
    "placeholder_small": (48, 36, 6, 22),
    "placeholder_medium": (56, 80, 8, 34),
    "placeholder_large": (96, 120, 12, 52),
}


def load_font(px: int) -> ImageFont.FreeTypeFont:
    for name in ("arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_frame(width: int, height: int, cell: int, glyph_px: int, frame: int) -> Image.Image:
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Checkerboard body with a 2 px black outline, inset 1 px so the outline survives filtering.
    body = (1, 1, width - 2, height - 2)
    shift = (frame // 4) % 2  # slow shimmer: the checker phase flips halfway through the loop
    for y in range(body[1], body[3], cell):
        for x in range(body[0], body[2], cell):
            parity = ((x // cell) + (y // cell) + shift) % 2
            draw.rectangle(
                (x, y, min(x + cell - 1, body[2]), min(y + cell - 1, body[3])),
                fill=MAGENTA if parity == 0 else BLACK,
            )
    draw.rectangle(body, outline=OUTLINE, width=2)

    # Bobbing "?": +-2 px sine over the loop.
    bob = round(2 * math.sin(2 * math.pi * frame / FRAMES))
    font = load_font(glyph_px)
    draw.text(
        (width / 2, height / 2 + bob),
        "?",
        font=font,
        fill=(255, 255, 255, 255),
        anchor="mm",
        stroke_width=2,
        stroke_fill=OUTLINE,
    )
    return img


def main() -> None:
    for name, (width, height, cell, glyph_px) in SIZES.items():
        folder = ROOT / name
        folder.mkdir(parents=True, exist_ok=True)
        for frame in range(FRAMES):
            img = draw_frame(width, height, cell, glyph_px, frame)
            img.save(folder / f"idle_{frame + 1}.png")
        print(f"{name}: {FRAMES} frames at {width}x{height}")


if __name__ == "__main__":
    main()
