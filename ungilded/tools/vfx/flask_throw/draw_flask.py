"""Draws the pixel-art frames of the thrown acid flask (res://scenes/fx/flask_throw.tscn).

The flask turns about the centre of its bulb, the centre of the cell. The bulb is one fixed 7 x 7
pixel circle in every frame, because a circle turned off the texel grid rasterises lumpy and
different each time. Only the neck and cork turn: frame k points them 45 * k degrees clockwise
from up, from two hand-placed stoppers (up and up-right) turned by exact quarter turns. Shading
uses a light fixed at the top left of the screen, so the highlight stays put while the flask turns. Every texture is a palette-index canvas
written as RGBA PNG, read back and checked against the palette; a colour that is not on the list
fails the run.

    python tools/vfx/flask_throw/draw_flask.py [--preview <dir>]

The pack flask in the Friend's hand (design/hero-sprites/masters/work/friend/layers/
arm_far__relaxed__off_flask_*.png) is 5 x 7 texels: a 4 x 4 bulb and a 1 texel neck, with no cork
and no rim, because the hand covers them. Cropped alone it reads as a green dot on a stick, so the
thrown flask is drawn here on the same palette with the same bulb shading (pale spot top left,
body, mid, dark bottom right) and the parts the hand hides.

Grid: one texel is 0.02 m at scale 1, the Prologue sprites' PixelSize.

Palette (index: hex). Index 0 is transparent. Nothing else is allowed.
     1 425A26  acid dark          5 9CADAF  glass shadow        8 523B2B  cork dark
     2 779539  acid mid           6 C3D0CE  glass               9 76543C  cork mid
     3 A9BF58  acid body          7 EEE5D2  glass glint        10 977253  cork light
     4 E2E5A9  acid pale         11 000000  ground shadow (strength from the Sprite3D's alpha)

Textures (cell size, columns x rows):
    flask.png   17 x 17, 8 x 1: frame k is the flask turned 45 * k degrees clockwise
    trail.png    4 x 4,  4 x 3: rows are three drop shapes, columns shrink them over life
    shadow.png  12 x 12, 6 x 1: ground discs 11 down to 6 texels across
"""

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "fx" / "flask_throw"

COLORS = {
    1: (0x42, 0x5A, 0x26, 255),
    2: (0x77, 0x95, 0x39, 255),
    3: (0xA9, 0xBF, 0x58, 255),
    4: (0xE2, 0xE5, 0xA9, 255),
    5: (0x9C, 0xAD, 0xAF, 255),
    6: (0xC3, 0xD0, 0xCE, 255),
    7: (0xEE, 0xE5, 0xD2, 255),
    8: (0x52, 0x3B, 0x2B, 255),
    9: (0x76, 0x54, 0x3C, 255),
    10: (0x97, 0x72, 0x53, 255),
    11: (0x00, 0x00, 0x00, 255),
}
ALLOWED = set(COLORS.values())

DARK, MID, BODY, PALE = 1, 2, 3, 4
GLASS_SHADOW, GLASS, GLINT = 5, 6, 7
CORK_DARK, CORK_MID, CORK_LIGHT = 8, 9, 10
SHADOW = 11

IMPORT_PARAMS = {
    "compress/mode": "0",
    "mipmaps/generate": "false",
    "process/fix_alpha_border": "true",
    "detect_3d/compress_to": "0",
}

# ---------------------------------------------------------------- flask model (texels, y up)

FLASK_CELL = 17  # one empty texel round the cork tip, so no cell reads its neighbour's edge
FLASK_FRAMES = 8

# The bulb, row by row from the top, columns x = -3 .. 3 around the cell centre. Glass on the
# upper-left rim (5) with one glint (7), the acid pale toward the light (4), body (3), mid (2)
# and dark on the lower-right rim (1), the pack flask's order. The rim was C3D0CE until r05; with
# the pale spot beside it the whole top left read as one white patch on a solid ball.
BULB = [
    "..553..",
    ".74333.",
    "5433332",
    "5333322",
    "3333221",
    ".32221.",
    "..111..",
]

# Neck and cork texels as (x, y) offsets from the bulb centre, y up, placed by hand for the flask
# pointing up and pointing up-right; the other six frames turn these by exact quarter turns on
# the grid. Rasterised at 45 degrees the cork came out as a three-texel hook. The neck is two
# texels wide and two long in glass, lit side C3D0CE and the other 9CADAF, and the cork sits on it,
# so bulb, neck and cork touch and read as three parts in every frame. With a one-texel neck two
# long (r01 to r05) the cork floated beside the bulb on the diagonals and the upside-down frame
# read as a lollipop; with a one-row collar (r06 to r08) the diagonal and cork-down frames read as
# an apple with a stalk (review 2).
STOPPER_UP = {
    "neck": [(-1, 4), (0, 4), (-1, 5), (0, 5)],
    "cork": [(-1, 6), (0, 6), (1, 6), (-1, 7), (0, 7), (1, 7)],
}
STOPPER_DIAGONAL = {
    "neck": [(2, 3), (3, 3), (3, 2), (3, 4), (4, 3)],
    # the texels within 1.5 of the axis and 1 of the cork's middle. With the far tip the r06 cork
    # read as a handle, as a plus without its side texels
    "cork": [(4, 5), (5, 4), (5, 5), (4, 6), (6, 4), (5, 6), (6, 5)],
}
CORK_MIDDLE = 6.6  # cork texels farther out along the axis than this are lit as its top
LIGHT = np.array([-1.0, 1.0]) / math.sqrt(2.0)  # top left of the screen, y up

NONE, NECK, CORK = 0, 1, 2


def rot(v, deg):
    """v turned clockwise on screen by deg degrees (y up)."""
    a = math.radians(-deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])


def quarter_turns(offset, k):
    """An (x, y) texel offset turned clockwise by k quarter turns, exactly on the grid."""
    x, y = offset
    for _ in range(k % 4):
        x, y = y, -x
    return x, y


def bulb_mask():
    n = FLASK_CELL
    half = n // 2
    idx = np.zeros((n, n), int)
    for r, line in enumerate(BULB):
        for c, ch in enumerate(line):
            if ch != ".":
                idx[half - 3 + r, half - 3 + c] = int(ch)
    return idx


def stopper_parts(k):
    """Neck and cork per texel for frame k, the flask pointing 45 * k degrees clockwise from up."""
    n = FLASK_CELL
    half = n // 2
    deg = 45.0 * k
    axis = rot(np.array([0.0, 1.0]), deg)
    side = rot(np.array([1.0, 0.0]), deg)
    stopper = STOPPER_UP if k % 2 == 0 else STOPPER_DIAGONAL
    parts = np.zeros((n, n), int)
    for name, part in (("neck", NECK), ("cork", CORK)):
        for offset in stopper[name]:
            x, y = quarter_turns(offset, k // 2)
            parts[half - y, half + x] = part
    return parts, axis, side


def shade_flask(k):
    n = FLASK_CELL
    half = n // 2
    idx = bulb_mask()
    parts, axis, side = stopper_parts(k)
    lit_side = 1.0 if float(np.dot(side, LIGHT)) >= 0.0 else -1.0
    for j in range(n):
        for i in range(n):
            part = parts[j, i]
            if part == NONE or idx[j, i] != 0:
                continue
            p = np.array([i - half, half - j], float)
            across = float(np.dot(p, side)) * lit_side
            if part == NECK:
                # the two-wide neck's middle is half a texel to the lit side, so the cut sits there
                idx[j, i] = GLASS_SHADOW if across < 0.3 else GLASS
            else:
                along = float(np.dot(p, axis))
                lift = across + (along - CORK_MIDDLE) * 0.8
                if lift > 0.5:
                    idx[j, i] = CORK_LIGHT
                elif lift < -0.5:
                    idx[j, i] = CORK_DARK
                else:
                    idx[j, i] = CORK_MID
    return idx


def draw_flask():
    return sheet([shade_flask(k) for k in range(FLASK_FRAMES)], FLASK_FRAMES)


# ---------------------------------------------------------------- trail drops

TRAIL_CELL = 4


def draw_trail():
    """Three drop shapes (rows), each shrinking over its 0.2 s life (columns)."""
    rows = [
        # a round drop: 2 x 2, 2 x 2, then 1 x 2 as it stretches, then a speck
        [["33", "21"], ["32", "11"], ["3", "1"], ["2"]],
        # a small drop: 1 x 2 to a speck
        [["3", "2"], ["3", "1"], ["2"], ["1"]],
        # a long drop: 1 x 3, tail first to go
        [["4", "3", "2"], ["3", "2", "1"], ["3", "1"], ["2"]],
    ]
    frames = []
    for row in rows:
        for shape in row:
            cell = np.zeros((TRAIL_CELL, TRAIL_CELL), int)
            h, w = len(shape), len(shape[0])
            y0 = (TRAIL_CELL - h) // 2
            x0 = (TRAIL_CELL - w) // 2
            for j, line in enumerate(shape):
                for i, ch in enumerate(line):
                    cell[y0 + j, x0 + i] = int(ch)
            frames.append(cell)
    return sheet(frames, 4)


# ---------------------------------------------------------------- ground shadow

# Larger than the flask on purpose: at 8 texels and alpha 0.55 it was an invisible smudge at 24 m,
# and the lob read as a slide (r01). The size carries the height, 11 texels at the floor to 6 at
# the apex, at an alpha that hardly changes (r06): at 6 texels and alpha 0.36 it vanished at the
# apex (r02), and at 7 texels it barely shrank.
SHADOW_CELL = 12
SHADOW_SIZES = (11, 10, 9, 8, 7, 6)


def draw_shadow():
    frames = []
    for d in SHADOW_SIZES:
        cell = np.zeros((SHADOW_CELL, SHADOW_CELL), int)
        c = SHADOW_CELL / 2.0 if d % 2 == 0 else SHADOW_CELL / 2.0 + 0.5
        r = d / 2.0
        for j in range(SHADOW_CELL):
            for i in range(SHADOW_CELL):
                if (i + 0.5 - c) ** 2 + (j + 0.5 - c) ** 2 <= r * r + 0.25:
                    cell[j, i] = SHADOW
        frames.append(cell)
    return sheet(frames, len(frames))


# ---------------------------------------------------------------- output

def sheet(frames, cols):
    ch, cw = frames[0].shape
    rows = (len(frames) + cols - 1) // cols
    out = np.zeros((rows * ch, cols * cw), int)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        out[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = f
    return out


def to_rgba(idx):
    rgba = np.zeros(idx.shape + (4,), np.uint8)
    for i, c in COLORS.items():
        rgba[idx == i] = c
    return Image.fromarray(rgba, "RGBA")


def check(path):
    """Every pixel is transparent or one of the palette entries, colour and alpha both."""
    im = np.array(Image.open(path).convert("RGBA"))
    bad = set()
    for px in im.reshape(-1, 4):
        t = tuple(int(v) for v in px)
        if t[3] == 0:
            continue
        if t not in ALLOWED:
            bad.add(t)
    return bad


def write_import(png):
    """Lossless, no mipmaps, no 3D compression; every other line Godot wrote is kept."""
    path = png.with_name(png.name + ".import")
    if not path.exists():
        lines = ["[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", ""]
        lines += [f"{k}={v}" for k, v in IMPORT_PARAMS.items()]
        path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        return
    lines = path.read_text(encoding="utf-8").splitlines()
    seen = set()
    in_params = False
    for i, line in enumerate(lines):
        if line.startswith("["):
            in_params = line == "[params]"
            continue
        key = line.split("=", 1)[0]
        if in_params and key in IMPORT_PARAMS:
            lines[i] = f"{key}={IMPORT_PARAMS[key]}"
            seen.add(key)
    lines += [f"{k}={v}" for k, v in IMPORT_PARAMS.items() if k not in seen]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def preview(img, path, scale, cell):
    bg = Image.new("RGBA", img.size, (38, 40, 44, 255))
    bg.alpha_composite(img)
    big = bg.resize((img.width * scale, img.height * scale), Image.NEAREST)
    px = big.load()
    cw, chh = cell
    for x in range(0, big.width, cw * scale):
        for y in range(big.height):
            px[x, y] = (90, 30, 30, 255)
    for y in range(0, big.height, chh * scale):
        for x in range(big.width):
            px[x, y] = (90, 30, 30, 255)
    big.save(path)


TEXTURES = {
    "flask": (draw_flask, (FLASK_CELL, FLASK_CELL)),
    "trail": (draw_trail, (TRAIL_CELL, TRAIL_CELL)),
    "shadow": (draw_shadow, (SHADOW_CELL, SHADOW_CELL)),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="folder for 12x previews with cell lines")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    failed = False
    for name, (fn, cell) in TEXTURES.items():
        img = to_rgba(fn())
        path = OUT / (name + ".png")
        img.save(path)
        write_import(path)
        bad = check(path)
        status = "OK" if not bad else "FAIL off-palette " + ", ".join("%02X%02X%02X@%d" % b for b in sorted(bad))
        print("%-7s %4dx%-4d %s" % (name, img.width, img.height, status))
        failed |= bool(bad)
        if args.preview:
            Path(args.preview).mkdir(parents=True, exist_ok=True)
            preview(img, Path(args.preview) / (name + ".png"), 12, cell)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
