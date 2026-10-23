"""Lay the roster close-ups from roster_shot_spike out on one labelled sheet.

    python tools/art/roster_sheet.py <shot_dir> [out.png]

Reads roster_<slug>.png (the per-unit close-ups, not roster_forest*.png), keeps the
spike's roster order, and writes a grid with the unit's name under each tile.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ORDER = [
    "the_player", "the_friend",
    "giant_rat", "viper", "goblin_warrior", "kobold_warrior", "wolf", "hunting_spider",
    "boar", "giant_monitor_lizard", "giant_viper", "dire_wolf", "grizzly_bear",
    "giant_stag_beetle", "dire_sewer_rat", "sewer_tyrant",
]
COLUMNS = 4
TILE = (400, 225)
LABEL = 28
GAP = 6


def main():
    shots = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else shots / "roster_sheet.png"
    files = {p.stem[len("roster_"):]: p for p in shots.glob("roster_*.png") if not p.stem.startswith("roster_forest")}
    slugs = [s for s in ORDER if s in files] + sorted(s for s in files if s not in ORDER)
    rows = (len(slugs) + COLUMNS - 1) // COLUMNS
    cell = (TILE[0] + GAP, TILE[1] + LABEL + GAP)
    sheet = Image.new("RGB", (COLUMNS * cell[0] + GAP, rows * cell[1] + GAP), (24, 22, 20))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=18)
    for i, slug in enumerate(slugs):
        x = GAP + (i % COLUMNS) * cell[0]
        y = GAP + (i // COLUMNS) * cell[1]
        tile = Image.open(files[slug]).convert("RGB").resize(TILE, Image.LANCZOS)
        sheet.paste(tile, (x, y))
        name = slug.replace("_", " ").title()
        draw.text((x + TILE[0] / 2, y + TILE[1] + LABEL / 2), name, fill=(220, 210, 190), font=font, anchor="mm")
    sheet.save(out)
    print(f"{out}: {len(slugs)} units, {sheet.size[0]}x{sheet.size[1]}")


if __name__ == "__main__":
    main()
