"""Bakes the condition icons into 22 px HUD tiles: bone art on a dark tile, one texel per art cell.

The source icons hold 22x22 cells of 22 texels inside a 14-texel margin. Each tile samples the
centre of every cell: the navy fill becomes Palette accent (bone), the light rim becomes Palette
ink, and empty cells take Palette recess. Colours are read from assets/ui/ui_theme.tres, so a
palette change needs only a re-run.

Usage (from delve/): python tools/art/bake_condition_tiles.py
"""
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/ui/conditions"
TARGET = SOURCE / "tiles"
THEME = ROOT / "assets/ui/ui_theme.tres"
MARGIN, CELL, CELLS = 14, 22, 22


def palette(name):
    text = THEME.read_text(encoding="utf-8")
    match = re.search(rf"Palette/colors/{name} = Color\(([^)]*)\)", text)
    r, g, b, _ = (float(v) for v in match.group(1).split(","))
    return round(r * 255), round(g * 255), round(b * 255), 255


def bake(path, fill, rim, tile):
    source = Image.open(path).convert("RGBA")
    pixels = source.load()
    out = Image.new("RGBA", (CELLS, CELLS), tile)
    for y in range(CELLS):
        for x in range(CELLS):
            r, g, b, a = pixels[MARGIN + x * CELL + CELL // 2, MARGIN + y * CELL + CELL // 2]
            if a < 128:
                continue
            light = (0.299 * r + 0.587 * g + 0.114 * b) / 255 >= 0.5
            out.putpixel((x, y), rim if light else fill)
    return out


def main():
    fill, rim, tile = palette("accent"), palette("ink"), palette("recess")
    TARGET.mkdir(exist_ok=True)
    names = sorted(p for p in SOURCE.glob("*.png"))
    for path in names:
        bake(path, fill, rim, tile).save(TARGET / path.name)
    print(f"baked {len(names)} tiles to {TARGET}")


if __name__ == "__main__":
    main()
