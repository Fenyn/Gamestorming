"""Import hand-painted terrain textures as board art.

Golden Skull 3D Starter Pack sources are graded and downscaled to one board tile (TILE_PX); the
large ground fields (grass, dirt, mud) come from the Stylized Grass and Dirt pack, recoloured
toward FFT's ground (see FIELDS). Everything is written to assets/textures/terrain/gs/. Run from
anywhere:

    python tools/art/import_goldenskull.py

Then run a Godot --import pass so the new files get .import files.
"""
import pathlib

from PIL import Image, ImageFilter

SOURCE = pathlib.Path(
    "F:/UnityNVME/Art/Sprites/Golden Skull/GoldenSkull_3DStarterPack_v01_Textures_PNG/Textures_PNG")
PROJECT = pathlib.Path(__file__).resolve().parents[2]
OUT = PROJECT / "assets/textures/terrain/gs"
TILE_PX = 64

# Channel multipliers. The pack's grass is lime; FFT greens are deeper and less yellow.
GRASS = (0.5, 0.64, 0.42)
EARTH = (0.85, 0.85, 0.8)
MUD = (0.62, 0.58, 0.55)
WOOD = (0.72, 0.66, 0.6)
NONE = (1.0, 1.0, 1.0)

# output name: (source file, grade, rotate 90 degrees)
TEXTURES = {
    "grass_a": ("T_Grass_01.png", GRASS, False),
    "grass_side": ("T_Grass-DirtSide_01.png", (0.78, 0.86, 0.68), False),
    "dirt_b": ("T_Dirt_02.png", EARTH, False),
    "earth_side": ("T_Dirt_03.png", EARTH, False),
    "mud_a": ("T_Dirt_04.png", MUD, False),
    "stone_top": ("T_Stone_Pattern_01.png", NONE, False),
    # Outdoor paving: FFT's stone reads grey and a little darker than the grass around it; the
    # pack's is beige. Dungeon floors keep the ungraded stone_top under their own palette tint.
    "stone_path": ("T_Stone_Pattern_01.png", (0.70, 0.72, 0.76), False),
    "stone_top_b": ("T_Stone_Pattern_03.png", NONE, False),
    "cobble": ("T_Stone_Cobble_01.png", NONE, False),
    "brick": ("T_Brick_01.png", (0.8, 0.75, 0.72), False),
    "stone_wall": ("T_Stone_Wall_SideCenter_01.png", NONE, False),
    "mossy_side_top": ("T_Stone_Wall_Mossy_SideTop_01.png", NONE, False),
    "mossy_side": ("T_Stone_Wall_Mossy_SideCenter_01.png", NONE, False),
    "wood_deck": ("Wood/T_Wood_03.png", WOOD, False),
    "wood_beam": ("Wood/T_Wood_03.png", WOOD, True),
}


# Fields: textures that span several board tiles so a large area of one surface reads as one
# continuous painting instead of a patchwork of per-tile variants. The baker picks each tile's
# window of the field by board position.
#
# FFT The Ivalice Chronicles paints its ground as smooth olive with soft darker blotches and no
# blade detail (a flat patch varies by about 6 to 15 levels). The fields keep only the light and
# dark pattern of a hand-painted source, a median filter removes its small detail (flowers,
# pebbles), and the pattern is recoloured to one target colour at a low spread. The warm key light
# and AgX tonemap push olive toward mustard, so the grass target sits greener than FFT's render.
# The user picked the Stylized pack's soft blotches (option B) on 2026-09-28.
STYLIZED = pathlib.Path("F:/UnityNVME/Art/Materials/Stylized_GrassAndDirt/JPEG")
FIELD_PX = TILE_PX * 4
# output name: (source under STYLIZED, target RGB, spread in levels, median size, rotate 90 degrees)
FIELDS = {
    "grass_field": ("Stylized_HandpaintedGrass_01/Stylized_HandpaintedGrass_01_basecolor.jpg", (70, 100, 44), 9, 9, False),
    "dirt_field": ("Stylized_HandpaintedDirt_01/Stylized_HandpaintedDirt_01_basecolor.jpg", (104, 86, 62), 10, 9, False),
    "mud_field": ("Stylized_HandpaintedDirt_01/Stylized_HandpaintedDirt_01_basecolor.jpg", (78, 66, 52), 9, 9, True),
}


def recolour(image: Image.Image, target, spread) -> Image.Image:
    """Keep the image's light and dark pattern and paint it in one colour: each pixel's luminance,
    normalised, sets how far it sits above or below the target, scaled per channel."""
    rgb = image.convert("RGB")
    lum = list(rgb.convert("L").tobytes())
    mean = sum(lum) / len(lum)
    std = (sum((v - mean) ** 2 for v in lum) / len(lum)) ** 0.5 or 1.0
    avg = sum(target) / 3
    pixels = [tuple(max(0, min(255, round(t + (v - mean) / std * spread * t / avg))) for t in target)
              for v in lum]
    out = Image.new("RGB", rgb.size)
    out.putdata(pixels)
    return out


def grade(image: Image.Image, multipliers) -> Image.Image:
    channels = image.convert("RGB").split()
    return Image.merge("RGB", [
        channel.point(lambda v, k=k: min(255, int(v * k))) for channel, k in zip(channels, multipliers)
    ])


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["# Golden Skull terrain textures", "",
             f"Imported by `tools/art/import_goldenskull.py` from `{SOURCE}` at {TILE_PX} px.",
             "Golden Skull 3D Starter Pack v01. No licence file ships with the pack; confirm terms",
             "before release.", "", "| File | Source |", "| --- | --- |"]
    for name, (source, multipliers, rotate) in TEXTURES.items():
        image = grade(Image.open(SOURCE / source), multipliers)
        if rotate:
            image = image.rotate(-90, expand=True)
        image.resize((TILE_PX, TILE_PX), Image.LANCZOS).save(OUT / f"{name}.png")
        lines.append(f"| {name}.png | {source}{' (rotated)' if rotate else ''} |")
    for name, (source, target, spread, median, rotate) in FIELDS.items():
        image = Image.open(STYLIZED / source).convert("RGB").filter(ImageFilter.MedianFilter(median))
        if rotate:
            image = image.rotate(-90)
        image = image.resize((FIELD_PX, FIELD_PX), Image.LANCZOS)
        recolour(image, target, spread).save(OUT / f"{name}.png")
        lines.append(f"| {name}.png | Stylized Grass and Dirt: {source}{' (rotated)' if rotate else ''}, "
                     f"4x4 tiles, recoloured to {target} |")
    lines += ["", "The *_field textures come from the Stylized Grass and Dirt pack",
              f"(`{STYLIZED}`). No licence file ships with it either; confirm terms before release."]
    (OUT / "SOURCES.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {len(TEXTURES)} textures to {OUT}")


if __name__ == "__main__":
    main()
