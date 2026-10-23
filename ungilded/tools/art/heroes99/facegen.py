"""Compose Heroes99 face sheets from a recipe, and infer the recipe behind an existing sheet.

A recipe names one choice per layer, in the generator's draw order (bottom to top):
base, eyes, face, hair_bottom, cloth_bottom, jaw, beard_lower, beard_upper, cloth_top, hair_top.
Face and jaw take the base (skin) colour. Paths follow the generator's folder rules.

    python facegen.py compose <FaceGen> <recipe.json> <out.png>
    python facegen.py infer <FaceGen> <sheet.png> <recipe.json>

infer matches frame (0, 0) layer by layer from the top, keeping the option that agrees with the
sheet on every pixel the layer covers and that no higher layer hides. It then composes the recipe
and reports whether rows 0-3 reproduce the sheet exactly.
"""
import json
import os
import sys
from PIL import Image

FRAME = 48
ORDER = ["base", "eyes", "face", "hair_bottom", "cloth_bottom", "jaw", "beard_lower", "beard_upper", "cloth_top", "hair_top"]


def layer_path(root, recipe, layer):
    skin = recipe["base"]
    if layer == "base":
        return os.path.join(root, "base", f"base_{skin}.png")
    choice = recipe.get(layer.split("_")[0] if layer.startswith(("hair", "cloth")) else layer)
    if not choice:
        return None
    if layer in ("face", "jaw"):
        return os.path.join(root, layer, choice, f"{choice}_{skin}.png")
    if layer == "eyes":
        style, colour = choice
        return os.path.join(root, "eyes", style, f"{style}_{colour}.png")
    if layer.startswith(("hair", "cloth")):
        style, colour = choice
        part = layer.split("_")[0]
        side = "top" if layer.endswith("top") else "bot"
        return os.path.join(root, part, style, side, f"{style}_{colour}_{side}.png")
    if layer.startswith("beard"):
        style, colour = choice
        jaw = recipe["jaw"]
        return os.path.join(root, "beard", f"{jaw}_beard", f"{jaw}_{style}", f"{jaw}_{style}_{colour}.png")
    return None


def compose(root, recipe):
    result = None
    for layer in ORDER:
        path = layer_path(root, recipe, layer)
        if not path or not os.path.exists(path):
            continue
        image = Image.open(path).convert("RGBA")
        result = image.copy() if result is None else Image.alpha_composite(result, image)
    return result


def options(root):
    """Every (layer, choice) the folder offers, with the file for frame matching."""
    found = {layer: [] for layer in ORDER}
    for name in sorted(os.listdir(os.path.join(root, "base"))):
        found["base"].append((name[len("base_"):-4], os.path.join(root, "base", name)))
    for layer in ("face", "jaw"):
        for style in sorted(os.listdir(os.path.join(root, layer))):
            found[layer].append((style, None))
    for style in sorted(os.listdir(os.path.join(root, "eyes"))):
        for name in sorted(os.listdir(os.path.join(root, "eyes", style))):
            colour = name[len(style) + 1:-4]
            found["eyes"].append(((style, colour), os.path.join(root, "eyes", style, name)))
    for part in ("hair", "cloth"):
        for style in sorted(os.listdir(os.path.join(root, part))):
            for side, layer in (("top", f"{part}_top"), ("bot", f"{part}_bottom")):
                folder = os.path.join(root, part, style, side)
                if not os.path.isdir(folder):
                    continue
                for name in sorted(os.listdir(folder)):
                    colour = name[len(style) + 1:-len(f"_{side}.png")]
                    found[layer].append(((style, colour), os.path.join(folder, name)))
    return found


def frame0(path):
    return Image.open(path).convert("RGBA").crop((0, 0, FRAME, FRAME))


def agreement(layer_img, target, hidden):
    """(pixels agreeing, pixels checked) over opaque layer pixels not hidden by higher layers."""
    lp, tp = layer_img.load(), target.load()
    good = total = 0
    for y in range(FRAME):
        for x in range(FRAME):
            if hidden[y][x] or lp[x, y][3] == 0:
                continue
            total += 1
            good += lp[x, y] == tp[x, y]
    return good, total


def infer(root, sheet_path):
    target = frame0(sheet_path)
    hidden = [[False] * FRAME for _ in range(FRAME)]
    found = options(root)
    recipe = {}

    def pick(layer, candidates, allow_none):
        best, best_score = None, (-1.0, 0)
        for choice, path in candidates:
            if path is None or not os.path.exists(path):
                continue
            img = frame0(path)
            good, total = agreement(img, target, hidden)
            if total == 0:
                continue
            score = (good / total, total)
            if score > best_score:
                best, best_score = (choice, img), score
        if best is None or (allow_none and best_score[0] < 1.0):
            return None
        return best

    def cover(img):
        p = img.load()
        for y in range(FRAME):
            for x in range(FRAME):
                if p[x, y][3] == 255:
                    hidden[y][x] = True

    for layer in ("hair_top", "cloth_top", "cloth_bottom", "hair_bottom"):
        part = layer.split("_")[0]
        candidates = found[layer]
        if part in recipe:
            candidates = [(c, p) for c, p in candidates if c == recipe[part]]
        best = pick(layer, candidates, allow_none=True)
        if best:
            recipe[part] = list(best[0])
            cover(best[1])
    skin = pick("base", found["base"], allow_none=False)
    recipe["base"] = skin[0]
    for layer in ("jaw", "face"):
        candidates = [(s, os.path.join(root, layer, s, f"{s}_{skin[0]}.png")) for s, _ in found[layer]]
        best = pick(layer, candidates, allow_none=False)
        recipe[layer] = best[0]
        cover(best[1])
    best = pick("eyes", found["eyes"], allow_none=False)
    recipe["eyes"] = list(best[0])
    return recipe


def visible(image):
    """Pixels with fully transparent ones normalised, so hidden RGB values do not count."""
    return [p if p[3] else (0, 0, 0, 0) for p in image.get_flattened_data()]


def main() -> int:
    mode, root = sys.argv[1], sys.argv[2]
    if mode == "compose":
        recipe = json.load(open(sys.argv[3], encoding="utf-8"))
        compose(root, recipe).save(sys.argv[4])
        print(f"OK {sys.argv[4]}")
        return 0
    if mode == "infer":
        recipe = infer(root, sys.argv[3])
        json.dump(recipe, open(sys.argv[4], "w", encoding="utf-8"), indent=2)
        original = Image.open(sys.argv[3]).convert("RGBA")
        rebuilt = compose(root, recipe).crop((0, 0) + original.size)
        same = visible(rebuilt) == visible(original)
        print(f"{'OK' if same else 'MISMATCH'} {json.dumps(recipe)}")
        return 0 if same else 1
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
