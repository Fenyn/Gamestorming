"""Tree layer for the MBG1 dusk crawl page, at 320x180.

The dusk page shows the same trees and hanged skeleton as the MBG2 sunset page before it, plus a
second skeleton (the first one mirrored) on the right tree. The pack has no MBG1 version of these
trees, so every pixel of MBG2 layer7 takes MBG1's flat tree colour.
Writes assets/story/crawl/mbg1/trees.png and fails on any colour other than TREE.
"""
import os
from PIL import Image

CRAWL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "story", "crawl")
SOURCE = os.path.join(CRAWL, "mbg2", "layer7.png")
OUT = os.path.join(CRAWL, "mbg1", "trees.png")
W, H = 320, 180
TREE = (43, 54, 77, 255)

# MBG2 skeleton: black pixels in this box, hung from a rope at ROPE_X.
SKELETON_BOX = (112, 118, 132, 141)
ROPE_X = 122

# Right-tree branch underside the second rope ties to, and its length in pixels.
SECOND_ANCHOR = (221, 87)
SECOND_ROPE = 14


def skeleton_offsets(src):
    x0, y0, x1, y1 = SKELETON_BOX
    return [(x - ROPE_X, y - y0)
            for y in range(y0, y1) for x in range(x0, x1)
            if src.getpixel((x, y)) == (0, 0, 0, 255)]


def main():
    src = Image.open(SOURCE).convert("RGBA")
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            if src.getpixel((x, y))[3]:
                out.putpixel((x, y), TREE)

    ax, ay = SECOND_ANCHOR
    for y in range(ay, ay + SECOND_ROPE):
        out.putpixel((ax, y), TREE)
    for dx, dy in skeleton_offsets(src):
        out.putpixel((ax - dx, ay + SECOND_ROPE + dy), TREE)

    stray = {c for _, c in out.getcolors(W * H) if c[3] and c != TREE}
    if stray:
        raise SystemExit(f"off-palette colours: {sorted(stray)}")
    out.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
