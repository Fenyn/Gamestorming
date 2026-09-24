"""Copies the duel's ruined-courtyard set out of the local art library into assets/courtyard/:
PSX stone, brick, grass and dirt textures with their normal maps, two cloth textures for the
playmat the cards lie on, an overcast sky converted from a
cross-layout cubemap to an equirectangular panorama, and PSX Nature models (rocks, stumps, ferns,
grass tufts, trees). Also copies two more EffectBlocks effects (falling leaves, god rays) into
PolyBlocks/ at their original res:// paths. Writes SOURCES.md.

    python tools/import_courtyard_art.py [--art F:/UnityNVME/Art]

Nothing here is generated; every pixel comes from a pack in the library.
"""
import argparse
import os
import shutil

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "assets", "courtyard")

PSX_TEX = "PSX/PSX Textures v3.0/PSX Textures/256"
PSX_NATURE = "PSX/PSX Nature v1.7.1/PSX Nature/Models/GLB"
SKY = "Skybox/Cubemap/Cubemap_Sky_10-512x512.png"
EFFECTS = "GodotVFX/EffectBlocks v4/PolyBlocks/EffectBlocks"

## Role in the set -> PSX texture name (colour map and its _normal).
TEXTURES = {
    "dais": "tiles_floor_6_1",     # the duelling slab the cards lie on (the grey cut; the brown
                                   # one read as mud under the cards)
    "flagstone": "stone_3",        # the courtyard floor around it: irregular cobbles (the square
                                   # tiles read as a chessboard at yard scale)
    "wall": "stone_3_1",           # mossy ruined walls
    "brick": "brick_wall_tx_4",    # weathered brick for pillars and coping
    "grass": "grass_5",            # ground beyond the walls
    "dirt": "dirt_3",              # worn patches
}

## The playmat the cards lie on: plain woven cloth, no normal maps in this pack.
PSX_MEGA_TEX = "PSX/PSX Mega Pack 3.1.2/PSX Mega Pack/Textures"
PLAYMAT = {
    "playmat": "fabric_5",         # charcoal felt, the mat's body
    "playmat_edge": "fabric_1",    # oxblood cloth, its bound edge
}

MODELS = ["stone_1", "stone_3", "tree_stump_1", "tree_log_1", "fern_1", "fern_2", "grass_2",
          "grass_3", "tree_1", "tree_5"]

## EffectBlocks files added to the zenith copy, at their pack paths.
EFFECT_FILES = [
    "assets/other/falling_leaves.tscn",
    "assets/other/god_rays.tscn",
    "source_files/materials/god_rays.tres",
    "source_files/shaders/god_rays.gdshader",
]

PANO_W, PANO_H = 2048, 1024


def cross_to_equirect(cross):
    """Horizontal-cross cubemap (4 x 3 faces: +Y on top of +Z; -X, +Z, +X, -Z across the middle;
    -Y below) to an equirectangular panorama, nearest sampling."""
    a = np.asarray(cross.convert("RGB"))
    f = a.shape[1] // 4
    faces = {
        "py": a[0:f, f:2 * f], "nx": a[f:2 * f, 0:f], "pz": a[f:2 * f, f:2 * f],
        "px": a[f:2 * f, 2 * f:3 * f], "nz": a[f:2 * f, 3 * f:4 * f], "ny": a[2 * f:3 * f, f:2 * f],
    }
    u = (np.arange(PANO_W) + 0.5) / PANO_W
    v = (np.arange(PANO_H) + 0.5) / PANO_H
    lon = (u - 0.5) * 2.0 * np.pi
    lat = (0.5 - v) * np.pi
    lon, lat = np.meshgrid(lon, lat)
    x = np.cos(lat) * np.sin(lon)
    y = np.sin(lat)
    z = np.cos(lat) * np.cos(lon)
    ax, ay, az = np.abs(x), np.abs(y), np.abs(z)
    out = np.zeros((PANO_H, PANO_W, 3), dtype=np.uint8)

    def sample(mask, face, s, t):
        si = np.clip(((s[mask] + 1.0) * 0.5 * f).astype(int), 0, f - 1)
        ti = np.clip(((t[mask] + 1.0) * 0.5 * f).astype(int), 0, f - 1)
        out[mask] = faces[face][ti, si]

    major_x = (ax >= ay) & (ax >= az)
    major_y = (ay > ax) & (ay >= az)
    major_z = ~(major_x | major_y)
    with np.errstate(divide="ignore", invalid="ignore"):
        sample(major_z & (z > 0), "pz", x / az, -y / az)
        sample(major_z & (z <= 0), "nz", -x / az, -y / az)
        sample(major_x & (x > 0), "px", -z / ax, -y / ax)
        sample(major_x & (x <= 0), "nx", z / ax, -y / ax)
        sample(major_y & (y > 0), "py", x / ay, z / ay)
        sample(major_y & (y <= 0), "ny", x / ay, -z / ay)
    return Image.fromarray(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--art", default="F:/UnityNVME/Art")
    art = parser.parse_args().art
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(os.path.join(OUT, "textures"))
    os.makedirs(os.path.join(OUT, "models"))
    rows = []

    for role, name in TEXTURES.items():
        for kind, folder, suffix in [("", "Color Maps", ""), ("_normal", "Normal Maps", "_normal")]:
            src = os.path.join(art, PSX_TEX, folder, name + suffix + ".png")
            dest = "textures/%s%s.png" % (role, kind)
            shutil.copyfile(src, os.path.join(OUT, dest))
            rows.append((dest, "%s/%s/%s%s.png" % (PSX_TEX, folder, name, suffix)))

    for role, name in PLAYMAT.items():
        dest = "textures/%s.png" % role
        shutil.copyfile(os.path.join(art, PSX_MEGA_TEX, name + ".png"), os.path.join(OUT, dest))
        rows.append((dest, "%s/%s.png" % (PSX_MEGA_TEX, name)))

    pano = cross_to_equirect(Image.open(os.path.join(art, SKY)))
    pano.save(os.path.join(OUT, "sky_overcast.png"))
    rows.append(("sky_overcast.png", SKY + " (cross cubemap converted to a panorama)"))

    for name in MODELS:
        shutil.copyfile(os.path.join(art, PSX_NATURE, name + ".glb"), os.path.join(OUT, "models", name + ".glb"))
        rows.append(("models/%s.glb" % name, "%s/%s.glb" % (PSX_NATURE, name)))

    for rel in EFFECT_FILES:
        dest = os.path.join(ROOT, "PolyBlocks", "EffectBlocks", rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copyfile(os.path.join(art, EFFECTS, rel), dest)

    with open(os.path.join(OUT, "SOURCES.md"), "w", encoding="utf-8") as f:
        f.write("# Courtyard set sources\n\n")
        f.write("Written by `tools/import_courtyard_art.py` from `F:/UnityNVME/Art/`. Nothing here is generated.\n\n")
        f.write("Licences:\n\n")
        f.write("- PSX Textures v3.0, PSX Mega Pack 3.1.2 and PSX Nature v1.7.1 (Pizza Doggy): use in any game, modification allowed, ")
        f.write("no attribution required; do not resell or redistribute the assets on their own.\n")
        f.write("- Screaming Brain Studios cloudy skyboxes: CC0.\n")
        f.write("- EffectBlocks v4 (falling leaves, god rays) are added to `PolyBlocks/EffectBlocks/`; see its SOURCES.md.\n\n")
        f.write("| Project file | Source under `F:/UnityNVME/Art/` |\n|---|---|\n")
        for dest, src in rows:
            f.write("| `%s` | `%s` |\n" % (dest, src))
    print("wrote %d files to %s" % (len(rows), OUT))


if __name__ == "__main__":
    main()
