"""Write a Godot SpriteFrames .tres for an extended Heroes99 portrait sheet.

Animations, from sheet_layout.json: idle, talk and hurt from "animations"; for each expression,
"<name>" (rest with blink) and "<name>_talk" from "expression_animations". Frame durations and
speeds come from the layout, so the game plays what the generator previews.

Usage: python godot_frames.py <sheet_layout.json> <res:// path of the sheet png> <out.tres>
"""
import json
import sys


def main() -> int:
    layout_path, sheet_res, out = sys.argv[1:4]
    layout = json.load(open(layout_path, encoding="utf-8"))
    size = layout["frame"]

    animations = []
    for name, spec in layout["animations"].items():
        animations.append((name, [tuple(c) for c in spec["cells"]], spec["durations"], spec["fps"], spec["loop"]))
    for expression in layout["expressions"]:
        for suffix, key in (("", "rest"), ("_talk", "talk")):
            spec = layout["expression_animations"][key]
            cells = [(expression["row"], col) for col in spec["columns"]]
            animations.append((expression["name"] + suffix, cells, spec["durations"], spec["fps"], spec["loop"]))

    cells = sorted({cell for _, anim_cells, _, _, _ in animations for cell in anim_cells})
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             f'[ext_resource type="Texture2D" path="{sheet_res}" id="1_sheet"]', ""]
    for row, col in cells:
        lines += [f'[sub_resource type="AtlasTexture" id="r{row}c{col}"]', 'atlas = ExtResource("1_sheet")',
                  f"region = Rect2({col * size}, {row * size}, {size}, {size})", ""]
    entries = []
    for name, anim_cells, durations, fps, loop in animations:
        frames = ", ".join(f'{{"duration": {float(d)}, "texture": SubResource("r{r}c{c}")}}'
                           for (r, c), d in zip(anim_cells, durations))
        entries.append(f'{{\n"frames": [{frames}],\n"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(fps)}\n}}')
    lines += ["[resource]", "animations = [" + ", ".join(entries) + "]", ""]
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"OK {out}: {len(animations)} animations, {len(cells)} frames")
    return 0


if __name__ == "__main__":
    sys.exit(main())
