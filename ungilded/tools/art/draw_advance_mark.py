"""Draw the dialogue "next line" caret: an 11x7 down-pointing triangle.

Writes assets/ui/advance_mark.png at 1x and checks every pixel against PALETTE.
Run from the ungilded folder: python tools/art/draw_advance_mark.py
"""
import sys
from pathlib import Path
from PIL import Image

# Index 0 is transparent. Fill is the DialogueName bone, outline is near-black, tip shade is a darker bone.
PALETTE = {
    0: (0, 0, 0, 0),
    1: (0x1A, 0x16, 0x14, 0xFF),
    2: (0xE6, 0xDC, 0xC6, 0xFF),
    3: (0xA8, 0x9F, 0x8C, 0xFF),
}

ROWS = [
    "11111111111",
    "12222222221",
    "01222222210",
    "00122222100",
    "00012333100",
    "00001310000",
    "00000100000",
]

OUT = Path(__file__).resolve().parents[2] / "assets" / "ui" / "advance_mark.png"


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
