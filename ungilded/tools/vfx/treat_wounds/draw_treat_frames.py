"""Draws the pixel-art frames of the Treat Wounds heal (res://scenes/fx/treat_wounds.tscn).

Treat Wounds is first aid: a linen roll touches the chest, the strip is wound round the torso
twice and knotted, a pinch of powder is dabbed on, and a few plain sparkles rise once it is done.
Every texture is a palette-index canvas drawn from shape rules, written as RGBA PNG, then read
back and checked against the palette. Any colour that is not on the list fails the run.

    python tools/vfx/treat_wounds/draw_treat_frames.py [--preview <dir>]

Palette (index: hex, alpha). Index 0 is transparent. Nothing else is allowed.
    1 F4F6DA   cream: linen highlight, powder, sparkle centre
    2 8CF28C   mint: sparkle arm tips (HealMotes tint 0.55, 0.95, 0.55)
    3 E6DCC6   linen: bandage body, roll
    4 BFAE90   linen shadow: underside, the turn at the sides, knot shade
    5 F4F6DA at alpha 128   powder edge
    6 E6DCC6 at alpha 128   powder edge
    7 8CF28C at alpha 128   small sparkle tips

Pixel size: one texel is 0.028 m at Body scale 1 (the build script sizes every quad as cell px x
0.028). The wraps are drawn on the unit sprites' own pixel grids, so their rows and columns are
sprite rows and columns.

Textures (cell, columns x rows, what the frames are):
    wrap.png      32x72, 17x1, hero wrap, 80 ms a frame over 1.36 s; cell column c is column
                  c + 16 of the hero sprite (rest_1.png, 64x72, feet on row 65)
    wrap_low.png  32x44, 17x1, rat wrap round the ribcage; cell column c is column c + 15 of the
                  rat sprite (rat_v1/idle_1.png, 62x44, feet on row 41)
    sparkle.png    7x7, 10x2, rows are plain cream and mint-tipped cream four-point sparkles;
                  columns are life frames, the first six empty
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "fx" / "treat_wounds"

COLORS = {
    1: (0xF4, 0xF6, 0xDA, 255),
    2: (0x8C, 0xF2, 0x8C, 255),
    3: (0xE6, 0xDC, 0xC6, 255),
    4: (0xBF, 0xAE, 0x90, 255),
    5: (0xF4, 0xF6, 0xDA, 128),
    6: (0xE6, 0xDC, 0xC6, 128),
    7: (0x8C, 0xF2, 0x8C, 128),
}
ALLOWED = set(COLORS.values())

CREAM, MINT, LINEN, SHADE = 1, 2, 3, 4
CREAM_H, LINEN_H, MINT_H = 5, 6, 7

FRAMES = 17  # 80 ms each: six application frames, two settling frames, then the held wrap


# ---------------------------------------------------------------- strips, rolls, knots

def put(idx, x, y, v):
    if 0 <= y < idx.shape[0] and 0 <= x < idx.shape[1]:
        idx[y, x] = v


def band(idx, x0, x1, top, sag, lo, hi, light, width=3, slope=0):
    """A whole pass from the body's edge x0 to its edge x1."""
    strip_band(idx, x0, x1, x0, x1, top, sag, lo, hi, light, width, slope)


def pass_top(x, full0, full1, top, slope):
    """Top row of a pass at column x: `top` at the edge full0, `slope` rows lower at full1 (the
    strip winds round the body as a spiral)."""
    return top + ((x - full0) * slope) // max(full1 - full0, 1)


def strip_band(idx, x_from, x_to, full0, full1, top, sag, lo, hi, light, width=3, slope=0):
    """The part of a pass from x_from to x_to laid so far, `width` rows, its top row from
    pass_top plus `sag` in the middle columns lo..hi (the strip bows over the chest until it is
    pulled taut). Where it reaches the body's edges full0 and full1 it turns round the body: two
    rows, shadow tone. `light` is the short run of columns that carries the highlight on the top
    row; the bottom row is the shadow, so two passes laid one under the other show a seam."""
    a, b = min(x_from, x_to), max(x_from, x_to)
    for x in range(a, b + 1):
        t = pass_top(x, full0, full1, top, slope) + (sag if lo <= x <= hi else 0)
        if x in (full0, full1):
            put(idx, x, t + 1, SHADE)
            put(idx, x, t + 2, SHADE)
            continue
        put(idx, x, t, CREAM if x in light else LINEN)
        for r in range(1, width - 1):
            put(idx, x, t + r, LINEN)
        put(idx, x, t + width - 1, SHADE)


ROLL = [  # 5 wide, 6 tall: a linen roll held upright against the body, its top end lit
    ".CCC.",
    "CLLLS",
    "LLLLS",
    "LLLLS",
    "LLLSS",
    ".SSS.",
]
ROLL_SMALL = [  # 3 wide, 4 tall, for the rat
    ".C.",
    "LLS",
    "LLS",
    ".S.",
]
GLYPH = {"C": CREAM, "L": LINEN, "S": SHADE}


def roll(idx, x, y, shape=ROLL, clip_left=None):
    """Draws a roll with its top-left at (x, y); columns left of clip_left are behind the body."""
    for r, line in enumerate(shape):
        for c, ch in enumerate(line):
            if ch == "." or (clip_left is not None and x + c < clip_left):
                continue
            put(idx, x + c, y + r, GLYPH[ch])


def glyphs(idx, x, y, rows):
    for r, line in enumerate(rows):
        for c, ch in enumerate(line):
            if ch in GLYPH:
                put(idx, x + c, y + r, GLYPH[ch])


def powder(idx, f, x, y, start):
    """A pinch of powder dabbed at (x, y) on frame `start`: a 6-texel cluster, then a thinner
    cloud, then three grains."""
    k = f - start
    if k == 0:
        for dx, dy in ((0, 0), (1, 0), (0, -1), (-1, 0), (0, 1), (1, -1)):
            put(idx, x + dx, y + dy, CREAM)
        put(idx, x - 1, y - 1, CREAM_H)
        put(idx, x + 2, y, CREAM_H)
    elif k == 1:
        for dx, dy in ((-3, 0), (3, 0), (-2, -1), (2, -2), (0, 2), (2, 1), (-2, 1), (-1, -2)):
            put(idx, x + dx, y + dy, CREAM_H)
        for dx, dy in ((-1, 1), (1, 1), (0, -2), (1, -1)):
            put(idx, x + dx, y + dy, LINEN_H)
        put(idx, x, y, CREAM)
        put(idx, x - 1, y, CREAM)
    elif k == 2:
        put(idx, x - 3, y - 1, CREAM_H)
        put(idx, x + 3, y + 1, LINEN_H)
        put(idx, x, y - 2, CREAM_H)


def flecks(idx, f, start, paths):
    """Specks falling from the powder: each path lists its (x, y) per frame from `start`."""
    k = f - start
    for path in paths:
        if 0 <= k < len(path):
            x, y = path[k]
            put(idx, x, y, CREAM if k == 0 else LINEN)


# ---------------------------------------------------------------- hero wrap

# Hero sprite columns 27 to 39 are the tunic between the left shoulder plate (to column 26) and
# the shield (from column 40); in cell columns that is 11 to 23. Rows 28 to 33 are the chest.
HERO_X0, HERO_X1 = 11, 23
HERO_SAG = (14, 20)  # middle columns that bow one row lower before the strip is pulled taut


HERO_TOP1, HERO_TOP2 = 27, 30  # the passes' top rows at the left edge
HERO_SLOPE = 2  # each pass runs two rows lower at the right edge: a spiral, not a flat plate


def hero_frame(f):
    """Frame 0: the roll arrives from the medic's side, outside the body. Then the application
    frames, the knot and the hold, one frame later than hero_apply counts them."""
    if f == 0:
        idx = np.zeros((72, 32), int)
        roll(idx, 26, 28)
        return idx
    return hero_apply(f - 1)


def hero_apply(f):
    idx = np.zeros((72, 32), int)
    x0, x1 = HERO_X0, HERO_X1
    lo, hi = HERO_SAG
    light1 = range(14, 18)
    light2 = range(16, 20)
    taut = f >= 5
    sag = 0 if taut else 1
    t1, t2, sl = HERO_TOP1, HERO_TOP2, HERO_SLOPE

    def roll_at(x, top):
        """The roll's top-left so that it sits on the strip's tip at column x."""
        return x, pass_top(x + 2, x0, x1, top, sl) - 1

    if f == 0:
        # contact: the roll's free end on the chest at the medic's side
        strip_band(idx, 22, 23, x0, x1, t1, 0, lo, hi, light1, slope=sl)
        roll(idx, *roll_at(20, t1))
    elif f == 1:
        # pulled across the front
        strip_band(idx, 16, 23, x0, x1, t1, sag, lo, hi, light1, slope=sl)
        roll(idx, *roll_at(13, t1))
    elif f == 2:
        # the turn at the far side: the roll goes behind the shoulder
        band(idx, x0, x1, t1, sag, lo, hi, light1, slope=sl)
        roll(idx, *roll_at(9, t1), clip_left=x0 + 1)
    elif f == 3:
        # the roll is behind the body; the first pass stays still
        band(idx, x0, x1, t1, sag, lo, hi, light1, slope=sl)
    elif f == 4:
        # second pass, laid under the first; the first pass's shadow row is the seam
        band(idx, x0, x1, t1, sag, lo, hi, light1, slope=sl)
        strip_band(idx, 17, 23, x0, x1, t2, sag, lo, hi, light2, slope=sl)
        roll(idx, *roll_at(14, t2))
    else:
        # pulled taut: the bow goes out of both passes; the knot from frame 6
        band(idx, x0, x1, t1, sag, lo, hi, light1, slope=sl)
        band(idx, x0, x1, t2, sag, lo, hi, light2, slope=sl)
        if f >= 6:
            glyphs(idx, 19, 30, ["SLLS", "LCLS", "SLL."])
            drop = 1 if f >= 7 else 0
            for r in range(33, 37 + drop):  # the long tail hangs over the belt
                put(idx, 20, r, LINEN if r < 36 + drop else SHADE)
            for r in range(33, 35 + drop):  # the short tail, its end tucked
                put(idx, 22, r, LINEN if r < 34 + drop else SHADE)

    # salve: powder on the tunic above the first pass, specks falling past the band
    powder(idx, f, 14, 25, 3)
    flecks(idx, f, 4, [[(12, 27), (12, 31), (11, 35)],
                       [(15, 27), (16, 31), (16, 35)],
                       [(17, 26), (18, 30)]])
    return idx


# ---------------------------------------------------------------- rat wrap

# Rat sprite columns 30 to 33 are the ribcage behind the forelegs; the back is on rows 24 to 26
# there and the belly on row 35. In cell columns (sprite - 15) that is 15 to 18.
def rat_pass(idx, x, top, bottom, lean_at):
    """A strip pass across the rat's body: down from the back (top) to the belly (bottom), three
    columns wide from x, leaning one column right below row lean_at; two columns at both ends."""
    for r in range(top, bottom + 1):
        cx = x + (1 if r >= lean_at else 0)
        end = r in (top, bottom)
        if end:
            put(idx, cx, r, LINEN if r == top else SHADE)
            put(idx, cx + 1, r, SHADE)
            continue
        put(idx, cx, r, CREAM if r <= top + 3 else LINEN)
        put(idx, cx + 1, r, LINEN)
        put(idx, cx + 2, r, SHADE)


def rat_frame(f):
    """Frame 0: the roll comes down toward the rat's back. Then rat_apply, one frame later."""
    if f == 0:
        idx = np.zeros((44, 32), int)
        roll(idx, 18, 17, ROLL_SMALL)
        return idx
    return rat_apply(f - 1)


def rat_apply(f):
    idx = np.zeros((44, 32), int)
    if f == 0:
        # contact on the back
        rat_pass(idx, 15, 24, 26, 30)
        roll(idx, 17, 21, ROLL_SMALL)
    elif f == 1:
        # down the near flank
        rat_pass(idx, 15, 24, 31, 30)
        roll(idx, 16, 30, ROLL_SMALL)
    elif f == 2:
        # under the belly: the roll leaves past the bottom of the body
        rat_pass(idx, 15, 24, 35, 30)
        for r, line in enumerate(ROLL_SMALL[:2]):
            for c, ch in enumerate(line):
                if ch != ".":
                    put(idx, 16 + c, 34 + r, GLYPH[ch])
    elif f == 3:
        rat_pass(idx, 15, 24, 35, 30)
    elif f == 4:
        # second pass laid beside the first; its shadow column against the first pass's lit
        # column is the seam
        rat_pass(idx, 15, 24, 35, 30)
        rat_pass(idx, 12, 25, 30, 29)
        roll(idx, 11, 29, ROLL_SMALL)
    else:
        rat_pass(idx, 15, 24, 35, 30)
        rat_pass(idx, 12, 25, 35, 29)
        if f >= 6:
            # knot on the back, off centre, one tail along the back and one tucked
            glyphs(idx, 16, 22, ["SLS", "LCL"])
            put(idx, 19, 24, LINEN)
            put(idx, 20, 25 if f >= 7 else 24, SHADE)
    powder(idx, f, 22, 28, 3)
    flecks(idx, f, 4, [[(21, 30), (21, 33)], [(23, 29), (24, 32)]])
    return idx


# ---------------------------------------------------------------- sparkles

SPARK_CELL = 7
SPARK_ORDER = ["empty"] * 6 + ["dot", "small", "big", "dot"]
SPARK_ROWS = [(CREAM, CREAM, CREAM_H), (CREAM, CREAM, MINT)]  # centre, arm, tip


def sparkle(kind, colours):
    n = SPARK_CELL
    c = n // 2
    idx = np.zeros((n, n), int)
    centre, arm, tip = colours
    if kind == "empty":
        return idx
    idx[c, c] = centre
    if kind in ("small", "big"):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            idx[c + dy, c + dx] = arm if kind == "big" else tip
    if kind == "big":
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            idx[c + dy, c + dx] = tip
    return idx


def draw_sparkle():
    rows = [np.concatenate([sparkle(k, colours) for k in SPARK_ORDER], axis=1) for colours in SPARK_ROWS]
    return np.concatenate(rows, axis=0)


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
    """Every pixel is fully transparent (0, 0, 0, 0) or one palette entry, colour and alpha both."""
    im = np.array(Image.open(path).convert("RGBA"))
    bad = set()
    for px in im.reshape(-1, 4):
        t = tuple(int(v) for v in px)
        if t == (0, 0, 0, 0):
            continue
        if t not in ALLOWED:
            bad.add(t)
    return bad


def preview(img, path, scale=6, cell=None, under=None):
    """Scaled preview with cell lines; `under` is a sprite drawn beneath every cell."""
    bg = Image.new("RGBA", img.size, (38, 40, 44, 255))
    if under is not None:
        cw, chh = cell
        for x in range(0, img.width, cw):
            bg.alpha_composite(under, (x, 0))
    bg.alpha_composite(img)
    big = bg.resize((img.width * scale, img.height * scale), Image.NEAREST)
    if cell:
        px = big.load()
        cw, chh = cell
        for x in range(0, big.width, cw * scale):
            for y in range(big.height):
                px[x, y] = (90, 30, 30, 255)
        for y in range(0, big.height, chh * scale):
            for x in range(big.width):
                px[x, y] = (90, 30, 30, 255)
    big.save(path)


def sprite_under(path, left, width):
    """The unit sprite cropped to the wrap's cell columns, for previews only."""
    im = Image.open(ROOT / path).convert("RGBA")
    return im.crop((left, 0, left + width, im.height))


TEXTURES = {
    "wrap": (lambda: sheet([hero_frame(f) for f in range(FRAMES)], FRAMES), (32, 72),
             ("assets/sprites/heroes/player/rest_1.png", 16)),
    "wrap_low": (lambda: sheet([rat_frame(f) for f in range(FRAMES)], FRAMES), (32, 44),
                 ("assets/sprites/enemies/rat_v1/idle_1.png", 15)),
    "sparkle": (draw_sparkle, (SPARK_CELL, SPARK_CELL), None),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="folder for scaled previews with cell lines and the sprite under the wraps")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    failed = False
    for name, (fn, cell, under) in TEXTURES.items():
        img = to_rgba(fn())
        path = OUT / (name + ".png")
        img.save(path)
        bad = check(path)
        status = "OK" if not bad else "FAIL off-palette " + ", ".join("%02X%02X%02X@%d" % b for b in sorted(bad))
        print("%-9s %4dx%-4d %s" % (name, img.width, img.height, status))
        failed |= bool(bad)
        if args.preview:
            Path(args.preview).mkdir(parents=True, exist_ok=True)
            scale = 4 if img.width * 4 <= 1900 else max(1, 1900 // img.width)
            sprite = sprite_under(under[0], under[1], cell[0]) if under else None
            preview(img, Path(args.preview) / (name + ".png"), scale, cell, sprite)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
