"""Bake Kenney Fantasy UI Borders (CC0) into palette-coloured nine-patch PNGs.

Run with Python 3 and Pillow. Reads F:/UnityNVME/Art/Sprites/UI/kenney_fantasy-ui-borders and
writes assets/ui/kenney/. Colours come from the Palette block of assets/ui/ui_theme.tres. Pieces
stay at 1x: the 2 px Kenney stroke matches a Pixeloid 18 font pixel.
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
KENNEY = Path("F:/UnityNVME/Art/Sprites/UI/kenney_fantasy-ui-borders/PNG/Default")
OUT = ROOT / "assets" / "ui" / "kenney"
THEME = ROOT / "assets" / "ui" / "ui_theme.tres"



def palette():
    colours = {}
    for name, values in re.findall(r"Palette/colors/(\w+) = Color\(([^)]*)\)", THEME.read_text(encoding="utf-8")):
        colours[name] = tuple(round(float(v) * 255) for v in values.split(","))
    return colours


def load(rel):
    return Image.open(KENNEY / rel).convert("RGBA")


def lines_in(border, colour):
    lines = Image.new("RGBA", border.size, colour)
    lines.putalpha(border.getchannel("A"))
    return lines


def inside_mask(border):
    """Pixels enclosed by the border's outline, so stepped corners stay clear."""
    region = border.getchannel("A").point(lambda a: 255 if a > 0 else 0)
    ImageDraw.floodfill(region, (region.width // 2, region.height // 2), 128)
    return region.point(lambda v: 255 if v > 0 else 0)


def panel(border, fill, line):
    base = Image.new("RGBA", border.size, (0, 0, 0, 0))
    base.paste(Image.new("RGBA", border.size, fill), mask=inside_mask(border))
    base.alpha_composite(lines_in(border, line))
    return base


def main():
    p = palette()
    OUT.mkdir(parents=True, exist_ok=True)
    frame = load("Border/panel-border-012.png")
    modal = load("Border/panel-border-014.png")
    button = load("Border/panel-border-022.png")
    focus = load("Border/panel-border-000.png")

    pieces = {
        "panel": panel(frame, p["surface"], p["line"]),
        "panel_inset": panel(frame, p["inset"], p["line"]),
        "modal": panel(modal, p["surface"][:3] + (255,), p["accent"]),
        "tooltip": panel(frame, p["recess"], p["line"]),
        "button_normal": panel(button, p["control"], p["rule_bright"]),
        "button_hover": panel(button, p["control_hover"], p["focus"]),
        "button_pressed": panel(button, p["recess"], p["accent"]),
        "button_disabled": panel(button, p["disabled_fill"], p["disabled_line"]),
        "accent_normal": panel(button, p["primary_fill"], p["accent"]),
        "accent_hover": panel(button, p["primary_fill"], p["focus"]),
        "accent_pressed": panel(button, p["recess"], p["accent"]),
        "focus": lines_in(focus, p["focus"]),
        "rule": lines_in(load("Divider Fade/divider-fade-003.png"), p["line"]),
        "rule_accent": lines_in(load("Divider Fade/divider-fade-004.png"), p["accent"]),
    }
    fade = pieces["rule_accent"]
    ornament = Image.new("RGBA", (fade.width * 2, fade.height))
    ornament.alpha_composite(fade, (0, 0))
    ornament.alpha_composite(fade.transpose(Image.FLIP_LEFT_RIGHT), (fade.width, 0))
    pieces["rule_ornament"] = ornament
    for name, image in pieces.items():
        image.save(OUT / f"{name}.png")

    (OUT / "SOURCES.md").write_text(
        "# Kenney chrome\n\n"
        "Written by `tools/art/kenney_chrome.py` from Kenney Fantasy UI Borders 1.0 "
        "(`F:/UnityNVME/Art/Sprites/UI/kenney_fantasy-ui-borders`), Default set at 1x, recoloured from "
        "the ui_theme Palette. Panels use border 012, modals 014, buttons 022, focus 000, rules "
        "divider-fade 003 and 004.\n\n"
        "Licence: Creative Commons Zero (CC0). Crediting Kenney (www.kenney.nl) is appreciated, not required.\n",
        encoding="utf-8",
    )
    print(f"wrote {len(pieces)} pieces to {OUT}")


if __name__ == "__main__":
    main()
