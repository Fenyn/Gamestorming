"""Make customer skin variants from Kenney Animated Characters skins.

All Kenney Animated Characters skins share one UV layout, so the shirt, trousers,
hair and skin sit in the same places on every texture. This script recolours
those regions to give more customer variety, and writes PNGs next to the
character model.

Usage (from the green-bean folder):
  python3 tools/make_customer_skins.py <kenney mirror checkout>

Source skins: animated-characters-2/Skins/{skaterMaleA,skaterFemaleA,criminalMaleA}.png
from https://github.com/ETdoFresh/kenney.nl (CC0).
"""

import colorsys
import os
import sys

import numpy as np
from PIL import Image

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models", "characters", "skins")

# Regions of the 1024x1024 atlas: (x0, y0, x1, y1).
SHIRT = (0, 490, 611, 1024)
TROUSERS = (611, 764, 1024, 1024)
HAIR_TOP = (0, 0, 639, 330)
FACE = (262, 182, 388, 330)

SKIN_TONES = {
    "light": (0.97, 0.78, 0.66),
    "medium": (0.93, 0.66, 0.5),
    "tan": (0.8, 0.55, 0.38),
    "brown": (0.6, 0.4, 0.27),
    "dark": (0.38, 0.25, 0.18),
}
HAIR_COLOURS = {
    "black": (0.12, 0.1, 0.09),
    "brown": (0.3, 0.17, 0.09),
    "blonde": (0.85, 0.66, 0.36),
    "auburn": (0.55, 0.2, 0.1),
    "grey": (0.62, 0.6, 0.58),
}

# base skin, skin tone, hair, shirt hue shift (0..1), trousers hue shift, trousers value scale.
# skaterFemaleA keeps its own hair: her fringe crosses the face area, which is protected.
VARIANTS = [
    ("skaterMaleA", "medium", None, 0.0, 0.0, 1.0),
    ("skaterMaleA", "dark", "black", 0.55, 0.0, 0.8),
    ("skaterMaleA", "light", "blonde", 0.33, 0.45, 1.0),
    ("skaterMaleA", "tan", "black", 0.75, 0.05, 0.6),
    ("skaterFemaleA", "light", None, 0.0, 0.0, 1.0),
    ("skaterFemaleA", "brown", "black", 0.6, 0.0, 1.0),
    ("skaterFemaleA", "medium", None, 0.15, 0.0, 1.0),
    ("skaterFemaleA", "tan", None, 0.42, 0.0, 1.0),
    ("criminalMaleA", "medium", None, 0.0, 0.0, 1.0),
    ("criminalMaleA", "dark", "grey", 0.0, 0.0, 1.0),
]


def to_hsv(rgb):
    flat = rgb.reshape(-1, 3)
    return np.array([colorsys.rgb_to_hsv(*p) for p in flat]).reshape(rgb.shape)


def to_rgb(hsv):
    flat = hsv.reshape(-1, 3)
    return np.array([colorsys.hsv_to_rgb(*p) for p in flat]).reshape(hsv.shape)


def region_mask(shape, box):
    # Boxes are in 1024 px atlas coordinates; scale to the working size.
    k = shape[0] / 1024.0
    mask = np.zeros(shape[:2], dtype=bool)
    x0, y0, x1, y1 = (int(round(c * k)) for c in box)
    mask[y0:y1, x0:x1] = True
    return mask


def recolour(src_path, skin_tone, hair, shirt_shift, trouser_shift, trouser_value):
    src = Image.open(src_path).convert("RGB").resize((512, 512), Image.LANCZOS)
    img = np.asarray(src, dtype=np.float64) / 255.0
    hsv = to_hsv(img)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]

    # Skin: the warm orange-pink family Kenney uses for faces and hands.
    skin = (h > 0.02) & (h < 0.07) & (s > 0.4) & (s < 0.7) & (v > 0.85)
    skin &= ~region_mask(img.shape, SHIRT) & ~region_mask(img.shape, TROUSERS)
    target = np.array(colorsys.rgb_to_hsv(*SKIN_TONES[skin_tone]))
    base = np.array(colorsys.rgb_to_hsv(0.96, 0.55, 0.42))
    hsv[skin, 0] = target[0]
    hsv[skin, 1] = np.clip(s[skin] * target[1] / base[1], 0, 1)
    hsv[skin, 2] = np.clip(v[skin] * target[2] / base[2], 0, 1)

    # Hair: dark, mostly-red-brown pixels at the top of the head area.
    if hair:
        hair_mask = region_mask(img.shape, HAIR_TOP) & ~region_mask(img.shape, FACE) & (v < 0.4) & ~skin
        target = np.array(colorsys.rgb_to_hsv(*HAIR_COLOURS[hair]))
        hsv[hair_mask, 0] = target[0]
        hsv[hair_mask, 1] = target[1]
        hsv[hair_mask, 2] = np.clip(v[hair_mask] / max(v[hair_mask].mean(), 0.01) * target[2], 0, 1)

    # Shirt and trousers: rotate hue of coloured pixels, leave white/black trim alone.
    coloured = (s > 0.25) & (v > 0.2)
    shirt = region_mask(img.shape, SHIRT) & coloured
    hsv[shirt, 0] = (h[shirt] + shirt_shift) % 1.0
    if shirt_shift:
        hsv[shirt, 1] *= 0.7
    trousers = region_mask(img.shape, TROUSERS) & coloured
    hsv[trousers, 0] = (h[trousers] + trouser_shift) % 1.0
    hsv[trousers, 2] = np.clip(v[trousers] * trouser_value, 0, 1)

    return Image.fromarray((np.clip(to_rgb(hsv), 0, 1) * 255).astype(np.uint8))


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    skins_dir = os.path.join(sys.argv[1], "animated-characters-2", "Skins")
    os.makedirs(OUT_DIR, exist_ok=True)
    for i, (base, tone, hair, shirt, trousers, trouser_value) in enumerate(VARIANTS):
        out = recolour(os.path.join(skins_dir, base + ".png"), tone, hair, shirt, trousers, trouser_value)
        name = "customer_%02d.png" % (i + 1)
        out.save(os.path.join(OUT_DIR, name))
        print(name, base, tone, hair or "-")


if __name__ == "__main__":
    main()
