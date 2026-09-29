"""Import Golden Skull 3D Starter Pack textures as board terrain art.

Each 512 px hand-painted source is graded and downscaled to one board tile (TILE_PX) and written
to assets/textures/terrain/gs/. The ground baker blits one texture per tile with nearest
filtering, so the painted clumps read as chunky FFT-style blocks. Run from anywhere:

    python tools/art/import_goldenskull.py

Then run a Godot --import pass so the new files get .import files.
"""
import pathlib

from PIL import Image, ImageEnhance

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
    "grass_b": ("T_Grass_02.png", GRASS, False),
    "grass_c": ("T_Grass_04.png", GRASS, False),
    "grass_side": ("T_Grass-DirtSide_01.png", (0.78, 0.86, 0.68), False),
    "dirt_a": ("T_Dirt_01.png", EARTH, False),
    "dirt_b": ("T_Dirt_02.png", EARTH, False),
    "earth_side": ("T_Dirt_03.png", EARTH, False),
    "mud_a": ("T_Dirt_04.png", MUD, False),
    "mud_b": ("T_Dirt_06.png", MUD, False),
    "stone_top": ("T_Stone_Pattern_01.png", NONE, False),
    "stone_top_b": ("T_Stone_Pattern_03.png", NONE, False),
    "cobble": ("T_Stone_Cobble_01.png", NONE, False),
    "mossy_top": ("T_Stone_Wall_Mossy_Top_01.png", NONE, False),
    "brick": ("T_Brick_01.png", (0.8, 0.75, 0.72), False),
    "stone_wall": ("T_Stone_Wall_SideCenter_01.png", NONE, False),
    "mossy_side_top": ("T_Stone_Wall_Mossy_SideTop_01.png", NONE, False),
    "mossy_side": ("T_Stone_Wall_Mossy_SideCenter_01.png", NONE, False),
    "wood_deck": ("Wood/T_Wood_03.png", WOOD, False),
    "wood_beam": ("Wood/T_Wood_03.png", WOOD, True),
}


# Fields: textures that span several board tiles so a large area of one surface reads as one
# continuous painting instead of a patchwork of per-tile variants. The baker picks each tile's
# window of the field by board position. output name: (source, grade, tiles per side, contrast,
# colour). The pack's grass is flat and lime; FFT ground has deep shadows between the clumps and
# muted greens, so the grass field gets extra contrast and less saturation before its grade.
FIELD_GRASS = (0.52, 0.62, 0.55)
FIELDS = {
    "grass_field": ("T_Grass_01.png", FIELD_GRASS, 4, 2.4, 0.6),
    "dirt_field": ("T_Dirt_01.png", EARTH, 4, 1.2, 0.9),
    "mud_field": ("T_Dirt_04.png", MUD, 4, 1.2, 0.9),
}


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
    for name, (source, multipliers, tiles, contrast, colour) in FIELDS.items():
        image = Image.open(SOURCE / source).convert("RGB")
        image = ImageEnhance.Color(ImageEnhance.Contrast(image).enhance(contrast)).enhance(colour)
        image = grade(image, multipliers)
        image.resize((TILE_PX * tiles, TILE_PX * tiles), Image.LANCZOS).save(OUT / f"{name}.png")
        lines.append(f"| {name}.png | {source}, {tiles}x{tiles} tiles |")
    (OUT / "SOURCES.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {len(TEXTURES)} textures to {OUT}")


if __name__ == "__main__":
    main()
