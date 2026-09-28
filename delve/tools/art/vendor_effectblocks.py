"""Copy chosen PolyBlocks EffectBlocks v4 scenes and their dependency closure into Delve.

The pack bakes res://PolyBlocks/EffectBlocks/ into every scene and binary material, so files
keep that path under the project root. Run from anywhere:

    python tools/art/vendor_effectblocks.py

Then run a Godot --import pass so the copies get .import files.
"""
import pathlib
import re
import shutil

SOURCE_ROOT = pathlib.Path("F:/UnityNVME/Art/GodotVFX/EffectBlocks v4")
PROJECT = pathlib.Path(__file__).resolve().parents[2]

EFFECTS = [
    "other/dust_ring",      # shutter landing, room entry
    "other/sparkles",       # room cleared
    "fire/fire_light",      # refuge fire
    "other/god_rays",       # shrine
    "other/portal_magic",   # ward chamber installation
    "smoke/smoke_light",    # kitchen stove
    "energy/electric_sparks_3",  # workshop bench
]

# Binary .material files store their shader and texture paths compressed, so the scan cannot see
# them. These are the ones the materials above need (same set Eidolarch's working copy carries).
EXTRA = [
    "PolyBlocks/EffectBlocks/source_files/shaders/portal.gdshader",
    "PolyBlocks/EffectBlocks/source_files/shaders/gradient_scroll.gdshader",
    "PolyBlocks/EffectBlocks/source_files/textures/circle_1.png",
]

RES = re.compile(r'res://(PolyBlocks/EffectBlocks/[^"\s)]+)')
TEXT = {".tscn", ".tres", ".gdshader", ".gd"}


def closure(start: pathlib.Path) -> set[pathlib.Path]:
    seen: set[pathlib.Path] = set()
    todo = [start]
    while todo:
        rel = todo.pop()
        if rel in seen:
            continue
        src = SOURCE_ROOT / rel
        if not src.exists():
            print(f"missing: {rel}")
            continue
        seen.add(rel)
        if src.suffix in TEXT:
            body = src.read_text(encoding="utf-8", errors="ignore")
        else:
            body = src.read_bytes().decode("latin-1")
        for match in RES.findall(body):
            todo.append(pathlib.Path(match))
    return seen


def main() -> None:
    files: set[pathlib.Path] = set()
    for effect in EFFECTS:
        files |= closure(pathlib.Path(f"PolyBlocks/EffectBlocks/assets/{effect}.tscn"))
    for extra in EXTRA:
        files |= closure(pathlib.Path(extra))
    for rel in sorted(files):
        dest = PROJECT / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SOURCE_ROOT / rel, dest)
    print(f"copied {len(files)} files")


if __name__ == "__main__":
    main()
