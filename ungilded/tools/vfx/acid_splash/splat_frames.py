"""The body splat of the acid splash: 18 frames of 48 x 48 px, 46 ms a frame (0 to 0.83 s).

One persistent set of liquid features is tracked through every frame: the sheet (metaball lumps
on a persistent low-frequency noise), six tendrils of unequal length and job with one empty
sector, a fold, a tear, channels cut up from the bottom edge, three unequal runs, and stains. The
shape deforms, tears and drains; it never just scales. Rules from Astra review 3 (NOTES.md):
tendrils taper 3, 2, 1 px to clipped tips; a dark edge only on part of the lower-right perimeter,
never a closed contour; values from offset bent regions, not rings round the centre; detached
drops leave the billboard (the Droplets particles carry them).

Area schedule (share of the 138 ms peak): 35 to 45 percent at 322 ms, 15 to 25 at 368 ms, 5 to 10
at 506 ms, a few stains at 736 ms, empty by 782 ms. Called by draw_acid_frames.py, which passes
itself as `d` for the shape helpers and the palette.
"""
import math

import numpy as np

W = H = 48
FRAMES = 18
FRAME_MS = 46.0
FX, FY = 24.0, 22.0   # footprint centre
SX, SY = 26.5, 23.0   # sheet centre, 2.5 px right of and 1 px below the footprint centre
T_ISO = 0.42          # metaball iso level: a lone lump draws at its own radius
NOISE_SHARE = 0.28    # how far the persistent noise moves the iso level
TALL = 1.4            # vertical spread of the lumps: the sheet is 16 to 18 px tall at its peak
G = 0.00035           # 9.8 m/s^2 in px per ms^2 at 0.028 m a texel

# sheet lumps: offset x, offset y (px at full spread), radius (px), drain rate (above 1 drains
# sooner: the centre goes first, so the chest clears before the sides)
LUMPS = [(-5.5, -1.0, 4.6, 0.9), (2.5, -3.0, 4.2, 1.15), (7.0, 1.5, 3.2, 1.0), (-1.0, 3.0, 4.0, 1.3),
         (-9.0, 1.5, 2.4, 0.85), (3.0, 1.5, 3.4, 1.25), (-3.5, -4.0, 2.6, 1.05)]
SPREAD = [(0, 0.45), (46, 0.8), (92, 0.98), (138, 1.05), (230, 1.1), (322, 1.12)]
# lump size: the sheet thins as the tendrils grow, then drains
# the coat lingers to 0.6 s as torn smears for the runs to hang from (it was gone by 0.55 s)
SIZE = [(0, 0.55), (46, 0.9), (92, 1.0), (138, 0.96), (184, 0.9), (230, 0.84), (276, 0.78),
        (322, 0.68), (368, 0.54), (414, 0.44), (460, 0.34), (506, 0.24), (552, 0.15), (598, 0.06), (644, 0.0)]
# draining lumps flatten into smears the runs hang from (round remnants read as heads)
SQUASH_X = [(0, 1.0), (184, 1.0), (276, 1.15), (368, 1.3)]
SQUASH_Y = [(0, 1.0), (184, 1.0), (276, 0.85), (368, 0.6), (414, 0.45), (460, 0.4)]
SAG = [(0, 0.0), (138, 0.0), (230, 1.2), (322, 2.6), (414, 3.6), (506, 4.2)]

# tendrils: angle (deg, 0 right, 90 up), length (px), root thickness (px), bend, break ms (None:
# folds back), beaded, one-sided narrowing (-1, 0, 1). Two long, three medium, one shoulder; the
# lower left is left empty.
TENDRILS = [
    (68.0, 11.0, 3, 0.42, 185, False, 1),
    (166.0, 10.0, 3, -0.18, 210, True, -1),
    (18.0, 6.0, 2, 0.30, 235, False, 0),
    (118.0, 5.0, 2, -0.14, None, False, 1),
    (-38.0, 5.5, 2, 0.12, None, False, 0),
    (140.0, 2.5, 2, 0.0, None, False, 0),
]
# channels cut up from the bottom edge: x offset, width (px), start ms, depth (px)
CHANNELS = [(-3.0, 2.0, 200, 6.0), (2.5, 3.0, 230, 8.0), (-8.0, 2.0, 260, 4.0), (6.5, 5.0, 250, 5.0)]
# runs: x offset, root y offset, root thickness px, length px, start ms, bead, bead leaves ms, lean px
# runs down the target from 0.23 s: x offset, root y offset, root thickness px, length px,
# start ms, the times beads leave the tip (ms), lean px. Unequal on purpose; at 24 m the thin
# r22 runs did not show, so these reach the belt (16 px at 0.02 m a texel is about 0.3 m).
RUNS = [(-6.0, 2.5, 4, 16.0, 230, (390, 500), -2.0), (2.5, 4.5, 3, 11.0, 260, (450,), 1.5),
        (7.5, 1.5, 2, 6.0, 300, (), 1.0)]
# stains that cling after the sheet has drained: offset x, offset y, radius, gone at ms
STAINS = [(-6.0, 1.5, 1.4, 700), (4.5, -1.5, 1.1, 600), (-1.5, 6.0, 1.0, 760), (7.0, 2.5, 0.9, 560)]
# where the short pale highlight marks sit on upper-left lips (offsets at full spread)
HIGHLIGHTS = [(-6.0, -3.5), (2.5, -5.0), (7.5, -0.5)]

_NOISE = np.random.default_rng(23).random((7, 7))


def noise_at(u, v):
    """Smooth noise in 0..1 on sheet coordinates (about -1..1), so its features move with the sheet."""
    gx = np.clip((u + 1.2) / 2.4 * 6.0, 0.0, 5.999)
    gy = np.clip((v + 1.2) / 2.4 * 6.0, 0.0, 5.999)
    x0, y0 = gx.astype(int), gy.astype(int)
    fx, fy = gx - x0, gy - y0
    n = _NOISE
    a = n[y0, x0] * (1 - fx) + n[y0, x0 + 1] * fx
    b = n[y0 + 1, x0] * (1 - fx) + n[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def ease_out(d, u):
    return 1.0 - (1.0 - d.clamp01(u)) ** 2.6


def sheet_field(d, t):
    x, y = d.centres(W, H)
    f = np.zeros((H, W))
    sp, sz, sag = d.lerp_keys(SPREAD, t), d.lerp_keys(SIZE, t), d.lerp_keys(SAG, t)
    for ox, oy, r, drain in LUMPS:
        rr = r * (d.lerp_keys(SIZE, 138.0 + (t - 138.0) * drain) if t > 138.0 else sz)
        if rr < 0.6:
            continue
        bx, by = SX + ox * sp, SY + oy * sp * TALL + sag * (1.0 + 0.15 * oy)
        rx, ry = rr * d.lerp_keys(SQUASH_X, t), rr * d.lerp_keys(SQUASH_Y, t)
        q = ((x - bx) / (2.0 * rx)) ** 2 + ((y - by) / (2.0 * ry)) ** 2
        f += np.where(q < 1.0, (1.0 - q) ** 3, 0.0)
    u, v = (x - SX) / (9.0 * max(sp, 0.3)), (y - SY - sag) / (7.0 * max(sp, 0.3))
    return f, noise_at(u, v), sp, sag


def tendrils(d, t, sp, sag):
    """Tapered bent polylines: 3 px root, 2 px middle, 1 px thread, clipped tips; one beaded."""
    x, y = d.centres(W, H)
    m = np.zeros((H, W), bool)
    under = np.zeros((H, W), bool)
    roots = []
    for a, length, thick, bend, tb, beaded, side in TENDRILS:
        ar = math.radians(a)
        dx, dy = math.cos(ar), -math.sin(ar)
        nx, ny = -dy, dx
        reach = length * ease_out(d, t / 130.0)
        grav = 0.5 * G * max(0.0, t - 60.0) ** 2 * 0.35
        keep = 1.0
        if tb is not None and t >= tb:
            keep = max(0.0, 0.55 - (t - tb) / 140.0)   # the outer part has left as a drop
        elif tb is None and t > 150:
            keep = max(0.0, 1.0 - (t - 150) / 110.0)    # short tendrils fold back into the sheet
        if reach * keep < 0.8:
            continue
        rx, ry = SX + dx * 7.5 * sp, SY + dy * 5.0 * sp + sag
        roots.append((rx, ry))
        pts, radii = [], []
        n = 7
        for i in range(n + 1):
            u = i / n
            if u > keep:
                break
            px = rx + dx * reach * u + nx * bend * reach * u * u
            py = ry + dy * reach * u + ny * bend * reach * u * u + grav * u * u
            if side and u > 0.5:
                px += nx * 0.5 * side
                py += ny * 0.5 * side
            pts.append((px, py))
            radii.append(0.5 * thick if u < 0.35 else (1.0 if u < 0.75 and thick >= 2 else 0.5))
        if len(pts) < 2:
            continue
        seg = d.polyline(W, H, pts, radii)
        m |= seg
        # the half away from the upper-left light
        sx, sy = (nx, ny) if ny > 0 else (-nx, -ny)
        under |= seg & (((x - rx) * sx + (y - ry) * sy) > 0.4)
        if beaded and (tb is None or t < tb) and t > 90:
            bx, by = pts[-1]
            m |= d.ellipse(W, H, bx + dx * 0.8, by + dy * 0.8, 1.2, 1.5) & ~d.disc(W, H, bx + dx * 2.0 + 1.0, by + dy * 2.0 - 1.0, 0.8)
    return m, under, roots


def runs(d, t, sag):
    """Runs hang from the coat and crawl down the target: a thick torn root, a shaft whose width
    wanders with a persistent noise, a bead at the tip. At each listed time the bead's neck
    stretches, the bead drops off and falls under gravity inside the frame, the stump shortens
    by 2 px and grows a new, smaller bead. The runs thin and break up from 0.55 s."""
    x, y = d.centres(W, H)
    m = np.zeros((H, W), bool)
    right = np.zeros((H, W), bool)
    for i, (ox, oy, thick, lmax, t0, drops, lean) in enumerate(RUNS):
        if t < t0:
            continue
        length = lmax * ease_out(d, (t - t0) / 240.0)
        for td in drops:
            if t >= td:
                length -= 2.0
        # from 0.5 s the runs thin and drain away, gone by 0.72 s (left hanging alone they read
        # as stick figures)
        thin = 1.0 - 0.6 * d.clamp01((t - 500.0) / 180.0)
        length *= 1.0 - d.clamp01((t - 520.0) / 200.0)
        rx, ry = SX + ox, SY + oy * 0.6 + sag
        if length >= 1.0 and thin > 0.3:
            n = 6
            pts, radii = [], []
            for k in range(n + 1):
                u = k / n
                pts.append((rx + lean * u * u, ry + length * u))
                wobble = 0.65 + 0.7 * float(_NOISE[(i * 2 + k) % 7, (k * 3 + i) % 7])
                r = (0.5 * thick * (1.0 - 0.55 * u)) * wobble * thin
                radii.append(max(0.5, r))
            seg = d.polyline(W, H, pts, radii)
            # torn edge: bite single pixels out of the shaft's sides where the noise is low
            bites = (noise_at((x - rx) / 2.0 + i, (y - ry) / 2.5) < 0.22) & ~d.disc(W, H, rx, ry, 1.5)
            seg &= ~(bites & d.nb(seg, -1, 0) & d.nb(seg, 1, 0))
            m |= seg
            right |= seg & (x > rx + lean * ((y - ry) / max(length, 1.0)) ** 2 + 0.2)
            # the bead at the tip, smaller after each drop; its neck stretches 50 ms before it goes
            tip_x, tip_y = rx + lean, ry + length
            nxt = [td for td in drops if td > t]
            stretch = 1.0 if nxt and t > nxt[0] - 50 else 0.0
            br = (1.4 - 0.3 * sum(1 for td in drops if t >= td)) * thin
            if br > 0.6:
                m |= d.ellipse(W, H, tip_x, tip_y + 1.0 + stretch, br, br + 0.4) & ~d.disc(W, H, tip_x + br, tip_y - 0.2, 0.7)
        # beads that have dropped fall away under gravity, drawn as a 1 px streak and a head
        for td in drops:
            if t < td:
                continue
            dt = t - td
            l_at = lmax * ease_out(d, (td - t0) / 240.0) - 2.0 * sum(1 for e in drops if e < td)
            bx = rx + lean + 0.3
            by = ry + l_at + 2.0 + 0.01 * dt + 0.5 * G * dt * dt
            if by < H - 3.0:
                m |= d.capsule(W, H, bx, by - 2.0, bx, by, 0.5, 1.1)
    return m, right


def stains(d, t, sag):
    m = np.zeros((H, W), bool)
    for ox, oy, r, gone in STAINS:
        if t < 368 or t > gone:
            continue
        rr = r * (1.0 - 0.5 * d.clamp01((t - 450.0) / max(gone - 450.0, 1.0)))
        m |= d.disc(W, H, SX + ox, SY + oy + sag, max(0.6, rr))
    return m


def cuts(d, t, sp, sag):
    """Channels up from the bottom edge, and a diagonal tear through the thin middle from 260 ms
    that splits the sheet into unequal remnants and clears the chest."""
    m = np.zeros((H, W), bool)
    bottom = SY + 7.0 * sp + sag
    for ox, wdt, t0, depth in CHANNELS:
        if t < t0:
            continue
        dep = depth * ease_out(d, (t - t0) / 140.0) + max(0.0, t - t0 - 140.0) * 0.03
        cx = SX + ox * sp
        m |= d.capsule(W, H, cx, bottom + 2.0, cx + 0.6, bottom - dep, wdt * 0.5, max(0.5, wdt * 0.35))
    if t >= 260:
        wdt = 1.0 + (t - 260.0) * 0.035
        m |= d.capsule(W, H, SX + 5.0, SY - 7.0 + sag, SX - 2.0, SY + 8.0 + sag, wdt * 0.4, wdt * 0.6)
    return m


def impact(d):
    """0 ms: a compact angular rupture about 14 px across: unequal straight fragments, a small
    pale centre with one glass pixel. The additive flash draws over it."""
    m = np.zeros((H, W), bool)
    idx = np.zeros((H, W), int)
    cx, cy = FX + 1.0, FY
    for a, ln in [(15, 7.0), (78, 5.0), (130, 6.5), (200, 4.0), (250, 5.5), (320, 4.5), (100, 3.0)]:
        ar = math.radians(a)
        m |= d.capsule(W, H, cx, cy, cx + math.cos(ar) * ln, cy - math.sin(ar) * ln, 1.0, 0.5)
    m |= d.ellipse(W, H, cx, cy, 2.6, 2.2)
    idx[m] = d.BODY
    idx[m & d.disc(W, H, cx, cy, 4.0)] = d.PALE
    idx[d.disc(W, H, cx - 0.5, cy - 0.5, 1.0)] = d.GLASS
    idx[m & ~d.nb(m, 0, 1) & (d.centres(W, H)[1] > cy)] = d.MID
    return idx


def frame(d, t):
    if t <= 0.0:
        return impact(d)
    f, nz, sp, sag = sheet_field(d, t)
    sheet = f >= T_ISO + NOISE_SHARE * (nz - 0.5)
    tm, t_under, roots = tendrils(d, t, sp, sag)
    rm, r_right = runs(d, t, sag)
    m = (sheet & ~cuts(d, t, sp, sag)) | tm | rm | stains(d, t, sag)
    m &= d.inside(W, H, 1)
    x, y = d.centres(W, H)
    late, later = t > 470, t > 650
    idx = np.zeros((H, W), int)
    idx[m] = d.MID if late else d.BODY

    # mid: the underside below a bent line, one bent fold across the sheet, tendril undersides
    under_line = SY + sag + 2.6 * sp + 1.8 * np.sin((x - SX) / 4.5 + 0.7)
    fold = d.capsule(W, H, SX - 8.0 * sp, SY - 3.5 * sp + sag, SX + 7.0 * sp, SY + 1.5 * sp + sag, 0.7, 0.9)
    idx[m & ((y > under_line) | fold | t_under)] = d.DARK if later else d.MID

    # dark pockets under the fold lip and the long tendrils' roots, and down one side of each run
    pockets = d.disc(W, H, SX + 4.0 * sp, SY + 2.6 * sp + sag, 1.2) | d.disc(W, H, SX - 6.0 * sp, SY + 3.5 * sp + sag, 1.0)
    for rx, ry in roots[:2]:
        pockets |= d.disc(W, H, rx + 0.8, ry + 1.4, 1.0)
    idx[m & (pockets | r_right)] = d.DARK

    # dark edge on part of the lower-right perimeter of the sheet only, in runs with gaps; thin
    # threads keep one colour
    open_edge = m & (~d.nb(m, 0, 1) | ~d.nb(m, 1, 0))
    thin = (m & ~d.nb(m, 0, 1) & ~d.nb(m, 0, -1)) | (m & ~d.nb(m, 1, 0) & ~d.nb(m, -1, 0))
    gate = (noise_at((x - SX) / 3.0, (y - SY) / 3.0) > 0.55) & (y > SY + sag - 1.0) & sheet
    idx[open_edge & gate & ~thin] = d.DARK

    # pale: a small off-centre impact core, a few pixels, gone by 184 ms (a larger pale patch
    # bloomed into a soft disc over the chest under the lit material)
    if t < 184:
        pa = 1.0 - t / 184.0
        patch = d.ellipse(W, H, SX - 3.5 * sp, SY - 3.2 * sp + sag, 2.0 + 1.2 * (1 - pa), 1.6 * pa + 0.8)
        idx[m & patch & (y <= under_line)] = d.PALE
    # short highlight marks on upper-left lips at two persistent anchors, gone by 420 ms
    if t < 420:
        lip = m & ~d.nb(m, -1, -1) & d.nb(m, 1, 1) & ~thin
        win = np.zeros((H, W), bool)
        for ax, ay in HIGHLIGHTS[:2]:
            win |= d.disc(W, H, SX + ax * sp, SY + ay * sp + sag, 1.6)
        idx[lip & win] = d.PALE if t < 320 else d.BODY

    # dark edge: 1 px of 425A26 outside every chip on its lower and right sides (away from the
    # upper-left light), so each piece keeps a dark rim on a pale shirt; the lit upper-left edges
    # meet the background directly, so there is no closed contour
    rim = d.outline(m) & (d.nb(m, -1, 0) | d.nb(m, 0, -1) | d.nb(m, -1, -1))
    idx[rim & d.inside(W, H, 0)] = d.DARK
    # dark backing while the splash is bright: a half-alpha 425A26 halo round everything drawn
    if 46 <= t <= 300:
        drawn = idx > 0
        idx[d.outline(drawn) & (idx == 0)] = d.HALO
    return idx


def draw(d):
    return d.sheet([frame(d, k * FRAME_MS) for k in range(FRAMES)], 6)
