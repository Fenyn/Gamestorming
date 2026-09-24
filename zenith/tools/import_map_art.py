"""Copies the adventure map's art out of the local art library into assets/adventure_map/,
cropped and scaled for the map screen, and writes SOURCES.md naming every file's origin.

    python tools/import_map_art.py [--art F:/UnityNVME/Art]

Run it again after changing a pick below; it rewrites the whole folder. Nothing here is generated:
every pixel comes from a licensed pack in the library (see SOURCES.md for the licences).
"""
import argparse
import os
import re
import shutil

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "adventure_map")

BORDERLESS = "Sprites/HexMaps/isle-of-lore-2-hex-tiles-regular-borderless/Isle of Lore 2 - Borderless"
HEX_OUTPUT = "Sprites/HexMaps/isle-of-lore-2-hex-tiles-regular-final/Sources/output"
ORNATE = "Sprites/Ornate Fantasy UI Assets v1.3/Ornate Fantasy UI Assets v1.3/SpriteSheets"

## Terrain per act: pointy hex tile folders and how many variants of each to take. The map picks
## uniformly from the files, so the counts set the mix. Calm ground dominates so the roads and
## markers read; the busy tiles (forest, mountains) are accents.
ACT_TERRAIN = {
    "act1": [("meadow_sparse.green", 6), ("meadow_clearing.green", 6), ("hills_sparse.green", 4),
             ("oak_forest_sparse.green", 3)],
    "act2": [("swamp_clearing.green", 6), ("swamp_sparse.green", 5), ("pine_forest_sparse.green", 3),
             ("mixed_forest_dense.green", 2)],
    "act3": [("hills_sparse.winter", 6), ("valley_sparse.winter", 4), ("grassland_sparse.winter", 3),
             ("pine_forest_sparse.winter", 3), ("mountain_hills.winter", 2)],
}
## The 840 px canvas is kept whole so trees that poke past the hex still show; scaled to this.
TILE_SIZE = 210

## Node type -> location marker.
MARKERS = {
    "duel": "location_battlefield_26",
    "elite": "location_military_tent_25",
    "key": "location_chapel_16",
    "boss": "location_castle_15",
    "twist": "location_witch_hut_7",
    "encounter": "location_campfire_22",
    "sensei": "location_tower_10",
    "shop": "location_inn_12",
    "shrine": "location_sanctuary_23",
    "forge": "location_mine_19",
    "mystery": "location_dungeon_18",
}
MARKER_SIZE = 160

## Badge name -> flair.
FLAIRS = {
    "key": "flair_exclamation_mark_3",
    "elite": "flair_horned_skull_5",
    "boss": "flair_crowned_skull_6",
    "grant": "flair_sun_16",
    "mystery": "flair_question_mark_2",
}
FLAIR_SIZE = 64

## Ornate UI pieces: sheet and (x, y, w, h), doubled with nearest filtering so the pixel art stays
## crisp at screen size, and turned to neutral greys (brightest pixel to white) so a screen can tint
## them. The adventure tints them to the run's school; anywhere else they stay white.
UI_SCALE = 2
GOLD = "GoldWoodFantasyUISheet.png"
LIGHT = "LightFantasyUISheet.png"
ORNATE_PIECES = {
    "banner": (GOLD, (20, 292, 112, 32)),
    "banner_tan": (GOLD, (20, 324, 111, 32)),
    # Filigree and wood motifs: a crest to sit over a heading, swirls for dividers, and a branch
    # rail that tiles along a line.
    "crest": (GOLD, (171, 543, 34, 17)),
    "crest_small": (GOLD, (133, 547, 30, 13)),
    "swirl": (GOLD, (165, 565, 46, 15)),
    "branch": (GOLD, (212, 485, 48, 15)),
    "corner_tl": (GOLD, (548, 212, 12, 13)),
    "corner_tr": (GOLD, (568, 212, 12, 13)),
    "corner_bl": (GOLD, (548, 231, 12, 13)),
    "corner_br": (GOLD, (568, 231, 12, 13)),
}

## Kenney Fantasy UI Borders (CC0): white line art, made to be tinted. Every set is copied, doubled,
## to assets/ui/borders/<style>/<set>/ so any screen can pick a variant. The adventure's default
## frame is the Default style's inner rule, border 012, and two panels are composed from it.
KENNEY = "Sprites/UI/kenney_fantasy-ui-borders/PNG"
KENNEY_OUT = os.path.join(HERE, "..", "assets", "ui", "borders")
DEFAULT_BORDER = "Default/Border/panel-border-012.png"
## The side panels: a neutral dark fill under a white rule, both tinted together.
PANEL_FILL = (54, 54, 58, 238)
## The map board: parchment with an inked rule, never tinted.
BOARD_FILL = (208, 196, 164, 255)
BOARD_INK = (92, 64, 40, 255)
## Buttons: Kenney's stepped-corner rule over a flat fill, one piece per state, never tinted.
## Ordinary buttons are dark with a light rule; the one primary action on a screen is ivory with
## a dark rule. name -> (fill, line).
BUTTON_BORDER = "Default/Border/panel-border-022.png"
BUTTON_PIECES = {
    "button_normal": ((46, 46, 50, 242), (196, 192, 184, 255)),
    "button_hover": ((72, 72, 76, 246), (255, 255, 255, 255)),
    "button_pressed": ((32, 32, 35, 246), (255, 255, 255, 255)),
    "button_disabled": ((40, 40, 43, 200), (96, 96, 96, 255)),
    "accent_normal": ((208, 202, 190, 255), (58, 54, 48, 255)),
    "accent_hover": ((230, 225, 214, 255), (36, 33, 29, 255)),
    "accent_pressed": ((178, 172, 160, 255), (36, 33, 29, 255)),
}

## Card face rules: Kenney borders scaled up so a line survives the card face (512 px) being drawn
## at a quarter of that in hand, each scaled so its lines land inside the face's 18 px colour
## band. Transparent centres; CardFace tints them. name -> (source, scale); the 96 px Double
## sources need half the scale of the 48 px Default ones.
CARD_RULE_OUT = os.path.join(HERE, "..", "assets", "ui", "card_rules")
CARD_RULES = {
    "inner_rule": ("Default/Border/panel-border-012.png", 3),
    "double": ("Double/Border/panel-border-000.png", 1),
    "notched": ("Default/Border/panel-border-003.png", 2),
}

## Single icons copied whole: name -> path under the art library.
ICONS = {
    "mote": "Sprites/Raven Megapack/Treasure, Currency, Gems and Loot/64X64/44.png",
}


def natural(name):
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", name)]


def crop_to_content(im, pad):
    box = im.getchannel("A").getbbox()
    if box is None:
        return im
    x0, y0, x1, y1 = box
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def fit(im, size):
    scale = size / max(im.width, im.height)
    return im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)


def find_png(folder, stem):
    for name in os.listdir(folder):
        if name.startswith(stem) and name.endswith(".png"):
            return os.path.join(folder, name)
    raise FileNotFoundError("%s in %s" % (stem, folder))


def neutral(im):
    """The same art in greys, scaled so its brightest opaque pixel is white; alpha untouched."""
    im = im.convert("RGBA")
    grey = im.convert("L")
    alpha = im.getchannel("A")
    opaque = alpha.point(lambda a: 255 if a > 0 else 0)
    peak = Image.composite(grey, Image.new("L", grey.size, 0), opaque).getextrema()[1] or 255
    grey = grey.point(lambda v: min(255, round(v * 255 / peak)))
    out = Image.merge("RGBA", (grey, grey, grey, alpha))
    return out


def compose_panel(border, fill, line):
    """A filled panel: `fill` under the border's lines recoloured to `line`."""
    base = Image.new("RGBA", border.size, fill)
    lines = Image.new("RGBA", border.size, line)
    lines.putalpha(border.getchannel("A"))
    base.alpha_composite(lines)
    return base


def compose_button(border, fill, line):
    """A button face: `fill` inside the border's outline only (the stepped corners stay clear),
    under the border's lines recoloured to `line`."""
    lines_mask = border.getchannel("A").point(lambda a: 255 if a > 0 else 0)
    region = lines_mask.copy()
    ImageDraw.floodfill(region, (region.width // 2, region.height // 2), 128)
    inside = region.point(lambda v: 255 if v > 0 else 0)
    base = Image.new("RGBA", border.size, (0, 0, 0, 0))
    base.paste(Image.new("RGBA", border.size, fill), mask=inside)
    lines = Image.new("RGBA", border.size, line)
    lines.putalpha(lines_mask)
    base.alpha_composite(lines)
    return base


def import_kenney(art, rows):
    if os.path.isdir(KENNEY_OUT):
        shutil.rmtree(KENNEY_OUT)
    count = 0
    for style in sorted(os.listdir(os.path.join(art, KENNEY))):
        for set_name in sorted(os.listdir(os.path.join(art, KENNEY, style))):
            src_dir = os.path.join(art, KENNEY, style, set_name)
            if not os.path.isdir(src_dir):
                continue
            dest_dir = os.path.join(KENNEY_OUT, style.lower(), set_name.lower().replace(" ", "_"))
            os.makedirs(dest_dir)
            for name in sorted(os.listdir(src_dir)):
                if name.endswith(".png"):
                    im = Image.open(os.path.join(src_dir, name)).convert("RGBA")
                    im.resize((im.width * UI_SCALE, im.height * UI_SCALE), Image.NEAREST).save(os.path.join(dest_dir, name))
                    count += 1
    with open(os.path.join(KENNEY_OUT, "SOURCES.md"), "w", encoding="utf-8") as f:
        f.write("# UI border sources\n\n")
        f.write("Written by `tools/import_map_art.py`: every set of Kenney's Fantasy UI Borders 1.0 from ")
        f.write("`F:/UnityNVME/Art/%s/`, doubled with nearest filtering. White line art, meant to be " % KENNEY)
        f.write("tinted. Licence: Creative Commons Zero (CC0); crediting Kenney (www.kenney.nl) is ")
        f.write("appreciated, not required.\n")
    rows.append(("../ui/borders/ (%d files)" % count, KENNEY))
    border = Image.open(os.path.join(art, KENNEY, DEFAULT_BORDER)).convert("RGBA")
    border = border.resize((border.width * UI_SCALE, border.height * UI_SCALE), Image.NEAREST)
    compose_panel(border, PANEL_FILL, (255, 255, 255, 255)).save(os.path.join(OUT, "ui", "panel.png"))
    compose_panel(border, BOARD_FILL, BOARD_INK).save(os.path.join(OUT, "ui", "board.png"))
    button = Image.open(os.path.join(art, KENNEY, BUTTON_BORDER)).convert("RGBA")
    button = button.resize((button.width * UI_SCALE, button.height * UI_SCALE), Image.NEAREST)
    for name, (fill, line) in BUTTON_PIECES.items():
        compose_button(button, fill, line).save(os.path.join(OUT, "ui", name + ".png"))
        rows.append(("ui/%s.png" % name, "%s, over a flat fill" % BUTTON_BORDER))
    if os.path.isdir(CARD_RULE_OUT):
        shutil.rmtree(CARD_RULE_OUT)
    os.makedirs(CARD_RULE_OUT)
    for name, (rel, scale) in CARD_RULES.items():
        rule = Image.open(os.path.join(art, KENNEY, rel)).convert("RGBA")
        rule.resize((rule.width * scale, rule.height * scale), Image.NEAREST).save(
            os.path.join(CARD_RULE_OUT, name + ".png"))
    with open(os.path.join(CARD_RULE_OUT, "SOURCES.md"), "w", encoding="utf-8") as f:
        f.write("# Card rule sources\n\nWritten by `tools/import_map_art.py`: Kenney Fantasy UI Borders 1.0 (CC0), ")
        f.write("scaled with nearest filtering, white, for `CardFace` to tint.\n\n")
        for name, (rel, scale) in CARD_RULES.items():
            f.write("- `%s.png`: `%s/%s` at %dx\n" % (name, KENNEY, rel, scale))
    rows.append(("ui/panel.png", "%s, over a neutral dark fill" % DEFAULT_BORDER))
    rows.append(("ui/board.png", "%s, inked, over a parchment fill" % DEFAULT_BORDER))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--art", default="F:/UnityNVME/Art")
    args = parser.parse_args()
    art = args.art
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    rows = []

    for act, folders in ACT_TERRAIN.items():
        os.makedirs(os.path.join(OUT, "terrain", act))
        for folder, count in folders:
            src_dir = os.path.join(art, BORDERLESS, "pointy." + folder)
            names = sorted([n for n in os.listdir(src_dir) if n.endswith(".png")], key=natural)
            for name in names[:count]:
                im = Image.open(os.path.join(src_dir, name)).convert("RGBA")
                im = im.resize((TILE_SIZE, TILE_SIZE), Image.LANCZOS)
                out_name = "%s_%s" % (folder.replace(".", "_"), name)
                im.save(os.path.join(OUT, "terrain", act, out_name))
                rows.append(("terrain/%s/%s" % (act, out_name), "%s/pointy.%s/%s" % (BORDERLESS, folder, name)))

    os.makedirs(os.path.join(OUT, "markers"))
    loc_dir = os.path.join(art, HEX_OUTPUT, "tiles", "overlay_locations.standard_full")
    for node_type, stem in MARKERS.items():
        path = find_png(loc_dir, stem)
        im = fit(crop_to_content(Image.open(path).convert("RGBA"), 6), MARKER_SIZE)
        im.save(os.path.join(OUT, "markers", node_type + ".png"))
        rows.append(("markers/%s.png" % node_type, os.path.relpath(path, art).replace("\\", "/")))

    os.makedirs(os.path.join(OUT, "flairs"))
    flair_dir = os.path.join(art, HEX_OUTPUT, "tiles", "pointy.overlay_flairs.standard")
    for badge, stem in FLAIRS.items():
        path = find_png(flair_dir, stem)
        im = fit(crop_to_content(Image.open(path).convert("RGBA"), 2), FLAIR_SIZE)
        im.save(os.path.join(OUT, "flairs", badge + ".png"))
        rows.append(("flairs/%s.png" % badge, os.path.relpath(path, art).replace("\\", "/")))

    os.makedirs(os.path.join(OUT, "ui"))
    sheets = {}
    for piece, (sheet_name, (x, y, w, h)) in ORNATE_PIECES.items():
        if sheet_name not in sheets:
            sheets[sheet_name] = Image.open(os.path.join(art, ORNATE, sheet_name)).convert("RGBA")
        piece_im = sheets[sheet_name].crop((x, y, x + w, y + h)).resize((w * UI_SCALE, h * UI_SCALE), Image.NEAREST)
        neutral(piece_im).save(os.path.join(OUT, "ui", piece + ".png"))
        rows.append(("ui/%s.png" % piece, "%s/%s at (%d, %d), %d x %d, doubled, greyed" % (ORNATE, sheet_name, x, y, w, h)))

    import_kenney(art, rows)

    for name, rel in ICONS.items():
        shutil.copyfile(os.path.join(art, rel), os.path.join(OUT, "ui", name + ".png"))
        rows.append(("ui/%s.png" % name, rel))

    with open(os.path.join(OUT, "SOURCES.md"), "w", encoding="utf-8") as f:
        f.write("# Adventure map art sources\n\n")
        f.write("Written by `tools/import_map_art.py` from the local art library under `F:/UnityNVME/Art/`. ")
        f.write("Nothing here is generated. Re-run the tool rather than editing these files by hand.\n\n")
        f.write("Licences:\n\n")
        f.write("- Isle of Lore 2 hex tiles, markers and flairs: Steven Colling Game Asset License 1.0. ")
        f.write("Commercial use and modification allowed, no attribution required; the assets may not be ")
        f.write("redistributed on their own.\n")
        f.write("- Ornate Fantasy UI Assets v1.3: personal or commercial use, modification allowed ")
        f.write("(`LICENSE.rtf` in the pack).\n")
        f.write("- Kenney Fantasy UI Borders 1.0: CC0.\n")
        f.write("- Raven Megapack (Clockwork Raven Studios): a purchased pack. It ships no licence file, only ")
        f.write("a note from the artist; check the store's terms before release.\n\n")
        f.write("| Project file | Source under `F:/UnityNVME/Art/` |\n|---|---|\n")
        for dest, src in rows:
            f.write("| `%s` | `%s` |\n" % (dest, src))
    print("wrote %d files to %s" % (len(rows), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
