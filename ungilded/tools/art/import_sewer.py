"""Import the sewer biome's terrain textures and prop sprites.

Terrain textures come from the Golden Skull 3D Starter Pack (floor flags, capstones, water ripple
mask) and Pizza Doggy's PSX Textures v3.0 (sludge). Prop sprites are crops from Winlu's Fantasy
Dungeon and Fantasy Interior tilesets. Run from anywhere:

    python tools/art/import_sewer.py

Then run a Godot --import pass so the new files get .import files.

Every object crop is checked: no pixel with alpha above 0 may touch the crop edge, so a crop never
clips its object or picks up a neighbour. Tile crops (the floor grate) are whole tiles and skip the
check.
"""
import pathlib
import sys

from PIL import Image

PROJECT = pathlib.Path(__file__).resolve().parents[2]
TEX_OUT = PROJECT / "assets/textures/terrain/sewer"
SPRITE_OUT = PROJECT / "assets/sprites/decor/sewer"

GOLDEN_SKULL = pathlib.Path(
    "F:/UnityNVME/Art/Sprites/Golden Skull/GoldenSkull_3DStarterPack_v01_Textures_PNG/Textures_PNG")
PSX = pathlib.Path("F:/UnityNVME/Art/PSX/PSX Textures v3.0/PSX Textures/256/Color Maps")
DUNGEON = pathlib.Path("F:/UnityNVME/Art/Sprites/Winlu/Winlu Fantasy Dungeon")
INTERIOR = pathlib.Path("F:/UnityNVME/Art/Sprites/Winlu/Winlu Fantasy Interior/Remaster")

TILE_PX = 64

# output name: (source, pixel size, channel multipliers). A texture larger than one tile is a
# field: the ground baker gives each tile its own window of it. The three floor patterns share one
# slab layout with different slab shades, so the baker's per-tile pick varies the shading while the
# joints line up with the board grid (one slab per tile at 128 px).
COOL_STONE = (0.62, 0.68, 0.74)
TEXTURES = {
    "floor_a": (GOLDEN_SKULL / "T_Stone_Pattern_01.png", 2 * TILE_PX, COOL_STONE),
    "floor_b": (GOLDEN_SKULL / "T_Stone_Pattern_04.png", 2 * TILE_PX, COOL_STONE),
    "floor_c": (GOLDEN_SKULL / "T_Stone_Pattern_05.png", 2 * TILE_PX, COOL_STONE),
    "cap": (GOLDEN_SKULL / "T_Stone_01.png", TILE_PX, (0.55, 0.58, 0.62)),
    "sludge": (PSX / "water_3.png", 4 * TILE_PX, (0.56, 0.68, 0.50)),
}

# Greyscale ripple mask the water shader scrolls along a channel.
WATER_FLOW = ("water_flow", GOLDEN_SKULL / "T_Water_01.png", 2 * TILE_PX)

# output name: (sheet, crop box, kind). Kinds: "object" (edge-checked), "tile" (whole tile),
# "glowless" (alpha below 200 cleared first: the sheet bakes a soft glow round the flame, which the
# torch's own light replaces).
SPRITES = {
    # Wall torch, three flicker frames. One box for all three keeps the frames aligned.
    "torch_0": (DUNGEON / "characters/!Decoration.png", (449, 129, 465, 169), "glowless"),
    "torch_1": (DUNGEON / "characters/!Decoration.png", (497, 129, 513, 169), "glowless"),
    "torch_2": (DUNGEON / "characters/!Decoration.png", (545, 129, 561, 169), "glowless"),
    # Wall pipes pouring sludge (bright green) and drain water (murky green), two frames each.
    "pipe_sludge_0": (DUNGEON / "characters/!Decoration_4.png", (5, 203, 44, 263), "object"),
    "pipe_sludge_1": (DUNGEON / "characters/!Decoration_4.png", (101, 203, 140, 263), "object"),
    "pipe_water_0": (DUNGEON / "characters/!Decoration_4.png", (5, 395, 44, 455), "object"),
    "pipe_water_1": (DUNGEON / "characters/!Decoration_4.png", (101, 395, 140, 455), "object"),
    # Floor drain grate: one whole 48 px tile with its own frame.
    "grate": (DUNGEON / "tilesets/Fantasy_Dungeon_A5.png", (144, 0, 192, 48), "tile"),
    # Puddles: the full blobs of two A2 autotiles.
    "puddle_small": (DUNGEON / "tilesets/Fantasy_Dungeon_A2.png", (587, 296, 619, 329), "object"),
    "puddle_large": (DUNGEON / "tilesets/Fantasy_Dungeon_A2.png", (580, 342, 672, 431), "object"),
    "slime": (DUNGEON / "tilesets/Fantasy_Dungeon_A2.png", (581, 202, 670, 281), "object"),
    # Bones.
    "skeleton": (DUNGEON / "tilesets/Fantasy_Dungeon_E.png", (726, 201, 763, 238), "object"),
    "skull_pile": (DUNGEON / "tilesets/Fantasy_Dungeon_E.png", (623, 186, 673, 224), "object"),
    "skull": (DUNGEON / "tilesets/Fantasy_Dungeon_E.png", (534, 103, 564, 126), "object"),
    "skull_ribs": (DUNGEON / "tilesets/Fantasy_Dungeon_E.png", (480, 159, 521, 188), "object"),
    # Rubble and fallen masonry.
    "rubble_pile": (DUNGEON / "tilesets/Fantasy_Dungeon_B.png", (12, 559, 82, 604), "object"),
    "stones": (DUNGEON / "tilesets/Fantasy_Dungeon_B.png", (103, 201, 140, 233), "object"),
    "block": (DUNGEON / "tilesets/Fantasy_Dungeon_C.png", (719, 605, 753, 625), "object"),
    "block_small": (DUNGEON / "tilesets/Fantasy_Dungeon_C.png", (690, 590, 715, 614), "object"),
    # The far-wall sigil (Encounter 4): the unlit carving and its glowing frame for the pulse.
    "sigil": (INTERIOR / "characters/!$symbol.png", (10, 10, 134, 134), "object"),
    "sigil_glow": (INTERIOR / "characters/!$symbol.png", (0, 144, 144, 288), "object"),
    # The dead truth-seeker's things beside the skeleton (Scene 4): a closed book and a knife, both
    # drawn lying flat, seen from above.
    "journal": (INTERIOR / "tilesets/Fantasy_Inside_D.png", (295, 489, 329, 523), "object"),
    "dagger": (INTERIOR / "tilesets/Fantasy_Inside_D.png", (62, 495, 89, 520), "object"),
}


def grade(image: Image.Image, multipliers) -> Image.Image:
    channels = image.convert("RGB").split()
    return Image.merge("RGB", [
        channel.point(lambda v, k=k: min(255, int(v * k))) for channel, k in zip(channels, multipliers)
    ])


def edge_clear(image: Image.Image) -> bool:
    alpha = image.getchannel("A")
    w, h = image.size
    border = [alpha.getpixel((x, 0)) for x in range(w)] + [alpha.getpixel((x, h - 1)) for x in range(w)]
    border += [alpha.getpixel((0, y)) for y in range(h)] + [alpha.getpixel((w - 1, y)) for y in range(h)]
    return max(border) == 0


def main() -> int:
    TEX_OUT.mkdir(parents=True, exist_ok=True)
    SPRITE_OUT.mkdir(parents=True, exist_ok=True)

    for name, (source, size, multipliers) in TEXTURES.items():
        grade(Image.open(source), multipliers).resize((size, size), Image.LANCZOS).save(TEX_OUT / f"{name}.png")
    name, source, size = WATER_FLOW
    Image.open(source).convert("L").resize((size, size), Image.LANCZOS).save(TEX_OUT / f"{name}.png")

    failures = []
    for name, (sheet, box, kind) in SPRITES.items():
        crop = Image.open(sheet).convert("RGBA").crop(box)
        if kind == "glowless":
            alpha = crop.getchannel("A").point(lambda v: v if v >= 200 else 0)
            crop.putalpha(alpha)
        if kind != "tile" and not edge_clear(crop):
            failures.append(f"{name}: an opaque pixel touches the crop edge {box}")
        crop.save(SPRITE_OUT / f"{name}.png")

    for line in failures:
        print("FAIL", line)
    print(f"wrote {len(TEXTURES) + 1} textures to {TEX_OUT} and {len(SPRITES)} sprites to {SPRITE_OUT}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
