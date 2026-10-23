"""Check that every colour variant of a Heroes99 part is a palette swap of its _c1 file.

A variant is a swap when it has the same alpha mask as _c1 and each _c1 colour maps to exactly one
variant colour. Prints one line per part that is not a swap.
Usage: python check_palette_swaps.py <FaceGen folder>
"""
import os
import re
import sys
from collections import defaultdict
from PIL import Image

VARIANT = re.compile(r"^(?P<stem>.+)_c(?P<n>\d+)(?P<tail>(_top|_bot)?)\.png$")


def groups(root):
    found = defaultdict(dict)
    for folder, _, files in os.walk(root):
        for name in files:
            m = VARIANT.match(name)
            if m:
                found[(folder, m["stem"], m["tail"])][int(m["n"])] = os.path.join(folder, name)
    return found


def is_swap(reference, variant):
    a, b = Image.open(reference).convert("RGBA"), Image.open(variant).convert("RGBA")
    if a.size != b.size:
        return False, "size differs"
    mapping = {}
    for pa, pb in zip(a.get_flattened_data(), b.get_flattened_data()):
        if (pa[3] == 0) != (pb[3] == 0):
            return False, "alpha mask differs"
        if pa[3] == 0:
            continue
        if mapping.setdefault(pa, pb) != pb:
            return False, f"colour {pa} maps to {mapping[pa]} and {pb}"
    return True, f"{len(mapping)} colours"


def main() -> int:
    root = sys.argv[1]
    total = bad = 0
    for (folder, stem, tail), variants in sorted(groups(root).items()):
        if 1 not in variants:
            print(f"NO C1 {folder} {stem}{tail}")
            bad += 1
            continue
        for n, path in sorted(variants.items()):
            if n == 1:
                continue
            total += 1
            ok, why = is_swap(variants[1], path)
            if not ok:
                bad += 1
                print(f"NOT SWAP {os.path.relpath(path, root)}: {why}")
    print(f"{total} variants checked, {bad} not palette swaps of _c1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
