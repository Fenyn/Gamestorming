"""Copy the cutscene emote bubbles from LimeZu Modern Interiors into one small sheet.

Source: UI_thinking_emotes_animation_16x16.png (160x160). Its top two rows are the pop-in sample: each
frame is 16x32, the bubble tile over the trailing dots. Below are the icon bubbles, two frames each,
one 16x16 tile per frame. Run from anywhere:

    python tools/art/import_emotes.py

Output: assets/sprites/emotes/emotes.png, 4 columns of 16x32 frames. Row 0 is the pop-in (dot, two
dots, small bubble, big bubble). Each row after holds one emote's two frames in columns 0 and 1, the
icon bubble over the sample's trailing dots. The row order matches the Emote enum
(scripts/story/cutscene/Emote.cs).
"""
import pathlib

from PIL import Image

PROJECT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = pathlib.Path(
    "F:/UnityNVME/Art/Sprites/Farming/moderninteriors-win/4_User_Interface_Elements/"
    "UI_thinking_emotes_animation_16x16.png")
OUT = PROJECT / "assets/sprites/emotes/emotes.png"

TILE = 16
COLUMNS = 4

# Emote name: (row, first column) of its two icon frames in the source.
EMOTES = [
    ("exclaim", (4, 0)),   # yellow !
    ("alarm", (5, 0)),     # red !
    ("question", (5, 2)),  # blue ?
    ("ellipsis", (9, 2)),  # bars, then ...
    ("sweat", (9, 6)),     # sweat drop
    ("anger", (9, 0)),     # anger mark
]

# The trailing dots under the sample's icon frames.
DOTS = (1, 4)


def tile(sheet, row, col):
    return sheet.crop((col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE))


def main():
    sheet = Image.open(SOURCE).convert("RGBA")
    out = Image.new("RGBA", (COLUMNS * TILE, (1 + len(EMOTES)) * 2 * TILE), (0, 0, 0, 0))
    for col in range(COLUMNS):
        out.alpha_composite(tile(sheet, 0, col), (col * TILE, 0))
        out.alpha_composite(tile(sheet, 1, col), (col * TILE, TILE))
    dots = tile(sheet, *DOTS)
    for index, (_, (row, first)) in enumerate(EMOTES):
        y = (1 + index) * 2 * TILE
        for frame in range(2):
            out.alpha_composite(tile(sheet, row, first + frame), (frame * TILE, y))
            out.alpha_composite(dots, (frame * TILE, y + TILE))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(f"{OUT} {out.size}")


if __name__ == "__main__":
    main()
