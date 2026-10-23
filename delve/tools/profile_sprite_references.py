"""Measure reference PNGs and draw equal-pixel review sheets. Requires Pillow.

Run from any directory. This reads source art without changing it. The JSON is
evidence about the selected frames, not an approved palette for future sprites.
"""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
REFERENCES = [
    ("Rat", "assets/sprites/enemies/rat_v1/idle_1.png"),
    ("Goblin", "assets/sprites/enemies/goblin_base/base.png"),
    ("Kobold", "assets/sprites/enemies/kobold_base/base.png"),
    ("Wolf", "assets/sprites/enemies/wolf_base/base.png"),
]
STUDIES = [
    ("Pack human body (study)", "design/race-identities/layers/human-03.png"),
    ("Pack human outfit (study)", "design/race-identities/previews/player-wardrobe.png"),
]


def inspect(label, relative, role):
    path = ROOT / relative
    with Image.open(path) as source:
        rgba = source.convert("RGBA")
    bounds = rgba.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Empty sprite: {path}")
    pixels = [rgba.getpixel((x, y)) for y in range(rgba.height) for x in range(rgba.width)]
    colors = Counter(p[:3] for p in pixels if p[3] > 0)
    record = {
        "label": label,
        "role": role,
        "path": relative,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "canvas": list(rgba.size),
        "bounds_xyxy_exclusive": list(bounds),
        "visible_size": [bounds[2] - bounds[0], bounds[3] - bounds[1]],
        "bottom_transparent_rows": rgba.height - bounds[3],
        "nontransparent_pixels": sum(colors.values()),
        "partial_alpha_pixels": sum(0 < p[3] < 255 for p in pixels),
        "used_rgb_count": len(colors),
        "colors_by_frequency": [
            {"hex": "#%02X%02X%02X" % rgb, "pixels": count}
            for rgb, count in sorted(colors.items(), key=lambda item: (-item[1], item[0]))
        ],
    }
    return record, rgba.crop(bounds)


def sheet(items, scale, out):
    # Cropping is for presentation only. Full source bounds stay in the JSON.
    cell_width = max(210, max(img.width for _, img in items) * scale + 28)
    height = max(img.height for _, img in items) * scale
    columns = 4
    row_height = height + 86
    canvas = Image.new("RGB", (columns * cell_width, ((len(items) + 3) // 4) * row_height), "#34383E")
    draw = ImageDraw.Draw(canvas)
    for index, (record, img) in enumerate(items):
        left = (index % columns) * cell_width
        top = (index // columns) * row_height
        ground = top + 42 + height
        draw.text((left + 10, top + 8), record["label"], fill="#EEE2C7")
        draw.text((left + 10, top + 23), f'{record["visible_size"][0]}x{record["visible_size"][1]} visible; {record["used_rgb_count"]} colors', fill="#B2B6BC")
        draw.line((left + 10, ground, left + cell_width - 10, ground), fill="#62676F")
        enlarged = img.resize((img.width * scale, img.height * scale), Image.Resampling.NEAREST)
        canvas.paste(enlarged, (left + (cell_width - enlarged.width) // 2, ground - enlarged.height), enlarged)
        palette = record["colors_by_frequency"]
        swatch_width = min(16, (cell_width - 20) // len(palette))
        for n, color in enumerate(palette):
            x = left + 10 + n * swatch_width
            draw.rectangle((x, ground + 10, x + swatch_width - 1, ground + 19), fill=color["hex"])
    canvas.save(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "design/sprite-style")
    args = parser.parse_args()
    items = [inspect(label, path, "rendering reference") for label, path in REFERENCES]
    items += [inspect(label, path, "construction study; not style approval") for label, path in STUDIES]
    args.out.mkdir(parents=True, exist_ok=True)
    profile = {
        "scope": "Selected static PNGs only. Colors are measured, not a universal palette. Lowest opaque row aligns previews; runtime anchors are separate.",
        "sprites": [record for record, _ in items],
    }
    (args.out / "reference-profile.json").write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
    for scale in (1, 4):
        sheet(items, scale, args.out / f"reference-sheet-{scale}x.png")
    for record, _ in items:
        print(f'{record["label"]}: canvas={record["canvas"]}, visible={record["visible_size"]}, colors={record["used_rgb_count"]}, partial_alpha={record["partial_alpha_pixels"]}')


if __name__ == "__main__":
    main()
