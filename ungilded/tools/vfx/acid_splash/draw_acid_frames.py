"""Draws the pixel-art frames of the acid splash (res://scenes/fx/acid_splash.tscn).

Every texture is a palette-index canvas drawn from shape rules (discs, tapered tongues, rings),
written as RGBA PNG, then read back and checked against the palette. Any colour that is not on
the list fails the run.

    python tools/vfx/acid_splash/draw_acid_frames.py [--preview <dir>]

Palette (index: hex, alpha). Index 0 is transparent. Nothing else is allowed.
    1 425A26   acid dark: outline, deepest shade
    2 779539   acid mid: shade
    3 A9BF58   acid body
    4 E2E5A9   acid pale: core, highlights
    5 EEE5D2   glass and flash white
    7 425A26 at alpha 128   dark halo behind the splat
(Index 6 and 8, the vapour colours, went with the vapour layer in r16.)

Pixel size: one texel is 0.028 m at FxScale 1 (the build script sizes every quad as cell px x 0.028).

Textures (cell size, columns x rows, what the rows are):
    splat.png     48x48, 6x3, 18 frames over 0.83 s, one particle (drawn by splat_frames.py)
    droplets.png   8x8,  4x4, rows are stretched drops in three sizes (head up), columns shorten
                 the tail to a single pixel
    glass.png      8x8,  4x4, rows are four shard shapes, columns are quarter-turn tumble frames
    bubbles.png   12x12, 10x3, rows are three bubble sizes: three empty lead cells, rise, swell,
                 pale cap, pop, residue
    puddles.png  128x128, 9x4, the whole floor: 36 frames of 40 ms, eight splats on the
                 neighbour tiles and four spatters, one particle, world aligned
    ring.png     112x112, 7x1, ground ring of spray, first frame empty
    flash.png     32x32, 4x1, impact flash (star, star, glass arcs, glints), additive
"""

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "fx" / "acid_splash"

COLORS = {
    1: (0x42, 0x5A, 0x26, 255),
    2: (0x77, 0x95, 0x39, 255),
    3: (0xA9, 0xBF, 0x58, 255),
    4: (0xE2, 0xE5, 0xA9, 255),
    5: (0xEE, 0xE5, 0xD2, 255),
    7: (0x42, 0x5A, 0x26, 128),
}
ALLOWED = set(COLORS.values())

DARK, MID, BODY, PALE, GLASS, HALO = 1, 2, 3, 4, 5, 7


# ---------------------------------------------------------------- shape masks

def centres(w, h):
    ys, xs = np.mgrid[0:h, 0:w]
    return xs + 0.5, ys + 0.5


def disc(w, h, cx, cy, r):
    x, y = centres(w, h)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def ellipse(w, h, cx, cy, rx, ry):
    x, y = centres(w, h)
    return ((x - cx) / max(rx, 1e-3)) ** 2 + ((y - cy) / max(ry, 1e-3)) ** 2 <= 1.0


def capsule(w, h, x0, y0, x1, y1, r0, r1):
    """Segment from (x0, y0) to (x1, y1) whose radius runs from r0 to r1."""
    x, y = centres(w, h)
    dx, dy = x1 - x0, y1 - y0
    l2 = max(dx * dx + dy * dy, 1e-6)
    t = np.clip(((x - x0) * dx + (y - y0) * dy) / l2, 0.0, 1.0)
    px, py = x0 + t * dx, y0 + t * dy
    r = r0 + (r1 - r0) * t
    return (x - px) ** 2 + (y - py) ** 2 <= r * r


def polyline(w, h, pts, radii):
    m = np.zeros((h, w), bool)
    for i in range(len(pts) - 1):
        m |= capsule(w, h, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], radii[i], radii[i + 1])
    return m


def ring(w, h, cx, cy, r, width):
    x, y = centres(w, h)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    return (d >= r - width * 0.5) & (d <= r + width * 0.5)


def angle_mask(w, h, cx, cy, count, duty, phase):
    """Keeps `duty` of each of `count` equal angular sectors: dashes on a ring."""
    x, y = centres(w, h)
    a = (np.arctan2(y - cy, x - cx) / (2.0 * math.pi) + 1.0 + phase) % 1.0
    return ((a * count) % 1.0) < duty


def inside(w, h, margin):
    """Pixels at least `margin` from every edge, so outlines never touch the cell border."""
    x, y = centres(w, h)
    return (x > margin) & (x < w - margin) & (y > margin) & (y < h - margin)


def angle_window(w, h, cx, cy, a0, a1):
    """Pixels whose direction from (cx, cy) lies between a0 and a1 degrees (0 right, 90 up)."""
    x, y = centres(w, h)
    a = (np.degrees(np.arctan2(-(y - cy), x - cx)) + 360.0) % 360.0
    lo, hi = a0 % 360.0, a1 % 360.0
    return (a >= lo) & (a <= hi) if lo <= hi else (a >= lo) | (a <= hi)


def nb(m, dx, dy):
    """m sampled at (x + dx, y + dy); outside the canvas is empty."""
    h, w = m.shape
    p = np.pad(m, 4, constant_values=False)
    return p[4 + dy:4 + dy + h, 4 + dx:4 + dx + w]


def outline(m):
    """Empty pixels that touch m on a side (4-neighbour outline)."""
    return ~m & (nb(m, 1, 0) | nb(m, -1, 0) | nb(m, 0, 1) | nb(m, 0, -1))


def lerp_keys(keys, t):
    """keys: [(t, value), ...] ascending; holds the end values outside the range."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return keys[-1][1]


def clamp01(v):
    return max(0.0, min(1.0, v))


# ---------------------------------------------------------------- shading

def shade_puddle(idx, m, body, edge, spec=None, rim=DARK):
    """A flat pool seen from above: body, a one-pixel inner edge band, dark outline."""
    idx[m] = body
    inner = m & (~nb(m, 1, 0) | ~nb(m, -1, 0) | ~nb(m, 0, 1) | ~nb(m, 0, -1))
    idx[inner] = edge
    if spec is not None:
        idx[spec & m & ~inner] = PALE
    if rim:
        idx[outline(m) & (idx == 0)] = rim
    return idx


def shade_floor_splat(idx, m, body, shadow, spec=None):
    """A wet splat on the floor seen from above: body, a shadow side away from the light (bottom
    right), an optional pale glint, and the dark outline."""
    idx[m] = body
    side = m & (~nb(m, 1, 1) | ~nb(m, 0, 1) | ~nb(m, 1, 0))
    idx[side] = shadow
    if spec is not None:
        idx[spec & m & ~side] = PALE
    idx[outline(m) & (idx == 0)] = DARK
    return idx


# ---------------------------------------------------------------- splat (48x48, 18 frames)

def draw_splat():
    """The body splat lives in splat_frames.py; it takes this module for the shape helpers."""
    import splat_frames
    return splat_frames.draw(sys.modules[__name__])


# ---------------------------------------------------------------- droplets (8x8, 4 sizes x 4 frames)

# Teardrops, head at the top of the cell: the emitter aligns the quad's +Y (the texture's top) with
# the velocity, so the bead leads and the tail trails. Four different shapes, not one shape scaled;
# each is (head rows, tail rows). Life frames drop tail rows: [full, full, one less, two less].
# Stretched drops, thin and long along the velocity: a head 1 to 3 px wide and a 1 px tail of 3 to
# 5 px, lit edge on the left, mid on the right, dark only under the largest head. Three sizes,
# with the large one in two rows so it shows most. Life frames shorten the tail and the last
# frame is a single pixel, so a drop is spent before it can reach the floor at full size.
DROPS = [
    ([".3.",
      "343",
      "332",
      ".21"],
     [".2.",
      ".2.",
      ".2.",
      ".1."]),
    ([".3.",
      "343",
      "332",
      ".2."],
     [".2.",
      ".2.",
      "..2",
      "..1"]),
    (["34",
      "32"],
     ["2.",
      "2.",
      "2."]),
    (["3",
      "2"],
     ["2",
      "2"]),
]
DROP_TAIL_CUT = [0, 1, 2, 9]


def stamp(cell, rows):
    """Paste a palette-index art block in the centre of a cell."""
    idx = np.zeros((cell, cell), int)
    h, w = len(rows), len(rows[0])
    oy, ox = (cell - h) // 2, (cell - w) // 2
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                idx[oy + y, ox + x] = int(ch)
    return idx


def draw_droplets():
    frames = []
    for head, tail in DROPS:
        for cut in DROP_TAIL_CUT:
            idx = np.zeros((8, 8), int)
            if cut >= 9:
                # spent: one mid pixel where the head was
                idx[1, 3] = MID
                frames.append(idx)
                continue
            rows = head + tail[:max(0, len(tail) - cut)]
            ox = (8 - len(rows[0])) // 2
            # the head stays on the same rows in every frame; only the tail shortens
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch != "." and 0 <= y < 8:
                        idx[y, ox + x] = int(ch)
            frames.append(idx)
    return sheet(frames, 4)


# ---------------------------------------------------------------- glass shards (8x8, 4 shapes x 4 tumble frames)

# four different flask shards, each with an acid-wet edge (3, 2) so they are not flat white
# triangles (those read as UI corner brackets); each row tumbles through four quarter turns
SHARDS = [
    ["5...", "54..", "443.", ".32."],
    [".55.", "5442", ".42."],
    ["55", "43", "3."],
    ["5.", "54", "4.", "32"],
]


def quarter_turns(rows, k):
    a = np.array([list(r) for r in rows])
    return ["".join(r) for r in np.rot90(a, k)]


def draw_glass():
    frames = [stamp(8, quarter_turns(base, k)) for base in SHARDS for k in range(4)]
    return sheet(frames, 4)


# ---------------------------------------------------------------- bubbles (12x12, 3 sizes x 10 frames)

# Boil and pop on the wet acid: a mid dome rises out of the surface, swells, its pale cap catches
# the light for one frame, it pops into four drops, and a small dark residue is left. Three
# sizes (3, 5, 7 px). Filled, never a hollow ring (two rings side by side read as goggles) and
# never a 3x3 "+" (it reads as a magic sparkle).
BUBBLES = [
    [
        ["2"],
        [".2.", "232"],
        [".3.", "333", "232"],
        [".4.", "343", "232"],
        ["3.3", "...", "3.3"],
        ["1"],
        ["."],
    ],
    [
        [".22.", "2332"],
        [".33.", "3333", "2332"],
        [".333.", "33333", "33332", ".222."],
        [".343.", "34433", "33332", ".222."],
        ["3...3", ".....", ".....", ".....", "3...3"],
        [".1.", "121", ".1."],
        ["1"],
    ],
    [
        [".222.", "23332"],
        [".333.", "33333", "23332"],
        ["..333..", ".33333.", "3333332", "3333322", ".22222."],
        ["..343..", ".34443.", "3344332", "3333322", ".22222."],
        ["3.....3", ".......", ".......", ".......", ".......", ".......", "3.....3"],
        [".11.", "1221", ".11."],
        [".1.", "1.1"],
    ],
]


# Three empty cells lead each row: every bubble waits about 0.2 s after it spawns, so the sizzle
# starts on the runs and stains once the crown has broken, not on top of the crown. The build
# script adds a random start offset of up to two of these cells, so the bubbles do not swell in step.
BUBBLE_LEAD = 3
BUBBLE_CELL = 12


def draw_bubbles():
    frames = []
    for row in BUBBLES:
        frames += [np.zeros((BUBBLE_CELL, BUBBLE_CELL), int)] * BUBBLE_LEAD
        frames += [stamp(BUBBLE_CELL, f) for f in row]
    return sheet(frames, BUBBLE_LEAD + 7)


# ---------------------------------------------------------------- puddles (32x32, 4 layouts x 10 frames)

PUDDLE = 40  # cell for one spatter: the streak reaches 17 px from the centre
PUDDLE_FRAMES = 10


def puddle_layout(seed, s=1.0, out=0.0):
    """One torn floor spatter's persistent features: an irregular mass of 3 to 5 metaball lumps
    stretched along `out` (radians, the direction the acid flew, away from the target) with a
    strongly noised, open edge; a streak thrown on from the mass along `out`, ending in a bead;
    2 to 4 satellite drops, most on the far side; 1 or 2 holes that open as it soaks. s scales sizes."""
    rng = np.random.default_rng(seed)
    ux, uy = math.cos(out), math.sin(out)
    lumps = [(0.0, 0.0, 4.8 * s)]
    for _ in range(int(rng.integers(2, 4))):
        along = rng.uniform(-2.0, 4.5) * s
        side = rng.uniform(-3.5, 3.5) * s
        lumps.append((ux * along - uy * side, uy * along + ux * side, rng.uniform(2.4, 3.8) * s))
    # arms, as r21's floor: 4 to 6 of unequal length radiating from the mass, most of them thrown
    # on along `out`; the longest is the streak away from the target; about half end in a bead
    arms = []
    n = int(rng.integers(4, 7))
    for i in range(n):
        a = out + (rng.uniform(-0.3, 0.3) if i == 0 else rng.normal(0.0, 1.3))
        ln = (rng.uniform(13.0, 16.0) if i == 0 else rng.uniform(6.0, 11.0)) * s
        arms.append((math.cos(a), math.sin(a), ln, (1.9 if i == 0 else rng.uniform(1.1, 1.6)) * s, i == 0 or rng.random() < 0.4))
    sats = []
    for _ in range(int(rng.integers(4, 8))):
        a = out + rng.normal(0.0, 1.2)
        d = rng.uniform(8.0, 16.0) * s
        sats.append((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.6, 1.4) * s))
    noise = rng.random((6, 6))
    return lumps, arms, sats, [], noise


def puddle_frame(layout, k):
    """k = 0 empty, 1 landing (body green, a shadow side, a broken dark edge), 2 to 6 soaking and
    shrinking (mid green, a dark band on the lower-right side, holes opening), 7 to 9 drying to a
    few dark specks. No drawn highlight: the lit material's glint is the only one."""
    w = h = PUDDLE
    cx, cy = w / 2.0, h / 2.0
    idx = np.zeros((h, w), int)
    if k == 0:
        return idx
    lumps, arms, sats, _unused, noise = layout
    grow = {1: 0.85, 2: 1.0, 3: 1.0, 4: 0.9, 5: 0.8, 6: 0.68, 7: 0.55, 8: 0.42, 9: 0.3}[k]
    x, y = centres(w, h)
    f = np.zeros((h, w))
    for ox, oy, r in lumps:
        rr = r * grow
        q = ((x - cx - ox * grow) ** 2 + (y - cy - oy * grow) ** 2) / (2.0 * rr) ** 2
        f += np.where(q < 1.0, (1.0 - q) ** 3, 0.0)
    gx = np.clip((x / w) * 5.0, 0.0, 4.999)
    gy = np.clip((y / h) * 5.0, 0.0, 4.999)
    x0, y0 = gx.astype(int), gy.astype(int)
    fx, fy = gx - x0, gy - y0
    nz = (noise[y0, x0] * (1 - fx) + noise[y0, x0 + 1] * fx) * (1 - fy) + (noise[y0 + 1, x0] * (1 - fx) + noise[y0 + 1, x0 + 1] * fx) * fy
    # a strong noise share on the iso level tears the edge open (0.25 left smooth ovals)
    m = f >= 0.42 + 0.5 * (nz - 0.5)
    if k <= 6:
        reach = {1: 0.8, 2: 1.0, 3: 1.0, 4: 0.92, 5: 0.82, 6: 0.7}[k]
        for ux, uy, ln, rr, bead in arms:
            tip = ln * reach
            m |= capsule(w, h, cx, cy, cx + ux * tip, cy + uy * tip, rr * min(1.0, grow + 0.15), 0.5)
            if bead:
                m |= disc(w, h, round(cx + ux * (tip + 1.5)), round(cy + uy * (tip + 1.5)), max(0.7, 1.2 * grow))
    if k <= 5:
        for dx, dy, dr in sats:
            m |= disc(w, h, round(cx + dx), round(cy + dy), max(0.7, dr * (1.0 if k <= 3 else 0.7)))
    if k >= 7:
        # drying: the mass breaks into its two or three thickest spots plus one satellite
        m &= f >= 0.42 + {7: 0.35, 8: 0.6, 9: 0.85}[k]
        dx, dy, _ = sats[0]
        m |= disc(w, h, round(cx + dx * 0.9), round(cy + dy * 0.9), 0.9) if k == 7 else np.zeros((h, w), bool)
    m &= inside(w, h, 1)
    side = m & (~nb(m, 1, 0) | ~nb(m, 0, 1) | ~nb(m, 1, 1))
    if k == 1:
        idx[m] = BODY
        idx[side] = MID
        edge = outline(m) & (nb(m, -1, 0) | nb(m, 0, -1)) & (noise[y0, x0] > 0.35)
        idx[edge & inside(w, h, 0)] = DARK
    else:
        idx[m] = MID if k <= 6 else DARK
        idx[side] = DARK
    return idx


# The floor: one world-aligned 128 px ground flipbook (3.58 m) centred on the target's tile.
# Eight principal splats sit on the eight neighbour tile centres (1 m apart, up to 4 px = 0.11 m
# off centre) and four smaller spatters between them, so every square the rule splashes gets acid
# at 24 m (twelve randomly placed puddles bunched on one side). Landings are staggered.
FLOOR = 128
FLOOR_STEP_MS = 40.0
FLOOR_FRAMES = 36  # 1.44 s
TILE_PX = 1.0 / 0.028
# (tile x, tile z, landing ms, seed); the near and far sides alternate so neither lands first
FLOOR_SPLATS = [
    (1, 0, 130, 3), (-1, 0, 160, 11), (0, 1, 150, 23), (0, -1, 190, 37),
    (1, 1, 220, 5), (-1, -1, 250, 17), (1, -1, 280, 29), (-1, 1, 330, 41),
]
# (angle degrees, distance in tiles, landing ms, seed): smaller connecting spatters
FLOOR_SPATTERS = [(25, 0.7, 170, 7), (115, 0.75, 210, 13), (205, 0.7, 240, 19), (300, 0.72, 270, 31)]


def floor_k(e):
    """Puddle frame index for e ms after landing: a bright landing for 100 ms, the soak by 220 ms,
    then one frame every 130 ms, drying to specks and gone after 1.1 s."""
    if e < 0:
        return 0
    if e < 100:
        return 1
    if e < 220:
        return 2
    k = 3 + int((e - 220) // 130)
    return k if k <= 9 else 0


def stamp_at(canvas, frame, cx, cy):
    h, w = frame.shape
    x0, y0 = int(round(cx - w / 2.0)), int(round(cy - h / 2.0))
    sub = canvas[y0:y0 + h, x0:x0 + w]
    sub[frame > 0] = frame[frame > 0]


def draw_puddles():
    rng = np.random.default_rng(101)
    c = FLOOR / 2.0
    splats = []
    for a, d, t_land, seed in FLOOR_SPATTERS:
        ar = math.radians(a)
        splats.append((c + math.cos(ar) * d * TILE_PX, c + math.sin(ar) * d * TILE_PX, t_land, puddle_layout(seed, 0.55, ar)))
    for tx, tz, t_land, seed in FLOOR_SPLATS:
        # off the tile centre by up to 6 px (0.17 m) and sizes varied, so the eight read as
        # thrown acid on eight squares rather than a ring of equal dots
        jx, jy = rng.uniform(-6.0, 6.0, 2)
        s = rng.uniform(0.75, 1.15)
        splats.append((c + tx * TILE_PX + jx, c + tz * TILE_PX + jy, t_land, puddle_layout(seed, s, math.atan2(tz, tx))))
    frames = []
    for f in range(FLOOR_FRAMES):
        t = f * FLOOR_STEP_MS
        idx = np.zeros((FLOOR, FLOOR), int)
        for x, y, t_land, layout in splats:
            k = floor_k(t - t_land)
            if k:
                stamp_at(idx, puddle_frame(layout, k), x, y)
        frames.append(idx)
    return sheet(frames, 9)


# ---------------------------------------------------------------- ground ring (112x112, 7 frames)

RING = 112
# A ragged ring of spray clumps racing out to the edge of the splash reach (53 px = 1.48 m, past
# the diagonal neighbours at 1.41 m). A clean even ring read as a unit selection ring.
# Ring radius per frame (px); None is the empty first frame.
RING_R = [None, 14.0, 26.0, 36.0, 43.0, 48.0, 51.0]
RING_CLUMPS = 22


def draw_ring():
    frames = []
    w = h = RING
    cx, cy = w / 2.0, h / 2.0
    rng = np.random.default_rng(7)
    # evenly spaced with jitter: random angles bunched the clumps and left gaps
    angles = (np.arange(RING_CLUMPS) + rng.uniform(-0.3, 0.3, RING_CLUMPS)) * 2.0 * math.pi / RING_CLUMPS
    jitter = rng.uniform(-1.0, 1.0, RING_CLUMPS)
    sizes = rng.uniform(1.6, 2.8, RING_CLUMPS)
    x, y = centres(w, h)
    theta = np.arctan2(y - cy, x - cx)
    dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    for k, big_r in enumerate(RING_R):
        idx = np.zeros((h, w), int)
        if big_r is None:
            frames.append(idx)
            continue
        m = np.zeros((h, w), bool)
        if k <= 2:
            # early on the spray is a lopsided, broken band: the radius swings 15 percent round
            # the ring and three gaps open in it (an even glowing ellipse read as a magic shockwave)
            rad = big_r * (1.0 + 0.15 * np.sin(3.0 * theta + 1.1) + 0.06 * np.sin(7.0 * theta + 0.4 * k))
            band = 2.6 + 1.0 * np.sin(7.0 * theta + 1.3)
            gaps = np.sin(3.0 * theta + 2.4 + 0.5 * k) > 0.75
            m |= (np.abs(dist - rad) <= band * 0.5) & ~gaps
        for i in range(RING_CLUMPS):
            rr = big_r + jitter[i] * (1.2 + 0.2 * k)
            s = sizes[i] * (1.05 - 0.09 * k)
            px, py = cx + math.cos(angles[i]) * rr, cy + math.sin(angles[i]) * rr
            m |= disc(w, h, px, py, max(1.1, s))
            if 3 <= k <= 5:
                # spray thrown on ahead of the clump: a 2x2 drop on pixel corners (a radius-1 disc
                # on a pixel centre draws a "+", which reads as a sparkle)
                ox = round(cx + math.cos(angles[i] + 0.04) * (rr + s + 2.5))
                oy = round(cy + math.sin(angles[i] + 0.04) * (rr + s + 2.5))
                m |= disc(w, h, ox, oy, 1.0)
        # no pale inner line: the glowing line is what read as magic
        shade_floor_splat(idx, m, BODY if k <= 4 else MID, MID)
        frames.append(idx)
    return sheet(frames, 7)


# ---------------------------------------------------------------- flash (32x32, 4 frames)

def draw_flash():
    w = h = 32
    cx, cy = w / 2.0, h / 2.0
    frames = []
    # 0: a 1 px cross, white only at its 2 px centre and inner arms, pale then acid green outward,
    # with short green diagonals. Only the white passes the glow threshold, so the bloom stays a
    # tight green-white star (a cream core bloomed into a 2 m halo)
    idx = np.zeros((h, w), int)
    ci, cj = int(cy), int(cx)
    for d in range(1, 15):
        tone = GLASS if d <= 3 else (PALE if d <= 9 else BODY)
        for oy, ox in ((0, d), (0, -d), (d, 0), (-d, 0)):
            idx[ci + oy, cj + ox] = tone
    for d in range(2, 7):
        tone = PALE if d <= 3 else BODY
        for oy, ox in ((d, d), (d, -d), (-d, d), (-d, -d)):
            idx[ci + oy, cj + ox] = tone
    idx[ci - 1:ci + 1, cj - 1:cj + 1] = GLASS
    idx[ci, cj] = GLASS
    # held for two cells so the star is on screen for about four game frames
    frames.append(idx)
    frames.append(idx.copy())
    # 2: the ring broken into glass arcs flying off the crown, no centre (a closed ring round a
    # pale disc read as an orb)
    idx = np.zeros((h, w), int)
    for k in range(5):
        a0 = k * 72.0 + 10.0
        arc = ring(w, h, cx, cy, 10.0 + (k % 2), 1.2) & angle_window(w, h, cx, cy, a0, a0 + 34.0)
        idx[arc] = GLASS if k % 2 == 0 else PALE
    for k in range(6):
        a = math.radians(k * 60.0 + 35.0)
        sx, sy = int(cx + math.cos(a) * 13.5), int(cy - math.sin(a) * 13.5)
        idx[sy, sx:sx + 2] = PALE
    frames.append(idx)
    # 3: four fading glass glints, 2x2 (plus-shaped sparkles read as magic, not glass)
    idx = np.zeros((h, w), int)
    for k in range(4):
        a = math.radians(k * 90.0 + 20.0)
        sx, sy = int(cx + math.cos(a) * 11.0), int(cy - math.sin(a) * 11.0)
        idx[sy:sy + 2, sx:sx + 2] = PALE
        idx[sy, sx] = GLASS
    frames.append(idx)
    return sheet(frames, 4)


# ---------------------------------------------------------------- output and checks

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


def preview(img, path, scale=6, cell=None):
    bg = Image.new("RGBA", img.size, (38, 40, 44, 255))
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


TEXTURES = {
    "splat": (draw_splat, (48, 48)),
    "droplets": (draw_droplets, (8, 8)),
    "glass": (draw_glass, (8, 8)),
    "bubbles": (draw_bubbles, (12, 12)),
    "puddles": (draw_puddles, (128, 128)),
    "ring": (draw_ring, (112, 112)),
    "flash": (draw_flash, (32, 32)),
}

# Lit layers get a normal page per cell, written by the project's tools/art/sprite_normals.py
# (bevel from the alpha edge plus a share of luma, Sobel, green up) with its import settings.
# The bevel is short because the liquid is thin. Normal pages are not palette art.
NORMAL_PAGES = {"splat": (3, 2.0, 1.2), "puddles": (3, 1.5, 1.0)}


def write_normal_page(name, img, cell):
    sys.path.insert(0, str(ROOT / "tools" / "art"))
    import sprite_normals
    rgba = np.array(img)
    out = np.empty_like(rgba)
    cw, ch = cell
    bevel, depth, luma = NORMAL_PAGES[name]
    for y in range(0, rgba.shape[0], ch):
        for x in range(0, rgba.shape[1], cw):
            out[y:y + ch, x:x + cw] = sprite_normals.normal_page(rgba[y:y + ch, x:x + cw], bevel, depth, luma)
    page = OUT / (name + "_n.png")
    Image.fromarray(out, "RGBA").save(page)
    sprite_normals.write_import(page)
    errors = sprite_normals.check(OUT / (name + ".png"))
    print("%-9s normal page %s" % (name, "OK" if not errors else "FAIL " + "; ".join(errors)))
    return bool(errors)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="folder for 6x previews with cell lines")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    failed = False
    for name, (fn, cell) in TEXTURES.items():
        img = to_rgba(fn())
        path = OUT / (name + ".png")
        img.save(path)
        bad = check(path)
        status = "OK" if not bad else "FAIL off-palette " + ", ".join("%02X%02X%02X@%d" % b for b in sorted(bad))
        print("%-9s %4dx%-4d %s" % (name, img.width, img.height, status))
        failed |= bool(bad)
        if name in NORMAL_PAGES:
            failed |= write_normal_page(name, img, cell)
        if args.preview:
            Path(args.preview).mkdir(parents=True, exist_ok=True)
            scale = 6 if img.width * 6 <= 1900 else max(1, 1900 // img.width)
            preview(img, Path(args.preview) / (name + ".png"), scale, cell)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
