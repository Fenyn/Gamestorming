"""Build the extended Heroes99 FaceGen folder: every layer sheet grows from 4 rows to the
layout's row count (sheet_layout.json "rows").

Rows 0-3 are copied from the purchased pack unchanged. Rows 4 and up hold one expression each
(sheet_layout.json): rest, talk A, talk B, blink. They are filled in these steps:

1. Recipe. Each new cell copies an existing cell of the same sheet, chosen by layer kind:
   base, hair and cloth copy the neutral frame (0, 0); face and eyes copy the expression's source
   frame; jaw and beard copy the expression's source frame at rest and blink, and the talk frames
   (1, 1) and (1, 2) for talk A and talk B. Expressions with no source start from (0, 0).
2. Authored overrides. A file under <authored>/ with the same relative path as a _c1 sheet
   replaces rows 4 and up of that sheet wherever its cell is not empty (a file with fewer rows
   than the layout covers only the rows it has). A cell whose top-left pixel is
   pure magenta (#FF00FF) is cleared instead.
3. Recolour. Each _cN sheet takes the authored cells of its _c1 sheet through the colour map from
   the original _c1 to the original _cN. An authored colour with no mapping fails the build.

4. New parts. Files that exist only under <authored> are copied as they are (they must already be
   12 rows tall). <authored>/recolour.json maps a new part folder to an existing one, for example
   {"new_parts": {"cloth/cloth18": "cloth/cloth4"}}; each of the new part's _c1 files then gets one
   variant per colour code of the reference, through the reference's _c1 -> _cN colour map.
5. New colours. <authored>/colours.json adds colour codes per family, for example
   {"hair": {"layers": ["hair", "beard"], "codes": {"c11": {"#a1b2c3": "#112233"}}}}. Every _c1
   sheet under the listed layer folders gets a _c11 variant through that map. Keys are colours of
   the _c1 sheets; a _c1 colour missing from the map fails the build.

Usage: python build_extended.py <purchased FaceGen> <authored folder> <out FaceGen> <sheet_layout.json>
"""
import json
import os
import re
import shutil
import sys
from collections import Counter, defaultdict
from PIL import Image

VARIANT = re.compile(r"^(?P<stem>.+)_c(?P<n>\d+)(?P<tail>(_top|_bot)?)\.png$")
CLEAR = (255, 0, 255, 255)
STATIC = {"base", "hair", "cloth"}
EXPRESSIVE = {"face", "eyes"}
MOUTH = {"jaw", "beard"}


def kind_of(relpath):
    return relpath.replace("\\", "/").split("/")[0]


def cell_box(row, col, size):
    return (col * size, row * size, (col + 1) * size, (row + 1) * size)


def recipe_cell(kind, expression, col, cols, talk_a, talk_b):
    source = tuple(expression["source"]) if expression["source"] else (0, 0)
    if kind in STATIC:
        return (0, 0)
    if kind in EXPRESSIVE:
        return source
    if kind in MOUTH:
        if col == cols["talk_a"]:
            return talk_a
        if col == cols["talk_b"]:
            return talk_b
        return source
    raise ValueError(f"unknown layer kind {kind}")


def colour_map(reference, variant):
    """Most common variant colour for each reference colour, over opaque pixels."""
    votes = defaultdict(Counter)
    for a, b in zip(reference.get_flattened_data(), variant.get_flattened_data()):
        if a[3] and b[3]:
            votes[a][b] += 1
    return {a: counts.most_common(1)[0][0] for a, counts in votes.items()}


def extend(sheet, kind, layout):
    size, rows, columns = layout["frame"], layout["rows"], layout["columns"]
    cols = layout["expression_columns"]
    out = Image.new("RGBA", (size * columns, size * rows))
    out.paste(sheet.crop((0, 0, size * columns, size * 4)), (0, 0))
    for expression in layout["expressions"]:
        for col in range(columns):
            r, c = recipe_cell(kind, expression, col, cols, (1, 1), (1, 2))
            out.paste(sheet.crop(cell_box(r, c, size)), cell_box(expression["row"], col, size)[:2])
    return out


def apply_authored(target, authored, size, columns, first_row, rows, mapping=None):
    for row in range(first_row, rows):
        for col in range(columns):
            box = cell_box(row, col, size)
            cell = authored.crop(box)
            if cell.getbbox() is None:
                continue
            if cell.getpixel((0, 0)) == CLEAR:
                target.paste(Image.new("RGBA", (size, size)), box[:2])
                continue
            if mapping is not None:
                cell = recolour(cell, mapping)
            target.paste(cell, box[:2])


def recolour(cell, mapping):
    pixels = []
    for p in cell.get_flattened_data():
        if p[3] == 0:
            pixels.append(p)
        elif p in mapping:
            pixels.append(mapping[p])
        else:
            raise ValueError(f"authored colour {p} has no mapping")
    out = Image.new("RGBA", cell.size)
    out.putdata(pixels)
    return out


def main() -> int:
    source, authored, out, layout_path = sys.argv[1:5]
    layout = json.load(open(layout_path, encoding="utf-8"))
    size, rows, columns = layout["frame"], layout["rows"], layout["columns"]
    if os.path.realpath(out) in (os.path.realpath(source), os.path.realpath(authored)):
        print("FAIL the out folder must differ from the source and authored folders")
        return 1
    if os.path.exists(out):
        shutil.rmtree(out)
    built = authored_parts = 0
    groups = defaultdict(dict)
    for folder, _, files in os.walk(source):
        for name in files:
            m = VARIANT.match(name)
            if m:
                rel = os.path.relpath(os.path.join(folder, name), source)
                groups[(os.path.dirname(rel), m["stem"], m["tail"])][int(m["n"])] = rel

    errors = []
    for (folder, stem, tail), variants in sorted(groups.items()):
        reference_rel = variants.get(1)
        authored_sheet = None
        if reference_rel and os.path.exists(os.path.join(authored, reference_rel)):
            authored_sheet = Image.open(os.path.join(authored, reference_rel)).convert("RGBA")
            authored_parts += 1
        reference = Image.open(os.path.join(source, reference_rel)).convert("RGBA") if reference_rel else None
        for n, rel in variants.items():
            sheet = Image.open(os.path.join(source, rel)).convert("RGBA")
            result = extend(sheet, kind_of(rel), layout)
            if authored_sheet is not None:
                mapping = None if n == 1 else colour_map(reference, sheet)
                try:
                    apply_authored(result, authored_sheet, size, columns, 4, rows, mapping)
                except ValueError as e:
                    errors.append(f"{rel}: {e}")
            target = os.path.join(out, rel)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            result.save(target)
            built += 1

    new_parts = 0
    for folder, _, files in os.walk(authored):
        for name in files:
            if not name.endswith(".png"):
                continue
            rel = os.path.relpath(os.path.join(folder, name), authored)
            if os.path.exists(os.path.join(source, rel)):
                continue
            image = Image.open(os.path.join(authored, rel)).convert("RGBA")
            if image.width != size * columns or image.height % size or image.height < size * 4:
                errors.append(f"{rel}: new part is {image.size}, expected {size * columns} wide and whole rows")
                continue
            if image.height < size * rows:
                # Drawn before the layout grew: recipe-fill the missing rows, keep the drawn ones.
                drawn_rows = image.height // size
                extended = extend(image, kind_of(rel), layout)
                apply_authored(extended, image, size, columns, 4, drawn_rows)
                image = extended
            target = os.path.join(out, rel)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            image.save(target)
            new_parts += 1

    new_variants = recolour_new_parts(authored, out, errors)
    added_colours = add_colours(authored, out, errors)

    for line in errors:
        print("FAIL", line)
    print(f"{built} sheets extended, {authored_parts} with authored rows, {new_parts} new part files, "
          f"{new_variants} new part variants, {added_colours} new colour variants")
    return 1 if errors else 0


def variant_path(path, code):
    folder, name = os.path.split(path)
    m = VARIANT.match(name)
    return os.path.join(folder, f"{m['stem']}_{code}{m['tail']}.png")


def recolour_sheet(image, mapping):
    pixels = []
    missing = set()
    for p in image.get_flattened_data():
        if p[3] == 0:
            pixels.append(p)
        elif p in mapping:
            pixels.append(mapping[p])
        else:
            missing.add(p)
            pixels.append(p)
    out = Image.new("RGBA", image.size)
    out.putdata(pixels)
    return out, missing


def recolour_new_parts(authored, out, errors):
    config_path = os.path.join(authored, "recolour.json")
    if not os.path.exists(config_path):
        return 0
    config = json.load(open(config_path, encoding="utf-8"))
    made = 0
    for new_folder, reference_folder in config.get("new_parts", {}).items():
        new_root, ref_root = os.path.join(out, new_folder), os.path.join(out, reference_folder)
        for folder, _, files in os.walk(new_root):
            for name in files:
                m = VARIANT.match(name)
                if not m or m["n"] != "1":
                    continue
                sub = os.path.relpath(folder, new_root)
                ref_dir = os.path.normpath(os.path.join(ref_root, sub))
                ref_c1 = next((f for f in os.listdir(ref_dir) if (v := VARIANT.match(f)) and v["n"] == "1" and v["tail"] == m["tail"]), None)
                if ref_c1 is None:
                    errors.append(f"{new_folder}/{sub}: no _c1 sheet in {reference_folder}/{sub}")
                    continue
                reference = Image.open(os.path.join(ref_dir, ref_c1)).convert("RGBA")
                drawn = Image.open(os.path.join(folder, name)).convert("RGBA")
                for ref_name in os.listdir(ref_dir):
                    v = VARIANT.match(ref_name)
                    if not v or v["n"] == "1" or v["tail"] != m["tail"]:
                        continue
                    mapping = colour_map(reference, Image.open(os.path.join(ref_dir, ref_name)).convert("RGBA"))
                    sheet, missing = recolour_sheet(drawn, mapping)
                    if missing:
                        errors.append(f"{new_folder}/{sub}/{name}: colours not in {ref_c1}: {sorted(missing)[:6]}")
                        break
                    sheet.save(variant_path(os.path.join(folder, name), f"c{v['n']}"))
                    made += 1
    return made


def hex_rgba(text):
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), 255)


def add_colours(authored, out, errors):
    config_path = os.path.join(authored, "colours.json")
    if not os.path.exists(config_path):
        return 0
    config = json.load(open(config_path, encoding="utf-8"))
    made = 0
    for family, spec in config.items():
        for code, table in spec.get("codes", {}).items():
            mapping = {hex_rgba(a): hex_rgba(b) for a, b in table.items()}
            for layer in spec["layers"]:
                for folder, _, files in os.walk(os.path.join(out, layer)):
                    for name in files:
                        m = VARIANT.match(name)
                        if not m or m["n"] != "1":
                            continue
                        path = os.path.join(folder, name)
                        sheet, missing = recolour_sheet(Image.open(path).convert("RGBA"), mapping)
                        if missing:
                            errors.append(f"colours.json {family} {code}: {os.path.relpath(path, out)} uses unmapped "
                                          + ", ".join("#%02x%02x%02x" % p[:3] for p in sorted(missing)[:6]))
                            continue
                        sheet.save(variant_path(path, code))
                        made += 1
    return made


if __name__ == "__main__":
    sys.exit(main())
