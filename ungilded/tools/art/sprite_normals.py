"""Write a normal page beside each sprite frame: idle_3.png gets idle_3_n.png, same size and alpha.

Height is a soft bevel from the distance to the alpha edge plus a small share of the frame's luma.
Normals come from the Sobel gradient of that height, one per source pixel, green up. Transparent
pixels are (128, 128, 255). Each page also gets its Godot import settings (lossless, normal map,
no mipmaps, no alpha-border fill, no 3D VRAM switch). The colour frames are only read.

Run from the ungilded folder:
    python tools/art/sprite_normals.py              # the Prologue sprites
    python tools/art/sprite_normals.py assets/sprites/enemies/goblin_base
    python tools/art/sprite_normals.py --check      # format check only, writes nothing
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SUFFIX = "_n"
FLAT = (128, 128, 255)

PROLOGUE = [
    "assets/sprites/heroes/player",
    "assets/sprites/heroes/friend",
    "assets/sprites/enemies/rat_v1",
    "assets/sprites/enemies/rat_v2",
    "assets/sprites/enemies/rat_v3",
    "assets/sprites/decor/lantern.png",
]

IMPORT_PARAMS = {
    "compress/mode": "0",
    "compress/normal_map": "1",
    "mipmaps/generate": "false",
    "process/fix_alpha_border": "false",
    "detect_3d/compress_to": "0",
}

NEIGHBOURS = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx]


def shifted(values: np.ndarray, dy: int, dx: int, outside: float) -> np.ndarray:
    """values moved so out[y, x] = values[y + dy, x + dx], with `outside` past the border."""
    h, w = values.shape
    out = np.full_like(values, outside)
    ys, yd = (slice(dy, h), slice(0, h - dy)) if dy >= 0 else (slice(0, h + dy), slice(-dy, h))
    xs, xd = (slice(dx, w), slice(0, w - dx)) if dx >= 0 else (slice(0, w + dx), slice(-dx, w))
    out[yd, xd] = values[ys, xs]
    return out


def edge_distance(mask: np.ndarray, limit: int) -> np.ndarray:
    """Steps from each opaque pixel to the nearest transparent one, alternating 4- and 8-neighbour
    erosion so the bevel follows an octagon. Capped at `limit`."""
    distance = np.zeros(mask.shape, np.float32)
    inside = mask.copy()
    for step in range(1, limit + 1):
        distance[inside] = step
        ring = NEIGHBOURS if step % 2 == 0 else [(-1, 0), (1, 0), (0, -1), (0, 1)]
        eroded = inside.copy()
        for dy, dx in ring:
            eroded &= shifted(inside.astype(np.float32), dy, dx, 0.0) > 0.5
        inside = eroded
    return distance


def masked_blur(values: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """3x3 binomial blur that only averages opaque pixels, so nothing crosses the alpha edge."""
    weights = {0: 4.0, 1: 2.0, 2: 1.0}
    total = values * mask * 4.0
    norm = mask * 4.0
    for dy, dx in NEIGHBOURS:
        w = weights[abs(dy) + abs(dx)]
        m = shifted(mask.astype(np.float32), dy, dx, 0.0)
        total += shifted(values, dy, dx, 0.0) * m * w
        norm += m * w
    return np.where(mask, total / np.maximum(norm, 1e-6), 0.0)


def sobel(values: np.ndarray, mask: np.ndarray, outside_is_zero: bool) -> tuple[np.ndarray, np.ndarray]:
    """Gradient per pixel along x (right) and y (down). A transparent neighbour reads as 0 for the
    bevel, and as the centre pixel's own value for the luma, so luma has no slope at the edge."""
    gx = np.zeros_like(values)
    gy = np.zeros_like(values)
    for dy, dx in NEIGHBOURS:
        w = 2.0 if dy == 0 or dx == 0 else 1.0
        n = shifted(values, dy, dx, 0.0)
        if not outside_is_zero:
            n = np.where(shifted(mask.astype(np.float32), dy, dx, 0.0) > 0.5, n, values)
        gx += dx * w * n
        gy += dy * w * n
    return gx / 8.0, gy / 8.0


def normal_page(rgba: np.ndarray, bevel: int, depth: float, luma_depth: float) -> np.ndarray:
    alpha = rgba[..., 3]
    mask = alpha > 0
    h, w = mask.shape
    limit = max(1, min(bevel, min(h, w) // 4))
    t = edge_distance(mask, limit) / limit
    dome = masked_blur(1.0 - (1.0 - t) ** 2, mask)
    rgb = rgba[..., :3].astype(np.float32) / 255.0
    luma = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    luma = masked_blur(luma, mask)

    bx, by = sobel(dome * depth, mask, True)
    lx, ly = sobel(luma * luma_depth, mask, False)
    gx, gy = bx + lx, by + ly
    # Image y runs down and the page's green runs up, so a height rising downward faces up.
    n = np.stack([-gx, gy, np.ones_like(gx)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)

    out = np.empty((h, w, 4), np.uint8)
    out[..., :3] = np.clip(np.round((n * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    out[~mask, :3] = FLAT
    out[..., 3] = alpha
    return out


def write_import(page: Path) -> None:
    """Set the page's import params, keeping every other line Godot wrote."""
    path = page.with_name(page.name + ".import")
    if not path.exists():
        lines = ["[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[params]", ""]
        lines += [f"{k}={v}" for k, v in IMPORT_PARAMS.items()]
        path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        return
    lines = path.read_text(encoding="utf-8").splitlines()
    seen = set()
    in_params = False
    for i, line in enumerate(lines):
        if line.startswith("["):
            in_params = line == "[params]"
            continue
        key = line.split("=", 1)[0]
        if in_params and key in IMPORT_PARAMS:
            lines[i] = f"{key}={IMPORT_PARAMS[key]}"
            seen.add(key)
    lines += [f"{k}={v}" for k, v in IMPORT_PARAMS.items() if k not in seen]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def frames(target: Path) -> list[Path]:
    if target.is_file():
        return [target]
    return sorted(p for p in target.glob("*.png") if not p.stem.endswith(SUFFIX))


def check(frame: Path) -> list[str]:
    page = frame.with_name(frame.stem + SUFFIX + ".png")
    if not page.exists():
        return [f"{frame.name}: no {page.name}"]
    colour = np.array(Image.open(frame).convert("RGBA"))
    normal = np.array(Image.open(page).convert("RGBA"))
    if colour.shape != normal.shape:
        return [f"{page.name}: size {normal.shape[1]}x{normal.shape[0]}, frame {colour.shape[1]}x{colour.shape[0]}"]
    errors = []
    if not np.array_equal(colour[..., 3], normal[..., 3]):
        errors.append(f"{page.name}: alpha mask differs from the frame")
    clear = normal[..., 3] == 0
    if np.any(normal[clear][:, :3] != FLAT):
        errors.append(f"{page.name}: transparent pixels are not {FLAT}")
    n = normal[~clear][:, :3].astype(np.float32) / 255.0 * 2.0 - 1.0
    length = np.linalg.norm(n, axis=-1)
    if n.size and np.max(np.abs(length - 1.0)) > 0.02:
        errors.append(f"{page.name}: normal length off by {np.max(np.abs(length - 1.0)):.3f}")
    if n.size and np.any(n[:, 2] <= 0.0):
        errors.append(f"{page.name}: a normal faces away from the camera")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("targets", nargs="*", help="sprite folders or frame PNGs, relative to ungilded")
    parser.add_argument("--check", action="store_true", help="check existing pages, write nothing")
    parser.add_argument("--bevel", type=int, default=5, help="pixels from the edge to the flat top")
    parser.add_argument("--depth", type=float, default=2.0, help="bevel height in pixels")
    parser.add_argument("--luma", type=float, default=1.5, help="height in pixels from black to white")
    args = parser.parse_args()

    targets = [ROOT / t for t in (args.targets or PROLOGUE)]
    missing = [t for t in targets if not t.exists()]
    if missing:
        print("FAIL missing: " + ", ".join(str(t) for t in missing))
        return 1
    all_frames = [f for t in targets for f in frames(t)]
    if not args.check:
        for frame in all_frames:
            rgba = np.array(Image.open(frame).convert("RGBA"))
            page = frame.with_name(frame.stem + SUFFIX + ".png")
            Image.fromarray(normal_page(rgba, args.bevel, args.depth, args.luma), "RGBA").save(page)
            write_import(page)

    errors = [e for f in all_frames for e in check(f)]
    for e in errors:
        print("FAIL " + e)
    print(f"{'FAIL' if errors else 'OK'} {len(all_frames)} pages checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
