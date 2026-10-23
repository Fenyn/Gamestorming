"""Draw three new Heroes99 outfits (cloth18-20) as palette-indexed rows and write them as new parts.

Each outfit is one 48x48 picture (rows 29-47 below) copied into every cell of a 192x576 sheet
except (1, 3), which stays empty as in the pack. Colours are the _c1 colours of the reference part,
so build_extended.py can make every colour code through that part's _c1 -> _cN map:

    cloth18 sewer explorer coat   reference cloth15 (bot)
    cloth19 guild apprentice robe reference cloth14 (bot)
    cloth20 leather jerkin, hood down  reference cloth7 (bot)

None of the references has a top layer, so the new parts have only a bot layer.

Usage: python draw_outfits.py <Extended folder> [<purchased FaceGen>]
With the purchased FaceGen path, the allowed lists are also checked against the reference files.
"""
import json
import os
import sys
from PIL import Image

FRAME = 48
COLUMNS, ROWS = 4, 12
EMPTY_CELL = (1, 3)

# Allowed colours per part and side: exactly the colours of the reference part's _c1 file.
COAT_PALETTE = {  # cloth15_c1_bot
    "O": "#1a010e", "n": "#12162b", "D": "#3e0d1f", "d": "#561427", "m": "#6c192e",
    "b": "#503830", "M": "#8b2a2e", "s": "#704838", "L": "#ac3e34", "H": "#d55d53",
    "t": "#a87848", "g": "#c09050", "G": "#d8b058",
}
ROBE_PALETTE = {  # cloth14_c1_bot
    "O": "#1a010e", "n": "#12162b", "D": "#330a1a", "d": "#471123", "4": "#422017",
    "q": "#2c2638", "m": "#6c192e", "Q": "#463c71", "M": "#8b2a2e", "9": "#663f35",
    "L": "#ac3e34", "b": "#885038", "c": "#456784", "e": "#a26e4a", "H": "#d55d53",
    "f": "#bc8c5d", "g": "#e9bf4f",
}
JERKIN_PALETTE = {  # cloth7_c1_bot
    "O": "#1c0b05", "p": "#3c123c", "B": "#472b21", "P": "#792246", "R": "#664435",
    "k": "#9f3257", "K": "#b04c64", "T": "#8b6451", "Y": "#bc9e5d", "y": "#c9c65e",
    "Z": "#d8f061",
}

COAT = [
    # 000000000011111111112222222222333333333344444444
    # 012345678901234567890123456789012345678901234567
    "................................................",  # 30
    ".................................OOOO...........",  # 31
    "................................OmLLmO..........",  # 32
    "..............OOO..............ODDDmMO..........",  # 33
    ".............OLHLO.............ODDDdmMO.........",  # 34
    "............OLHHLMO...........ODDDddmMO.........",  # 35
    "............OMLHLMmO..........ODDDddmMMO........",  # 36
    "...........OMLLHLmLLHHLLLMMmmdODDddmMLMO........",  # 37
    "..........OLHLLMMmMLOGgOMMmmddODddmMMLLMmO......",  # 38
    ".........OLHHLLMMmMMLLMMmmmdddOODddmMMLLMMmO....",  # 39
    "........OLHHLLMMmmDDDDDDDDDDDDOddmMMLLLMMMmmO...",  # 40
    "......OLHHLLLMMMmmmmmmmOmmmddddddmMMLLLMMMmmO...",  # 41
    "....OLHHHLLLMMMMMMMmmmmGgmmddddddmMMMLLMMMmmmO..",  # 42
    "..OLHHLLLMMMMMMMMMmmmmmOmmmmddddddmmMMMLLMMmmmO.",  # 43
    "OLHHLLLMMMMMMMMMMmmmmmmOmmmmmdddddddmmMMLLMMmmmO",  # 44
    "LHHLLLMMMMMMMMMMmmmmmmmGgmmmmddddddddmMMLLMMmmmO",  # 45
    "HHLLLMMMMMMMMMMmmmmmmmmOmmmmmddddddddmMMLLMMmmmO",  # 46
    "HLLLMMMMMMMMMMmmmmmmmmmOmmmmmddddddddmMMLLMMmmmO",  # 47
]
COAT_TOP = 30

ROBE = [
    # 000000000011111111112222222222333333333344444444
    # 012345678901234567890123456789012345678901234567
    "...................................OO...........",  # 30
    "..................................OQqO..........",  # 31
    ".................................OQqqO..........",  # 32
    "..............OO.................OQqqnO.........",  # 33
    ".............OcQO...............OQqqnnO.........",  # 34
    "............OccQO...............OQqqnnO.........",  # 35
    "............OcQQqO.............OQQqqnnO.........",  # 36
    "...........OccQQqO.............OQQqqnnMO........",  # 37
    "..........OLHcQQqqO...........OQQqqnMMLMO.......",  # 38
    ".........OLHHcQQqqqO.........OQQqqnMMLLMMO......",  # 39
    "........OLHHLcQQqqqqO......OQQqqnMMMLLMMMMMO....",  # 40
    "......OLHHLLMcQQqqqqOggfOOQqqnMMMMLLLMMMmmO.....",  # 41
    "....OLHHHLLLMMMMMmfcQOgfbOqqnbOmMMMMLLLMMMmmmO..",  # 42
    "..OLHHLLLMMMMMMMmmfcQQOOOqqqnbOmmMMMMLLLMMMmmmO.",  # 43
    "OLHHLLLMMMMMMMMmmfcQQQQQqqqqnbOmmMMMMLLLMMMmmmmO",  # 44
    "LHHLLLMMMMMMMMMmmfcQQQQQQqqqqnbOmMMMMLLLMMMmmmmO",  # 45
    "HHLLLMMMMMMMMMmmfcQQQQQQQqqqqnbOmMMMLLLMMMmmmmmO",  # 46
    "HLLLMMMMMMMMMmmmfcQQQQQQQqqqqqnbOmMMLLLMMMmmmmmO",  # 47
]
ROBE_TOP = 30
ROBE_MARKS = [  # collar shadow under the chin, then sleeve folds
    (18, 37, "n"), (19, 38, "nn"),
    (10, 43, "mL"), (9, 44, "mL"), (9, 45, "mL"), (8, 46, "mL"), (8, 47, "mL"),
    (38, 42, "m"), (38, 43, "m"), (39, 44, "m"), (39, 45, "m"), (40, 46, "m"), (40, 47, "m"),
]
ROBE_OVER = [(21, 40, "OggO"), (20, 41, "OgffbO"), (20, 42, "OfeebO"), (21, 43, "ObbO"), (22, 44, "OO")]  # guild badge

JERKIN = [
    # 000000000011111111112222222222333333333344444444
    # 012345678901234567890123456789012345678901234567
    "..................................OOO...........",  # 31
    ".................................OkKkO..........",  # 32
    "................................OKkPPkO.........",  # 33
    "...............................OpKPPkPpO........",  # 34
    ".............OOOO.............OppKPPkPPpO.......",  # 35
    "...........OOkKKPPO...........OOpKkPPkPPpO......",  # 36
    "..........OkKKPPPpPO..........OOpkKPPkPPpO......",  # 37
    ".........OkKPPpkKPPPO........OOppkKPPkPPpOTO....",  # 38
    "........OkKPPppkKPPkPO......OOppkKPPPkPPpORTO...",  # 39
    ".......OTOkPPppPPPkKPPO....OPkKPPkKPPPkPpOBRRTO.",  # 40
    "......OYTOpPPPpppPPkKKPPkKkPPPpppPPpOBBRRRTTRO..",  # 41
    ".....OYTTOOppPPPPPPkkKKKkkPPPPPpppppOOBRRRTTRRO.",  # 42
    "...OYYTTTRROOppPPPPPPPPPPPPPpppppOOBBRRRTTRRBO..",  # 43
    "..OYTTTTRRRRRBOOOpppppppppppOOOBRRRRRRTTRRBBO...",  # 44
    ".OYTTTTRRRRRRRRRBOOOOOOOOOBRRRRRRRRRRRRTTRRBBO..",  # 45
    "OYTTTRRRRRRRRRRRRRRBOYOYOBRRRRRRRRRRRRTTRRRBBO..",  # 46
    "YTTTRRRRRRRRRRRRRRRBOOYOOBRRRRRRRRRRRRTTRRRRBBO.",  # 47
]
JERKIN_TOP = 31

STRAP = {"from": (38, 38), "to_x": 12, "light": "t", "mid": "s", "dark": "b", "edge": "O"}
COAT_MARKS = [  # fold creases: dark line with the lit ridge to its right
    (12, 43, "mL"), (11, 44, "mL"), (11, 45, "mL"), (10, 46, "mL"), (10, 47, "mL"),
    (18, 43, "m"), (18, 44, "m"), (17, 45, "m"), (17, 46, "m"), (17, 47, "m"),
    (32, 42, "m"), (32, 43, "m"), (31, 44, "m"), (31, 45, "m"), (30, 46, "m"), (30, 47, "m"),
]
COAT_OVER = [(27, 41, "GGg"), (27, 42, "G g"), (27, 43, "ggg")]  # strap buckle

OUTFITS = [
    {"part": "cloth18", "reference": "cloth15", "palette": COAT_PALETTE, "rows": COAT, "top": COAT_TOP,
     "marks": COAT_MARKS, "strap": STRAP, "over": COAT_OVER},
    {"part": "cloth19", "reference": "cloth14", "palette": ROBE_PALETTE, "rows": ROBE, "top": ROBE_TOP,
     "marks": ROBE_MARKS, "over": ROBE_OVER},
    {"part": "cloth20", "reference": "cloth7", "palette": JERKIN_PALETTE, "rows": JERKIN, "top": JERKIN_TOP},
]


def hex_rgba(text):
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), 255)


def draw_strap(grid, strap):
    """Band falling one pixel per two columns from the shoulder, light on top, dark edge below.
    It only covers pixels the coat already fills."""
    x0, y0 = strap["from"]
    for x in range(strap["to_x"], x0 + 1):
        y = y0 + (x0 - x) // 2
        for dy, key in ((-2, "edge"), (-1, "light"), (0, "mid"), (1, "dark"), (2, "edge")):
            if 0 <= y + dy < FRAME and grid[y + dy][x] != ".":
                grid[y + dy][x] = strap[key]


def stamp(grid, spans):
    for x, y, text in spans:
        for k, key in enumerate(text):
            if key != " ":
                grid[y][x + k] = key


def draw_cell(outfit):
    grid = [["."] * FRAME for _ in range(FRAME)]
    for i, row in enumerate(outfit["rows"]):
        if len(row) != FRAME:
            raise ValueError(f"{outfit['part']} row {outfit['top'] + i} is {len(row)} wide")
        grid[outfit["top"] + i] = list(row)
    stamp(grid, outfit.get("marks", []))
    if "strap" in outfit:
        draw_strap(grid, outfit["strap"])
    stamp(grid, outfit.get("over", []))
    palette = {key: hex_rgba(value) for key, value in outfit["palette"].items()}
    cell = Image.new("RGBA", (FRAME, FRAME))
    for y, row in enumerate(grid):
        for x, key in enumerate(row):
            if key == ".":
                continue
            if key not in palette:
                raise ValueError(f"{outfit['part']} ({x}, {y}) uses '{key}', not in its palette")
            cell.putpixel((x, y), palette[key])
    return cell


def build_sheet(cell):
    sheet = Image.new("RGBA", (FRAME * COLUMNS, FRAME * ROWS))
    for row in range(ROWS):
        for col in range(COLUMNS):
            if (row, col) != EMPTY_CELL:
                sheet.paste(cell, (col * FRAME, row * FRAME))
    return sheet


def check_colours(sheet, allowed, name):
    allowed = {hex_rgba(h) for h in allowed}
    found = {p for p in sheet.get_flattened_data() if p[3]}
    stray = sorted(found - allowed)
    if stray:
        raise ValueError(f"{name}: colours not in the allowed list: " + ", ".join("#%02x%02x%02x" % p[:3] for p in stray))
    if any(0 < p[3] < 255 for p in sheet.get_flattened_data()):
        raise ValueError(f"{name}: partial alpha found")


def check_reference(facegen, outfit):
    path = os.path.join(facegen, "cloth", outfit["reference"], "bot", f"{outfit['reference']}_c1_bot.png")
    image = Image.open(path).convert("RGBA")
    actual = {"#%02x%02x%02x" % p[:3] for p in image.get_flattened_data() if p[3]}
    listed = {h.lower() for h in outfit["palette"].values()}
    if actual != listed:
        raise ValueError(f"{outfit['part']}: palette differs from {path}: missing {sorted(actual - listed)}, extra {sorted(listed - actual)}")
    top = os.path.join(facegen, "cloth", outfit["reference"], "top", f"{outfit['reference']}_c1_top.png")
    if os.path.exists(top) and Image.open(top).convert("RGBA").getbbox() is not None:
        raise ValueError(f"{outfit['part']}: reference has a top layer; this script draws bot only")


def update_recolour(authored):
    path = os.path.join(authored, "recolour.json")
    config = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    parts = config.setdefault("new_parts", {})
    for outfit in OUTFITS:
        parts[f"cloth/{outfit['part']}"] = f"cloth/{outfit['reference']}"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(config, f, indent=2)
        f.write("\n")


def main() -> int:
    extended = sys.argv[1]
    facegen = sys.argv[2] if len(sys.argv) > 2 else None
    authored = os.path.join(extended, "authored")
    for outfit in OUTFITS:
        if facegen:
            check_reference(facegen, outfit)
        sheet = build_sheet(draw_cell(outfit))
        name = f"{outfit['part']}_c1_bot.png"
        check_colours(sheet, outfit["palette"].values(), name)
        target = os.path.join(authored, "cloth", outfit["part"], "bot", name)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        sheet.save(target)
        print(f"wrote {target}: colours OK ({len(set(sheet.get_flattened_data())) - 1} used)")
    update_recolour(authored)
    print("updated", os.path.join(authored, "recolour.json"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
