"""Copies the adventure screens' art out of the local art library into assets/adventure_map/,
composed and scaled for the screens, and writes SOURCES.md naming every file's origin.

    python tools/import_map_art.py [--art F:/UnityNVME/Art] [--phase-only | --resonances-only | --frames-only]

Run it again after changing a pick below; it rewrites the whole folder, .import files included,
so `--phase-only` is the way to change a phase track icon, `--resonances-only` a sigil and
`--frames-only` the panel and button faces. Apart from those faces, which are drawn here, every
pixel comes from a licensed pack in the library (see SOURCES.md for the licences).
"""
import argparse
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "adventure_map")

ORNATE = "Sprites/Ornate Fantasy UI Assets v1.3/Ornate Fantasy UI Assets v1.3/SpriteSheets"
## Kenney Board Game Icons (CC0): solid white icons, 128 px.
KENNEY_ICONS = "Sprites/UI/kenney_board-game-icons/PNG/Double (128px)"

## Map nodes: a Kenney icon on a dark tile under Kenney border 001, so a node reads as
## something to click. The boss gets the Double style's rule and a larger tile. Node type -> icon.
MARKER_ICONS = {
    "duel": "sword",
    "elite": "skull",
    "key": "character",
    "boss": "crown_b",
    "twist": "dice_question",
    "encounter": "campfire",
    "relic": "book_open",
    "shop": "pouch",
    "shrine": "fire",
    "forge": "resource_iron",
    "mystery": "hexagon_question",
}
MARKER_BORDER = "Default/Border/panel-border-001.png"   # 48 px, taken at 3x
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
## to assets/ui/borders/<style>/<set>/ so any screen can pick a variant.
KENNEY = "Sprites/UI/kenney_fantasy-ui-borders/PNG"
KENNEY_OUT = os.path.join(HERE, "..", "assets", "ui", "borders")

## The panel and button faces are drawn here, with no outline: a dark fill, a soft drop shadow
## baked round it, and a faint 1 px highlight along the top edge. The shadow lies outside the face,
## so MapArt draws these with expand margins of the shadow pad (keep the numbers in step with
## map_art.gd). Drawn at FRAME_SUPERSAMPLE times the size and scaled down for smooth corners.
FRAME_SUPERSAMPLE = 4
## The panel: one texture, tinted whole by MapArt, so the fill is chosen to land on surface.panel
## under the iron frame tint (designs/zenith_ui.md, frame.metal). A faint rule engraved 5 px inside
## the edge.
PANEL_FILL = (39, 35, 35, 245)
PANEL_RADIUS = 4
PANEL_SHADOW_PAD = 28          # MapArt.PANEL_SHADOW
PANEL_MARGIN = 36              # MapArt.PANEL_MARGIN: the pad plus the corner, rule and highlight
PANEL_SHADOW = ((0, 5), 8, 170)   # offset, blur, alpha
PANEL_RULE = (5, (255, 255, 255, 50))   # inset, colour
PANEL_HIGHLIGHT = (255, 255, 255, 40)
## Buttons, one piece per state, never tinted. Ordinary buttons are a raised dark fill; the one
## primary action on a screen is bone-white. Pressed sinks: no shadow, and a bone rule engraved
## inside, which is also how a toggled button shows it is on.
## name -> (fill, top highlight or None, shadow, engraved rule or None).
BUTTON_RADIUS = 3
BUTTON_SHADOW_PAD = 10         # MapArt.BUTTON_SHADOW
BUTTON_MARGIN = 16             # MapArt.BUTTON_MARGIN
BUTTON_SHADOW = ((0, 2), 3, 120)
BUTTON_RULE_INSET = 3
BUTTON_PIECES = {
    "button_normal": ((46, 43, 42, 255), (255, 255, 255, 26), True, None),
    "button_hover": ((64, 60, 58, 255), (255, 255, 255, 34), True, None),
    "button_pressed": ((30, 28, 28, 255), None, False, (240, 232, 214, 220)),
    "button_disabled": ((32, 30, 30, 200), None, False, None),
    "accent_normal": ((236, 228, 210, 255), (255, 255, 255, 90), True, None),
    "accent_hover": ((250, 245, 234, 255), (255, 255, 255, 110), True, None),
    "accent_pressed": ((206, 198, 180, 255), None, False, (58, 54, 48, 200)),
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

## The duel's phase track printed on the table: step -> Kenney icon, written white for the track
## to tint. Turn start in the left notch, Combat across the ring, turn end in the right notch.
PHASE_OUT = os.path.join(HERE, "..", "assets", "ui", "phase_icons")
PHASE_ICONS = {
    "draw": "card_add",
    "place": "card_place",
    "power_up": "flask_full",
    "declare": "flag_triangle",
    "enter": "arrow_right",
    "attack": "sword",
    "defend": "shield",
    "resolve": "exploding",
    "end": "hourglass_bottom",
    "discard": "card_remove",
    "recover": "cards_return",
    "turn_end": "hourglass",
}

## Resonance sigils (designs/zenith_adventure.md 7.7): cells of the Raven Megapack spell sheet, 16
## columns by 28 rows of 64 px, doubled with nearest filtering. Resonance id -> (row, column).
RESONANCE_OUT = os.path.join(OUT, "resonances")
RESONANCE_SHEET = "Sprites/Raven Megapack/Skills and Spells/icons64x64.png"
RESONANCE_CELL = 64
RESONANCE_SCALE = 2
RESONANCE_CELLS = {
    "iron_resolve": (16, 14),
    "ready_channel": (8, 0),
    "steady_flame": (0, 15),
    "rising_ash": (0, 6),
    "spoils_of_ruin": (20, 8),
    "deep_well": (4, 5),
    "open_hand": (22, 5),
    "first_stone": (16, 15),
    "warband": (20, 3),
    "sealwrights_patience": (12, 15),
    "braced_stance": (22, 2),
    "blood_price": (21, 1),
    "glass_cannon": (0, 13),
    "patient_tide": (3, 11),
}

## Single icons copied whole: name -> path under the art library.
ICONS = {
    "mote": "Sprites/Raven Megapack/Treasure, Currency, Gems and Loot/64X64/44.png",
    "mana": "Sprites/Raven Megapack/Treasure, Currency, Gems and Loot/64X64/45.png",
    # The Forge's two choices, white for the screen to tint.
    "card_remove": KENNEY_ICONS + "/card_remove.png",
    "card_add": KENNEY_ICONS + "/card_add.png",
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


def compose_face(pad, margin, radius, fill, shadow=None, highlight=None, rule=None):
    """A frame face for a nine-slice: a `radius`-cornered `fill` with `pad` pixels round it for
    `shadow` ((dx, dy), blur, alpha), a 1 px `highlight` along its top edge and a 1 px `rule`
    ((inset, colour)) inside it. The face is two margins wide, minus the pads, plus a little to
    stretch."""
    k = FRAME_SUPERSAMPLE
    size = 2 * margin + 8
    face = (pad, pad, size - pad - 1, size - pad - 1)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if shadow:
        (dx, dy), blur, alpha = shadow
        cast = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(cast).rounded_rectangle((face[0] + dx, face[1] + dy, face[2] + dx, face[3] + dy), radius, fill=(0, 0, 0, alpha))
        out.alpha_composite(cast.filter(ImageFilter.GaussianBlur(blur)))
    big = Image.new("RGBA", (size * k, size * k), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    x0, y0, x1, y1 = (v * k for v in face)
    draw.rounded_rectangle((x0, y0, x1 + k - 1, y1 + k - 1), radius * k, fill=fill)
    if highlight:
        draw.rectangle((x0 + radius * k, y0 + k, x1 + k - 1 - radius * k, y0 + 2 * k - 1), fill=highlight)
    if rule:
        inset, colour = rule
        i = inset * k
        draw.rounded_rectangle((x0 + i, y0 + i, x1 + k - 1 - i, y1 + k - 1 - i), max(radius - inset, 1) * k, outline=colour, width=k)
    out.alpha_composite(big.resize((size, size), Image.LANCZOS))
    return out


def import_frames(rows):
    """The panel and button faces, written in place so Godot keeps their .import files."""
    ui = os.path.join(OUT, "ui")
    os.makedirs(ui, exist_ok=True)
    compose_face(PANEL_SHADOW_PAD, PANEL_MARGIN, PANEL_RADIUS, PANEL_FILL, PANEL_SHADOW, PANEL_HIGHLIGHT,
                 PANEL_RULE).save(os.path.join(ui, "panel.png"))
    rows.append(("ui/panel.png", "drawn by the tool: neutral dark fill, engraved rule, drop shadow"))
    for name, (fill, highlight, shadow, rule) in BUTTON_PIECES.items():
        compose_face(BUTTON_SHADOW_PAD, BUTTON_MARGIN, BUTTON_RADIUS, fill, BUTTON_SHADOW if shadow else None,
                     highlight, (BUTTON_RULE_INSET, rule) if rule else None).save(os.path.join(ui, name + ".png"))
        rows.append(("ui/%s.png" % name, "drawn by the tool: flat fill, no outline"))


def compose_button(border, fill, line):
    """A button face: `fill` inside the border's outline only (the corner blocks stay clear),
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
    import_frames(rows)
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


def import_phase_icons(art):
    # Overwritten in place, so Godot keeps each icon's .import file and UID.
    os.makedirs(PHASE_OUT, exist_ok=True)
    for step, name in PHASE_ICONS.items():
        icon = Image.open(os.path.join(art, KENNEY_ICONS, name + ".png")).convert("RGBA")
        recolour(icon, (255, 255, 255, 255)).save(os.path.join(PHASE_OUT, step + ".png"))
    with open(os.path.join(PHASE_OUT, "SOURCES.md"), "w", encoding="utf-8") as f:
        f.write("# Phase track icon sources\n\nWritten by `tools/import_map_art.py`: Kenney Board Game Icons 1.1 ")
        f.write("(CC0), 128 px, written white for the track to tint.\n\n")
        for step, name in PHASE_ICONS.items():
            f.write("- `%s.png`: `%s/%s.png`\n" % (step, KENNEY_ICONS, name))


def import_resonances(art, rows):
    # Overwritten in place, so Godot keeps each sigil's .import file and UID.
    os.makedirs(RESONANCE_OUT, exist_ok=True)
    sheet = Image.open(os.path.join(art, RESONANCE_SHEET)).convert("RGBA")
    for resonance, (row, col) in RESONANCE_CELLS.items():
        x, y = col * RESONANCE_CELL, row * RESONANCE_CELL
        cell = sheet.crop((x, y, x + RESONANCE_CELL, y + RESONANCE_CELL))
        side = RESONANCE_CELL * RESONANCE_SCALE
        cell.resize((side, side), Image.NEAREST).save(os.path.join(RESONANCE_OUT, resonance + ".png"))
        rows.append(("resonances/%s.png" % resonance, "%s, row %d, column %d, doubled" % (RESONANCE_SHEET, row, col)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--art", default="F:/UnityNVME/Art")
    parser.add_argument("--phase-only", action="store_true",
                        help="rewrite only assets/ui/phase_icons, leaving the other folders and their .import files alone")
    parser.add_argument("--resonances-only", action="store_true",
                        help="rewrite only assets/adventure_map/resonances, leaving the other folders and SOURCES.md alone")
    parser.add_argument("--frames-only", action="store_true",
                        help="rewrite only the panel and button faces in assets/adventure_map/ui, leaving the rest and SOURCES.md alone")
    args = parser.parse_args()
    art = args.art
    if args.frames_only:
        import_frames([])
        print("wrote the panel and %d button faces to %s" % (len(BUTTON_PIECES), os.path.normpath(os.path.join(OUT, "ui"))))
        return
    if args.phase_only:
        import_phase_icons(art)
        print("wrote %d phase icons to %s" % (len(PHASE_ICONS), os.path.normpath(PHASE_OUT)))
        return
    if args.resonances_only:
        import_resonances(art, [])
        print("wrote %d Resonance sigils to %s" % (len(RESONANCE_CELLS), os.path.normpath(RESONANCE_OUT)))
        return
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
    import_phase_icons(art)
    import_resonances(art, rows)

    for name, rel in ICONS.items():
        shutil.copyfile(os.path.join(art, rel), os.path.join(OUT, "ui", name + ".png"))
        rows.append(("ui/%s.png" % name, rel))

    with open(os.path.join(OUT, "SOURCES.md"), "w", encoding="utf-8") as f:
        f.write("# Adventure map art sources\n\n")
        f.write("Written by `tools/import_map_art.py` from the local art library under `F:/UnityNVME/Art/`. ")
        f.write("Only the panel and button faces are drawn by the tool. Re-run it rather than editing these files by hand.\n\n")
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
