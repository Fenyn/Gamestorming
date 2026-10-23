"""Write the skin, hair, eyes and cloth colour codes of <Extended>/authored/colours.json.

Each new code is an explicit ramp below. Skin, hair and eyes map each _c1 colour to a fixed ramp
step (the pack uses one palette per family). Cloth styles each use their own _c1 palette, so cloth
maps every crimson dye colour to the ramp step nearest its luminance and keeps trims, leather,
metal and gems as they are. Other top-level keys in colours.json are kept.

    python make_colours.py <purchased FaceGen> <authored folder>
"""
import colorsys
import json
import os
import re
import sys
from PIL import Image

VARIANT = re.compile(r"^(?P<stem>.+)_c1(_top|_bot)?\.png$")

# Skin: base, face and jaw. Steps follow the _c1 colours below, dark to light.
SKIN_C1 = ["#32171a", "#522c2c", "#885038", "#954e30", "#b1704f",
           "#c17353", "#d08860", "#e3aa7b", "#eebe8a", "#f8d098"]
# Positions 3 and 5 are the mouth interior (dark, light); the rest is the skin ramp.
SKIN = {
    "c7": ("umber", ["#2a1410", "#3e2018", "#5e3222", "#5a1e18", "#7a4630", "#7c3226", "#93583a", "#ab7048", "#b67b51", "#c0865a"]),
    "c8": ("olive", ["#2a1a14", "#433020", "#6a4c32", "#6a2a22", "#8e6644", "#94463a", "#aa7c56", "#bf9068", "#c89a70", "#d0a47a"]),
    "c9": ("fair", ["#321a24", "#583440", "#8c5c5e", "#8a3442", "#b07e78", "#b25a5e", "#cc9c8e", "#e2bca8", "#ebc9b6", "#f4d8c4"]),
    "c10": ("ruddy", ["#34141a", "#5a2628", "#8c4234", "#6a1c1c", "#b05e48", "#963830", "#c8745a", "#da9674", "#e2a582", "#eab38e"]),
}

# Hair and beard. Eight-step ramp, then the five ornament colours of hair m7.
HAIR_RAMP_C1 = ["#17020b", "#470d26", "#711733", "#922c3f", "#b8464f", "#d65f60", "#e57370", "#f38b84"]
HAIR_EXTRA_C1 = ["#895e5e", "#af8c83", "#b9c1b2", "#d2dcce", "#eef9ed"]
HAIR_OUTLINE_C1 = "#0e1026"  # m7 outline, follows ramp step 0 like every pack code
HAIR_FIXED = ["#523a31"]  # m2 hair tie, the same in every pack code
HAIR = {
    "c11": ("raven", ["#09090f", "#131724", "#1d2333", "#283044", "#374157", "#48546b", "#58667e", "#6c7c94"],
            ["#5c6470", "#808894", "#a8b0b8", "#c8ced2", "#e8ecee"]),
    "c12": ("ash", ["#1c1a1f", "#363439", "#524f53", "#706d6f", "#918e8d", "#afaca8", "#c5c2bc", "#dbd8d0"],
            ["#8a8886", "#aeacaa", "#c8c6c2", "#dedcd8", "#f2f0ea"]),
    "c13": ("copper", ["#1a0807", "#3c120d", "#5e1e13", "#82301a", "#a44822", "#c0622d", "#d07839", "#de924b"],
            ["#8a5a48", "#b08068", "#c8aa98", "#ddd0c4", "#f2ece4"]),
    "c14": ("chestnut", ["#140808", "#2c120e", "#461f15", "#62301e", "#7e4428", "#985a34", "#aa6c40", "#bc8050"],
            ["#7a5e52", "#a08274", "#bea898", "#d8ccc0", "#eee8e0"]),
    "c15": ("flaxen", ["#2a1a10", "#54381e", "#7a5a2e", "#9c7c40", "#ba9c58", "#d0b670", "#dec886", "#ead8a0"],
            ["#9a8c70", "#bcae92", "#d4cab2", "#e6e0d0", "#f6f4ea"]),
}

# Eyes: three iris steps; the whites stay.
EYES_C1 = ["#760a09", "#a81e1d", "#ff0000"]
EYES_FIXED = ["#d6d3e2", "#ffffff"]
EYES = {
    "c8": ("brown", ["#341a0c", "#5e3214", "#8a4e1c"]),
    "c9": ("hazel", ["#36300e", "#5e6420", "#8e9a34"]),
    "c10": ("steel", ["#2a3850", "#4a6486", "#7c9cc0"]),
}

# Cloth: twelve steps, darkest first. A dye colour of luminance L takes step round(L / CLOTH_STEP_L)
# (raised past the step below it within the same style, so no two shades of a style merge).
CLOTH_STEP_L = 12
CLOTH = {
    "c9": ("linen", ["#1c1618", "#2e2426", "#433632", "#5a4a40", "#70604e", "#86765e", "#988870",
                     "#a8987e", "#b6a88c", "#c2b598", "#ccc0a4", "#d6cbb0"]),
    "c10": ("soot", ["#060506", "#0e0c0e", "#161416", "#1e1c1e", "#282527", "#322f30", "#3e3a3a",
                     "#4a4646", "#585352", "#666160", "#76706e", "#86807c"]),
    "c11": ("moss", ["#060a0a", "#0e1614", "#16221c", "#1f2e22", "#283a28", "#32462e", "#3e5234",
                     "#4a5e3a", "#586a40", "#687848", "#7a8652", "#8c945e"]),
    "c12": ("russet", ["#0e0608", "#1c0c0c", "#2a1410", "#3a1c14", "#4a2618", "#5a301c", "#6c3c22",
                       "#7e4828", "#90562e", "#a26636", "#b27840", "#c28c50"]),
}
# The crimson dye: hue at or above 255 degrees or at most 12, saturation at least 0.45.
CLOTH_DYE_ADD = {"#111020", "#342744"}  # cloth17 robe shadows, part of its dye ramp in every pack code
CLOTH_DYE_SKIP = {"#462855"}  # cloth10 white robe shading


def hx(p):
    return "#%02x%02x%02x" % p[:3]


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def c1_palettes(root, layer):
    """{relative folder: set of hex colours} over every _c1 sheet under root/layer."""
    found = {}
    for folder, _, files in os.walk(os.path.join(root, layer)):
        for name in files:
            if VARIANT.match(name):
                image = Image.open(os.path.join(folder, name)).convert("RGBA")
                colours = {hx(p) for p in image.get_flattened_data() if p[3]}
                found.setdefault(os.path.relpath(folder, root), set()).update(colours)
    return found


def check_cover(root, layers, table, family, code):
    for layer in layers:
        for folder, colours in c1_palettes(root, layer).items():
            missing = colours - table.keys()
            if missing:
                raise SystemExit(f"{family} {code}: {folder} uses unmapped {sorted(missing)}")


def skin_codes():
    return {code: dict(zip(SKIN_C1, ramp)) for code, (_, ramp) in SKIN.items()}


def hair_codes():
    codes = {}
    for code, (_, ramp, extra) in HAIR.items():
        table = dict(zip(HAIR_RAMP_C1, ramp)) | dict(zip(HAIR_EXTRA_C1, extra))
        table[HAIR_OUTLINE_C1] = ramp[0]
        table |= {c: c for c in HAIR_FIXED}
        codes[code] = table
    return codes


def eyes_codes():
    return {code: dict(zip(EYES_C1, ramp)) | {c: c for c in EYES_FIXED} for code, (_, ramp) in EYES.items()}


def is_dye(colour):
    if colour in CLOTH_DYE_ADD:
        return True
    if colour in CLOTH_DYE_SKIP:
        return False
    r, g, b = (int(colour[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, s, _ = colorsys.rgb_to_hsv(r, g, b)
    return s >= 0.45 and (h * 360 >= 255 or h * 360 <= 12)


def cloth_steps(root):
    """{dye hex: step}, one step per shade within each cloth style."""
    styles = {}
    for folder, colours in c1_palettes(root, "cloth").items():
        style = folder.replace("\\", "/").split("/")[1]
        styles.setdefault(style, set()).update(colours)
    steps = {}
    for style in sorted(styles):
        last = -1
        for colour in sorted((c for c in styles[style] if is_dye(c)), key=lambda c: lum(_rgb(c))):
            step = steps.get(colour, max(round(lum(_rgb(colour)) / CLOTH_STEP_L), last + 1))
            if step <= last:
                raise SystemExit(f"cloth {style}: {colour} shares a step with a darker shade")
            steps[colour] = min(step, 11)
            last = steps[colour]
    return steps, set().union(*styles.values())


def _rgb(colour):
    return tuple(int(colour[i:i + 2], 16) for i in (1, 3, 5))


def cloth_codes(root):
    steps, every = cloth_steps(root)
    codes = {}
    for code, (_, ramp) in CLOTH.items():
        codes[code] = {c: (ramp[steps[c]] if c in steps else c) for c in sorted(every)}
    return codes


def main():
    root, authored = sys.argv[1:3]
    path = os.path.join(authored, "colours.json")
    config = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    families = {
        "skin": (["base", "face", "jaw"], skin_codes()),
        "hair": (["hair", "beard"], hair_codes()),
        "eyes": (["eyes"], eyes_codes()),
        "cloth": (["cloth"], cloth_codes(root)),
    }
    for family, (layers, codes) in families.items():
        for code, table in codes.items():
            check_cover(root, layers, table, family, code)
        config[family] = {"layers": layers, "codes": codes}
    os.makedirs(authored, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(config, f, indent=1)
        f.write("\n")
    for family, (_, codes) in families.items():
        print(family, ", ".join(codes))


if __name__ == "__main__":
    main()
