"""Night slum backdrop at 320x180, drawn with PIL calls on a locked palette.

Sky and stars come from the Medieval pack's MBG5 layers 1-2. Everything below is drawn here.
Writes one PNG per parallax layer to assets/story/crawl/slum/ and fails on any colour outside PAL.
The lit window and its sill sit on their own top layer ("lamp") so the scene's dim can go under it.
"""
import os
import random
from PIL import Image, ImageDraw

PACK = r"F:/UnityNVME/Art/Backgrounds/2D Medieval Backgrounds Pack/320x180"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "story", "crawl", "slum")
W, H = 320, 180

PAL = {
    "capital": "#322d5b", "capital_dark": "#292a59", "gold": "#e0b860",
    "far": "#271f4c", "far_win": "#322d5b",
    "haze": "#44347a", "smoke": "#3a3168",
    "mid": "#1e1840", "mid_edge": "#2c2b68", "mid_win": "#2a2560",
    "near": "#141030", "near_edge": "#242457", "near_win": "#1e1a48", "near_panel": "#19143a",
    "fore": "#0c0a1f", "fore_edge": "#1a1b42", "beam": "#171637", "plaster": "#110e29",
    "warm": "#ffd98a", "warm_mid": "#f0a050", "warm_dim": "#8a4a3a", "leaf": "#2f3a2a",
    "cloth_a": "#3a398a", "cloth_b": "#55448e",
}
SKY = {"#44347a", "#6956a6", "#292a59", "#141538", "#55448e", "#1a1b42", "#ceeae9", "#feeeeb"}
ALLOWED = {c.lower() for c in PAL.values()} | SKY


def layer():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def roof(d, rng, x, w, top, body, edge, kind=None):
    kind = kind or rng.choice(["gable", "gable", "lean", "flat"])
    if kind == "gable":
        peak = rng.randint(4, max(5, w // 2 + 2))
        d.polygon([(x - 2, top), (x + w + 1, top), (x + w // 2, top - peak)], fill=body)
        d.line((x + w // 2, top - peak, x + w + 1, top), fill=edge)
        return top - peak
    if kind == "lean":
        rise = rng.randint(3, 8)
        if rng.random() < 0.5:
            d.polygon([(x - 1, top), (x + w, top), (x + w, top - rise)], fill=body)
            d.line((x - 1, top, x + w, top - rise), fill=edge)
        else:
            d.polygon([(x - 1, top), (x + w, top), (x - 1, top - rise)], fill=body)
            d.line((x - 1, top - rise, x + w, top), fill=edge)
        return top - rise
    d.rectangle((x, top - 2, x + w - 1, top), fill=body)
    d.line((x, top - 2, x + w - 1, top - 2), fill=edge)
    return top - 2


def house(d, rng, x, w, base, h, body, edge, win, win_rate, extras=False, smoke=None):
    """One tenement: body, jetty storey, roof, chimney, windows; near rows add shacks and stairs."""
    top = base - h
    d.rectangle((x, top, x + w - 1, base), fill=body)
    if h > 30 and rng.random() < 0.6:
        jy = top + rng.randint(6, h // 2)
        d.rectangle((x - 1, top, x + w, jy), fill=body)
        d.line((x - 1, jy + 1, x + w, jy + 1), fill=edge)
    roof(d, rng, x, w, top, body, edge)
    if rng.random() < 0.7:
        cx = x + rng.randint(1, max(1, w - 3))
        ch = rng.randint(4, 9)
        d.rectangle((cx, top - ch - 3, cx + 1, top), fill=body)
        if smoke and rng.random() < 0.18:
            sx, sy = cx, top - ch - 4
            for k, r in enumerate((1, 1, 2, 2, 3)):
                px = sx + k * 2
                py = sy - k * 3
                d.ellipse((px - r, py - r, px + r, py + r), fill=smoke)
    d.line((x + w - 1, top, x + w - 1, base), fill=edge)
    if extras:
        if rng.random() < 0.45 and w > 10:
            sw = rng.randint(5, min(9, w - 2))
            sx = x + rng.randint(0, w - sw)
            sh = rng.randint(4, 7)
            d.rectangle((sx, top - sh, sx + sw, top), fill=body)
            roof(d, rng, sx, sw, top - sh, body, edge, "lean")
            d.rectangle((sx + 2, top - sh + 2, sx + 3, top - sh + 3), fill=win)
        if rng.random() < 0.4:
            side = rng.choice((-1, 1))
            lx = x - 6 if side < 0 else x + w
            ly = base - rng.randint(8, 14)
            d.rectangle((lx, ly, lx + 5, base), fill=body)
            if side < 0:
                d.line((lx - 1, ly, lx + 6, ly - 3), fill=edge)
            else:
                d.line((lx - 1, ly - 3, lx + 6, ly), fill=edge)
        for sy in range(top + 6, base - 2, 9):
            d.line((x + 1, sy, x + w - 2, sy), fill=PAL["near_panel"])
    if win:
        for wy in range(top + 4, base - 4, 7):
            for wx in range(x + 2, x + w - 3, 5):
                if rng.random() < win_rate:
                    d.rectangle((wx, wy, wx + 1, wy + 2), fill=win)
    return top


def row(d, rng, x0, x1, base, hmin, hmax, wmin, wmax, body, edge, win, win_rate, extras=False, smoke=None):
    tops = []
    x = x0
    while x < x1:
        w = rng.randint(wmin, wmax)
        h = rng.randint(hmin, hmax)
        tops.append((x, w, house(d, rng, x, w, base + rng.randint(-2, 2), h, body, edge, win, win_rate, extras, smoke)))
        x += w + rng.randint(-2, 1)
    return tops


def capital(rng):
    im, d = layer()
    wall_top = 74
    d.polygon([(0, 104), (60, 96), (140, 90), (200, 86), (270, 92), (W, 100), (W, 130), (0, 130)], fill=PAL["capital_dark"])
    d.rectangle((0, wall_top, W, 92), fill=PAL["capital"])
    for x in range(10, W, 40):
        d.line((x, wall_top + 4, x, 90), fill=PAL["capital_dark"])
    for x in range(0, W, 6):
        d.rectangle((x, wall_top - 3, x + 2, wall_top), fill=PAL["capital"])
    for tx in (18, 92, 150, 236, 300):
        d.rectangle((tx, wall_top - 16, tx + 9, wall_top), fill=PAL["capital"])
        d.polygon([(tx - 1, wall_top - 16), (tx + 10, wall_top - 16), (tx + 4, wall_top - 26)], fill=PAL["capital"])
    d.polygon([(170, wall_top), (250, wall_top), (238, 50), (182, 50)], fill=PAL["capital"])
    for sx, sh in ((186, 30), (200, 44), (214, 36), (228, 26)):
        d.rectangle((sx, 50 - sh, sx + 6, 50), fill=PAL["capital"])
        d.polygon([(sx - 1, 50 - sh), (sx + 7, 50 - sh), (sx + 3, 50 - sh - 10)], fill=PAL["capital"])
    d.rectangle((200, 4, 201, 10), fill=PAL["capital"])
    for sx, sh in ((186, 30), (200, 44), (214, 36), (228, 26)):
        for gy in range(50 - sh + 4, 46, 6):
            if rng.random() < 0.55:
                d.rectangle((sx + 3, gy, sx + 3, gy + 1), fill=PAL["gold"])
    for gx in range(184, 238, 5):
        for gy in (56, 63, 70):
            if rng.random() < 0.3:
                d.rectangle((gx, gy, gx, gy + 1), fill=PAL["gold"])
    for tx in (18, 92, 150, 236, 300):
        d.rectangle((tx + 4, wall_top - 11, tx + 4, wall_top - 10), fill=PAL["gold"])
    return im


def heap(rng):
    """The farthest slum, piled up against the foot of the wall."""
    im, d = layer()
    row(d, rng, -2, W + 10, 118, 10, 30, 5, 10, PAL["capital_dark"], PAL["capital"], None, 0)
    d.rectangle((0, 118, W, H), fill=PAL["capital_dark"])
    return im


def haze():
    im, d = layer()
    for y in range(108, 124):
        for x in range(0, W):
            if (x + y) % 2 == 0 and y > 112 or (x * 3 + y) % 7 == 0:
                d.point((x, y), fill=PAL["haze"])
    return im


def far(rng):
    im, d = layer()
    row(d, rng, -4, W + 10, 132, 14, 38, 6, 13, PAL["far"], PAL["far_win"], PAL["far_win"], 0.25)
    d.rectangle((0, 132, W, H), fill=PAL["far"])
    return im


def mid(rng):
    im, d = layer()
    row(d, rng, -6, W + 10, 150, 22, 50, 9, 18, PAL["mid"], PAL["mid_edge"], PAL["mid_win"], 0.35, smoke=PAL["smoke"])
    d.rectangle((0, 150, W, H), fill=PAL["mid"])
    return im


def near(rng):
    im, d = layer()
    tops = row(d, rng, 58, 276, 168, 30, 58, 12, 22, PAL["near"], PAL["near_edge"], PAL["near_win"], 0.4,
               extras=True, smoke=PAL["smoke"])
    d.rectangle((0, 166, W, H), fill=PAL["near"])
    for (xa, wa, ta), (xb, _, tb) in zip(tops, tops[1:]):
        if abs(ta - tb) < 10 and rng.random() < 0.4:
            y = max(ta, tb) + 6
            d.line((xa + wa - 2, y, xb + 1, y), fill=PAL["near_edge"])
            d.line((xa + wa - 2, y + 1, xb + 1, y + 1), fill=PAL["near"])
    for i, (x0, x1, y0) in enumerate(((84, 150, 132), (150, 214, 138), (214, 266, 128))):
        sag = 5
        pts = [(x, y0 + int(sag * 4 * (x - x0) * (x1 - x) / (x1 - x0) ** 2)) for x in range(x0, x1 + 1)]
        d.line(pts, fill=PAL["near_edge"])
        for k in range(x0 + 6, x1 - 4, 9):
            yy = y0 + int(sag * 4 * (k - x0) * (x1 - k) / (x1 - x0) ** 2)
            d.rectangle((k, yy + 1, k + 3, yy + 5 + (k % 3)), fill=PAL["cloth_a"] if (k + i) % 2 else PAL["cloth_b"])
    return im


def foreground():
    im, d = layer()
    # left tenement, close to camera: jettied storeys, plaster panels between timbers
    storeys = [(10, 22, 66), (22, 64, 63), (64, 108, 60), (108, H, 57)]
    d.polygon([(0, 0), (76, 0), (69, 10), (0, 10)], fill=PAL["fore"])
    d.line((0, 10, 69, 10), fill=PAL["fore_edge"])
    for x in range(2, 70, 4):
        d.point((x, 11), fill=PAL["beam"])
    for top, bottom, right in storeys:
        d.rectangle((0, top, right, bottom), fill=PAL["fore"])
        for bx in range(0, right - 2, 14):
            d.rectangle((bx + 2, top + 2, min(bx + 12, right - 2), bottom - 4), fill=PAL["plaster"])
            d.line((bx + 1, top + 1, bx + 1, bottom - 3), fill=PAL["beam"])
            if bottom - top > 30 and (bx // 14) % 2 == 0:
                d.line((bx + 2, bottom - 4, min(bx + 12, right - 2), top + 14), fill=PAL["beam"])
            elif bottom - top > 30:
                d.line((bx + 2, top + 14, min(bx + 12, right - 2), bottom - 4), fill=PAL["beam"])
        d.line((0, bottom - 3, right, bottom - 3), fill=PAL["beam"])
        d.line((0, bottom - 1, right, bottom - 1), fill=PAL["fore_edge"])
        d.line((right, top, right, bottom), fill=PAL["fore_edge"])
        for px in range(4, right - 2, 14):
            d.point((px, bottom), fill=PAL["fore_edge"])
    for sy in (30, 74):
        d.rectangle((14, sy, 25, sy + 12), fill=PAL["fore"])
        d.line((14, sy, 14, sy + 12), fill=PAL["beam"])
        d.line((25, sy, 25, sy + 12), fill=PAL["beam"])
        d.line((19, sy, 19, sy + 12), fill=PAL["fore_edge"])
    d.line((60, 64, 74, 64), fill=PAL["fore_edge"])
    d.line((72, 64, 72, 70), fill=PAL["beam"])
    d.rectangle((70, 70, 74, 76), fill=PAL["fore"])
    d.line((70, 70, 74, 70), fill=PAL["fore_edge"])
    # right lean-to with a ladder and an awning
    d.polygon([(266, 60), (W, 38), (W, H), (276, H), (276, 70)], fill=PAL["fore"])
    d.line((266, 60, W, 38), fill=PAL["fore_edge"])
    d.line((276, 70, 276, H), fill=PAL["fore_edge"])
    for sx in range(284, W, 10):
        d.rectangle((sx, 88, sx + 3, 93), fill=PAL["plaster"])
        d.line((sx, 88, sx + 3, 88), fill=PAL["beam"])
    d.polygon([(272, 128), (300, 124), (300, 128), (276, 133)], fill=PAL["beam"])
    d.line((272, 128, 300, 124), fill=PAL["fore_edge"])
    for ly in range(104, 172, 5):
        d.line((262, ly, 268, ly), fill=PAL["beam"])
    d.line((262, 100, 262, 172), fill=PAL["fore_edge"])
    d.line((268, 100, 268, 172), fill=PAL["fore_edge"])
    d.rectangle((0, 172, W, H), fill=PAL["fore"])
    d.line((0, 172, W, 172), fill=PAL["fore_edge"])
    return im


def lamp():
    """The one lit window, its spill and a potted weed on the sill."""
    im, d = layer()
    wx, wy = 34, 116
    d.rectangle((wx - 2, wy - 2, wx + 11, wy + 15), fill=PAL["beam"])
    d.rectangle((wx, wy, wx + 9, wy + 13), fill=PAL["warm"])
    d.rectangle((wx, wy + 9, wx + 9, wy + 13), fill=PAL["warm_mid"])
    d.line((wx + 4, wy, wx + 4, wy + 13), fill=PAL["warm_dim"])
    d.line((wx + 5, wy, wx + 5, wy + 13), fill=PAL["warm_dim"])
    d.line((wx, wy + 6, wx + 9, wy + 6), fill=PAL["warm_dim"])
    d.rectangle((wx - 4, wy + 16, wx + 13, wy + 17), fill=PAL["fore_edge"])
    for sx in range(wx - 4, wx + 14, 2):
        d.point((sx, wy + 16), fill=PAL["warm_dim"])
    px, py = wx + 10, wy + 15
    d.rectangle((px, py - 2, px + 3, py), fill=PAL["warm_dim"])
    for lx, ly in ((px + 1, py - 3), (px + 1, py - 4), (px + 2, py - 5), (px, py - 5), (px + 2, py - 3),
                   (px + 3, py - 6), (px - 1, py - 4)):
        d.point((lx, ly), fill=PAL["leaf"])
    d.point((px + 3, py - 7), fill=PAL["warm"])
    for k in range(4):
        d.point((wx + 2 + k * 2, wy + 19 + k % 2), fill=PAL["warm_dim"])
    return im


def check(name, im):
    bad = {"#%02x%02x%02x" % p[:3] for p in im.get_flattened_data() if p[3] and "#%02x%02x%02x" % p[:3] not in ALLOWED}
    if bad:
        raise SystemExit(f"{name}: off-palette {sorted(bad)}")


def main():
    rng = random.Random(7)
    os.makedirs(OUT, exist_ok=True)
    sky = Image.open(f"{PACK}/MBG5 layer1.png").convert("RGBA")
    src = Image.open(f"{PACK}/MBG5 layer2.png").convert("RGBA")
    stars = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    stars.paste(src, (80, -36))
    stars.paste(src.crop((W - 80, 0, W, H)), (0, -36))
    layers = [("sky", sky), ("stars", stars), ("capital", capital(rng)), ("heap", heap(rng)), ("haze", haze()),
              ("far", far(rng)), ("mid", mid(rng)), ("near", near(rng)), ("fore", foreground()), ("lamp", lamp())]
    flat = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for name, im in layers:
        check(name, im)
        im.save(os.path.join(OUT, f"{name}.png"))
        flat.alpha_composite(im)
    check("flat", flat)
    print("palette ok")


main()
