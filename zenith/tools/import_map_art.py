"""Copies the adventure screens' art out of the local art library into assets/adventure_map/,
composed and scaled for the screens, and writes SOURCES.md naming every file's origin.

    python tools/import_map_art.py [--art F:/UnityNVME/Art]

Run it again after changing a pick below; it rewrites the whole folder. Nothing here is generated:
every pixel comes from a licensed pack in the library (see SOURCES.md for the licences).
"""
import argparse
import os
import shutil

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "adventure_map")

ORNATE = "Sprites/Ornate Fantasy UI Assets v1.3/Ornate Fantasy UI Assets v1.3/SpriteSheets"
## Kenney Board Game Icons (CC0): solid white icons, 128 px.
KENNEY_ICONS = "Sprites/UI/kenney_board-game-icons/PNG/Double (128px)"

## Map nodes: a Kenney icon on a dark tile under the button rule (border 022), so a node reads as
## something to click. The boss gets the Double style's rule and a larger tile. Node type -> icon.
MARKER_ICONS = {
    "duel": "sword",
    "elite": "skull",
    "key": "character",
    "boss": "crown_b",
    "twist": "dice_question",
    "encounter": "campfire",
    "sensei": "book_open",
    "shop": "pouch",
    "shrine": "fire",
    "forge": "resource_iron",
    "mystery": "hexagon_question",
}
MARKER_BORDER = "Default/Border/panel-border-022.png"   # 48 px, taken at 3x
BOSS_BORDER = "Double/Border/panel-border-000.png"      # 96 px, taken at 2x
MARKER_FILL = (40, 40, 44, 246)
MARKER_LINE = (196, 192, 184, 255)
MARKER_ICON = (238, 234, 226, 255)
## The icon's share of the tile's side.
MARKER_ICON_SHARE = 0.56

## Badges pinned to a node's corner: a small icon on a round dark chip. Badge name -> icon.
FLAIR_ICONS = {
    "grant": "award",
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
    # Filigree: a crest to sit over a heading and a swirl for the title screen.
    "crest": (GOLD, (171, 543, 34, 17)),
    "crest_small": (GOLD, (133, 547, 30, 13)),
    "swirl": (GOLD, (165, 565, 46, 15)),
}

## Kenney Fantasy UI Borders (CC0): white line art, made to be tinted. Every set is copied, doubled,
## to assets/ui/borders/<style>/<set>/ so any screen can pick a variant. The adventure's default
## frame is the Default style's inner rule, border 012, and two panels are composed from it.
KENNEY = "Sprites/UI/kenney_fantasy-ui-borders/PNG"
KENNEY_OUT = os.path.join(HERE, "..", "assets", "ui", "borders")
DEFAULT_BORDER = "Default/Border/panel-border-012.png"
## The side panels and the map board: a neutral dark fill under a white rule, both tinted together.
PANEL_FILL = (54, 54, 58, 238)
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


def fit(im, size):
    scale = size / max(im.width, im.height)
    return im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)


def recolour(icon, colour):
    """A white icon in `colour`, keeping its alpha."""
    out = Image.new("RGBA", icon.size, colour)
    out.putalpha(Image.eval(icon.getchannel("A"), lambda a: a * colour[3] // 255))
    return out


def compose_marker(border, icon):
    """A node marker: the icon centred on a dark tile under the border's rule."""
    tile = compose_button(border, MARKER_FILL, MARKER_LINE)
    glyph = recolour(fit(icon, round(tile.width * MARKER_ICON_SHARE)), MARKER_ICON)
    tile.alpha_composite(glyph, ((tile.width - glyph.width) // 2, (tile.height - glyph.height) // 2))
    return tile


def compose_flair(icon):
    """A badge: the icon on a round dark chip with a light edge."""
    chip = Image.new("RGBA", (FLAIR_SIZE, FLAIR_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(chip)
    draw.ellipse((1, 1, FLAIR_SIZE - 2, FLAIR_SIZE - 2), fill=MARKER_FILL, outline=MARKER_LINE, width=4)
    glyph = recolour(fit(icon, round(FLAIR_SIZE * 0.6)), MARKER_ICON)
    chip.alpha_composite(glyph, ((FLAIR_SIZE - glyph.width) // 2, (FLAIR_SIZE - glyph.height) // 2))
    return chip


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


def import_markers(art, rows):
    os.makedirs(os.path.join(OUT, "markers"))
    tile = Image.open(os.path.join(art, KENNEY, MARKER_BORDER)).convert("RGBA")
    tile = tile.resize((tile.width * 3, tile.height * 3), Image.NEAREST)
    boss = Image.open(os.path.join(art, KENNEY, BOSS_BORDER)).convert("RGBA")
    boss = boss.resize((boss.width * 2, boss.height * 2), Image.NEAREST)
    for node_type, name in MARKER_ICONS.items():
        rel = "%s/%s.png" % (KENNEY_ICONS, name)
        icon = Image.open(os.path.join(art, rel)).convert("RGBA")
        compose_marker(boss if node_type == "boss" else tile, icon).save(os.path.join(OUT, "markers", node_type + ".png"))
        rows.append(("markers/%s.png" % node_type, "%s on %s" % (rel, BOSS_BORDER if node_type == "boss" else MARKER_BORDER)))
    os.makedirs(os.path.join(OUT, "flairs"))
    for badge, name in FLAIR_ICONS.items():
        rel = "%s/%s.png" % (KENNEY_ICONS, name)
        compose_flair(Image.open(os.path.join(art, rel)).convert("RGBA")).save(os.path.join(OUT, "flairs", badge + ".png"))
        rows.append(("flairs/%s.png" % badge, "%s on a round chip" % rel))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--art", default="F:/UnityNVME/Art")
    args = parser.parse_args()
    art = args.art
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    rows = []
    os.makedirs(OUT)
    import_markers(art, rows)

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
        f.write("- Ornate Fantasy UI Assets v1.3: personal or commercial use, modification allowed ")
        f.write("(`LICENSE.rtf` in the pack).\n")
        f.write("- Kenney Fantasy UI Borders 1.0 and Kenney Board Game Icons 1.1: CC0.\n")
        f.write("- Raven Megapack (Clockwork Raven Studios): a purchased pack. It ships no licence file, only ")
        f.write("a note from the artist; check the store's terms before release.\n\n")
        f.write("| Project file | Source under `F:/UnityNVME/Art/` |\n|---|---|\n")
        for dest, src in rows:
            f.write("| `%s` | `%s` |\n" % (dest, src))
    print("wrote %d files to %s" % (len(rows), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
