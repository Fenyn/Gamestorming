"""Draw the Friend's hand lantern: a 9x14 iron lantern, a ring at the top centre and a cage of 2 px
bars around a lit flame.

Writes assets/sprites/decor/lantern.png at 1x and checks every pixel against PALETTE.
Run from the ungilded folder: python tools/art/draw_lantern.py
"""
import sys
from pathlib import Path
from PIL import Image

# Index 0 is transparent. Iron 1-3 are the Friend's own darks and grey (heroes/friend/rest_1.png).
# Flame 4-6 is a warm ramp, core to edge.
PALETTE = {
    0: (0, 0, 0, 0),
    1: (0x30, 0x2D, 0x29, 0xFF),
    2: (0x45, 0x41, 0x3A, 0xFF),
    3: (0x72, 0x75, 0x75, 0xFF),
    4: (0xFF, 0xF1, 0xB8, 0xFF),
    5: (0xF2, 0xB8, 0x4B, 0xFF),
    6: (0xD9, 0x72, 0x2B, 0xFF),
}

ROWS = [
    "000111000",
    "001000100",
    "000101000",
    "012222210",
    "123333321",
    "126666621",
    "126656621",
    "126545621",
    "125444521",
    "125444521",
    "126545621",
    "123333321",
    "012222210",
    "001111100",
]

OUT = Path(__file__).resolve().parents[2] / "assets" / "sprites" / "decor" / "lantern.png"


def main() -> int:
    width = len(ROWS[0])
    image = Image.new("RGBA", (width, len(ROWS)))
    for y, row in enumerate(ROWS):
        assert len(row) == width, f"row {y} is {len(row)} wide"
        for x, index in enumerate(row):
            image.putpixel((x, y), PALETTE[int(index)])
    image.save(OUT)

    allowed = set(PALETTE.values())
    used = Image.open(OUT).convert("RGBA").getcolors(maxcolors=4096)
    stray = {c for _, c in used if c not in allowed}
    if stray:
        print(f"FAIL off-palette colours: {sorted(stray)}")
        return 1
    print(f"OK {OUT} {image.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
