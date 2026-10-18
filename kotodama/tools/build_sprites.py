"""Draws the small code-drawn sprites: spirit body layers, flower layers, bubbles, gate light.

Run from the kotodama folder:  python tools/build_sprites.py
Every sprite is drawn on a stated grid from the palette below. Any other colour fails the build.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"

PALETTE = {
    "white": "#ffffff",
    "mid": "#8c8c8c",
    "ink": "#1e1928",
    "shadow": "#1e2814",
    "stem": "#4f8a3c",
    "stem_dark": "#2f5a24",
    "leaf": "#6fae4e",
    "gold": "#f2d06b",
    "gold_light": "#fff3c0",
    "bubble": "#fff8e6",
    "bubble_edge": "#7a6a4a",
    "water": "#5aa0e0",
}
T = (0, 0, 0, 0)


def rgba(name: str, alpha: int = 255) -> tuple:
    h = PALETTE[name].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)


def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), T)


def check(img: Image.Image, name: str, allowed: set) -> None:
    bad = set()
    for px in img.getdata():
        if px[3] == 0:
            continue
        if px[:3] not in allowed:
            bad.add(px[:3])
    if bad:
        print(f"PALETTE FAIL {name}: {sorted(bad)}")
        sys.exit(1)


def save(img: Image.Image, name: str) -> None:
    allowed = {rgba(k)[:3] for k in PALETTE}
    check(img, name, allowed)
    img.save(OUT / f"{name}.png")
    print("wrote", name, img.size)


def blob() -> None:
    """36x44. White fill, mid outline. Modulated by the zone tint at runtime."""
    img = canvas(36, 44)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 34, 42], fill=rgba("white"), outline=rgba("mid"))
    save(img, "blob")


def eyes() -> None:
    """14x5. Two eyes: ink rim, white, ink pupil."""
    img = canvas(14, 5)
    d = ImageDraw.Draw(img)
    for x in (0, 9):
        d.rectangle([x, 0, x + 4, 4], fill=rgba("ink"))
        d.rectangle([x + 1, 1, x + 3, 3], fill=rgba("white"))
        d.point((x + 2, 2), fill=rgba("ink"))
    save(img, "eyes")


def shadow() -> None:
    """32x8 ellipse, 40% alpha."""
    img = canvas(32, 8)
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 31, 7], fill=rgba("shadow", 100))
    save(img, "shadow")


def halo() -> None:
    """48x48 ring for burned spirits."""
    img = canvas(48, 48)
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 45, 45], outline=rgba("gold"), width=2)
    for x, y in ((23, 0), (23, 47), (0, 23), (47, 23)):
        d.point((x, y), fill=rgba("gold_light"))
    save(img, "halo")


def bubble() -> None:
    """16x16 speech bubble with a tail. Used over hungry spirits and flowers."""
    img = canvas(16, 16)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, 15, 11], radius=3, fill=rgba("bubble"), outline=rgba("bubble_edge"))
    d.polygon([(4, 11), (8, 11), (5, 15)], fill=rgba("bubble"))
    d.line([(4, 11), (5, 15)], fill=rgba("bubble_edge"))
    d.line([(5, 15), (8, 12)], fill=rgba("bubble_edge"))
    d.line([(5, 11), (7, 11)], fill=rgba("bubble"))
    save(img, "bubble")


def drop() -> None:
    """8x10 water drop shown inside the bubble over a drooping flower."""
    img = canvas(8, 10)
    d = ImageDraw.Draw(img)
    d.polygon([(4, 0), (7, 5), (4, 9), (0, 5)], fill=rgba("water"))
    d.ellipse([1, 4, 6, 9], fill=rgba("water"))
    d.point((2, 5), fill=rgba("white"))
    save(img, "drop")


def stems() -> None:
    """Strip of 2 frames, 16x24 each: upright, drooping."""
    img = canvas(32, 24)
    d = ImageDraw.Draw(img)
    # upright
    d.line([(8, 23), (8, 8)], fill=rgba("stem"), width=2)
    d.line([(7, 23), (7, 9)], fill=rgba("stem_dark"))
    d.polygon([(8, 16), (3, 13), (4, 17)], fill=rgba("leaf"))
    d.polygon([(9, 19), (14, 16), (13, 20)], fill=rgba("leaf"))
    # drooping
    ox = 16
    d.line([(ox + 8, 23), (ox + 8, 14)], fill=rgba("stem"), width=2)
    d.line([(ox + 8, 14), (ox + 12, 10)], fill=rgba("stem"), width=2)
    d.line([(ox + 7, 23), (ox + 7, 15)], fill=rgba("stem_dark"))
    d.polygon([(ox + 8, 19), (ox + 3, 18), (ox + 5, 21)], fill=rgba("leaf"))
    save(img, "stems")


def blooms() -> None:
    """Strip of 4 frames, 16x16 each: bud, small, full, big. White, modulated by zone tint."""
    img = canvas(64, 16)
    d = ImageDraw.Draw(img)
    # bud
    d.ellipse([6, 6, 9, 11], fill=rgba("white"), outline=rgba("mid"))
    # small
    ox = 16
    for cx, cy in ((7, 6), (10, 8), (7, 10), (4, 8)):
        d.ellipse([ox + cx - 1, cy - 1, ox + cx + 1, cy + 1], fill=rgba("white"))
    d.point((ox + 7, 8), fill=rgba("gold"))
    # full
    ox = 32
    for cx, cy in ((8, 4), (12, 8), (8, 12), (4, 8), (11, 5), (11, 11), (5, 11), (5, 5)):
        d.ellipse([ox + cx - 2, cy - 2, ox + cx + 2, cy + 2], fill=rgba("white"), outline=rgba("mid"))
    d.ellipse([ox + 6, 6, ox + 10, 10], fill=rgba("gold"))
    # big
    ox = 48
    for cx, cy in ((8, 2), (14, 8), (8, 14), (2, 8), (12, 4), (12, 12), (4, 12), (4, 4)):
        d.ellipse([ox + cx - 2, cy - 2, ox + cx + 2, cy + 2], fill=rgba("white"), outline=rgba("mid"))
    d.ellipse([ox + 5, 5, ox + 11, 11], fill=rgba("gold"))
    d.point((ox + 7, 7), fill=rgba("gold_light"))
    save(img, "blooms")


def light() -> None:
    """Strip of 2 frames, 16x16: a nameless spirit light at the gate."""
    img = canvas(32, 16)
    d = ImageDraw.Draw(img)
    for i in range(2):
        ox = i * 16
        r = 5 if i == 0 else 6
        d.ellipse([ox + 8 - r, 8 - r, ox + 8 + r, 8 + r], fill=rgba("gold", 150))
        d.ellipse([ox + 5, 5, ox + 10, 10], fill=rgba("gold_light"))
        d.point((ox + 8, 1 if i == 0 else 0), fill=rgba("gold_light"))
    save(img, "light")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    blob()
    eyes()
    shadow()
    halo()
    bubble()
    drop()
    stems()
    blooms()
    light()


if __name__ == "__main__":
    main()
