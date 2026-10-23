"""Compose a per-character accessory overlay sheet that lines up with that character's face sheet.

Each accessory is a palette-indexed map drawn on frame (0, 0) at ORIGIN, plus a locked RGBA palette.
For every cell of the layout the map moves by the face layer's offset in that cell (the top-left of
its bbox, relative to cell (0, 0)), so the accessory follows the head when an expression shifts it.
A cell whose face layer is empty stays empty. Pixels under the character's hair_top layer are erased,
so the fringe falls over the accessory. The saved sheet is read back and fails on any colour that is
not in the accessory's palette.

    python accessories.py <accessory> <FaceGen> <sheet_layout.json> <recipe.json> <out.png>
"""
import json
import sys
from PIL import Image

import facegen

# Heroes99 faces turn to the viewer's left: near eye at x 23-25, y 24-25, far eye a 1-px sliver at
# x 13, ear on the right.
ACCESSORIES = {
    "spectacles": {
        "origin": (11, 22),
        # x 11-14 far lens (edge-on), 15-20 bridge, 21-27 near lens (7x6), 28-29 temple arm.
        # 1 iron frame, 4 glass, 5 glass sheen.
        "map": [
            ".11........11111...",
            "1541111111154444111",
            "1441......1444441..",
            "1441......1444441..",
            "1441......1444441..",
            ".11........11111...",
        ],
        "palette": {"1": "#2a2830ff", "4": "#9a5cffcc", "5": "#f6efffff"},
    },
}


def rgba(hex_colour):
    h = hex_colour.lstrip("#")
    values = [int(h[i:i + 2], 16) for i in range(0, len(h), 2)]
    return tuple(values + [255] * (4 - len(values)))


def cell_box(row, col, size):
    return (col * size, row * size, (col + 1) * size, (row + 1) * size)


def layer(root, recipe, name, size, rows, columns):
    path = facegen.layer_path(root, recipe, name)
    if not path:
        return None
    image = Image.open(path).convert("RGBA")
    if image.size != (size * columns, size * rows):
        raise ValueError(f"{path} is {image.size}, the layout needs {(size * columns, size * rows)}")
    return image


def compose(accessory, root, layout, recipe):
    size, rows, columns = layout["frame"], layout["rows"], layout["columns"]
    face = layer(root, recipe, "face", size, rows, columns)
    hair = layer(root, recipe, "hair_top", size, rows, columns)
    home = face.crop(cell_box(0, 0, size)).getbbox()
    ox, oy = accessory["origin"]
    palette = {key: rgba(value) for key, value in accessory["palette"].items()}
    sheet = Image.new("RGBA", (size * columns, size * rows), (0, 0, 0, 0))
    shifted = []
    for row in range(rows):
        for col in range(columns):
            box = cell_box(row, col, size)
            bbox = face.crop(box).getbbox()
            if bbox is None:
                continue
            dx, dy = bbox[0] - home[0], bbox[1] - home[1]
            if dx or dy:
                shifted.append(f"({row},{col}) {dx:+d},{dy:+d}")
            hair_cell = hair.crop(box) if hair else None
            for my, line in enumerate(accessory["map"]):
                for mx, key in enumerate(line):
                    colour = palette.get(key)
                    x, y = ox + mx + dx, oy + my + dy
                    if not colour or not (0 <= x < size and 0 <= y < size):
                        continue
                    if hair_cell and hair_cell.getpixel((x, y))[3]:
                        continue
                    sheet.putpixel((box[0] + x, box[1] + y), colour)
    return sheet, shifted


def off_palette(path, accessory):
    allowed = {rgba(value) for value in accessory["palette"].values()}
    image = Image.open(path).convert("RGBA")
    return sorted({p for p in image.get_flattened_data() if p[3] and p not in allowed})


def main() -> int:
    if len(sys.argv) != 6 or sys.argv[1] not in ACCESSORIES:
        print(__doc__)
        return 1
    name, root, layout_path, recipe_path, out = sys.argv[1:6]
    accessory = ACCESSORIES[name]
    layout = json.load(open(layout_path, encoding="utf-8"))
    recipe = json.load(open(recipe_path, encoding="utf-8"))
    sheet, shifted = compose(accessory, root, layout, recipe)
    sheet.save(out)
    bad = off_palette(out, accessory)
    for colour in bad:
        print("FAIL off-palette colour #%02x%02x%02x%02x" % colour)
    print(f"{'FAIL' if bad else 'OK'} {out}: {name}, shifted cells: {', '.join(shifted) or 'none'}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
