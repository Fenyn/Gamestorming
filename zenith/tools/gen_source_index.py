"""Rebuilds data/import/source_index.json from the source-card column of docs/card_roster.csv.

    python tools/gen_source_index.py
    python tools/gen_source_index.py --roster tests/fixtures/source_roster.csv --out tests/fixtures/source_index.json

The deck importer matches a pasted list against this index. Names are stored only as the sha256 of
their normalised form, so no reference-game name ships with the game. `normalise` and the hint
cleaning in `split_source` must stay identical to `SourceIndex.normalise` and
`SourceIndex.set_hint` in deckbuild/source_index.gd; tests/deckbuild_tests.gd checks digests
of a few strings against values from here.

Run it after gen_roster.py whenever a source changes.
"""
import argparse
import csv
import hashlib
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROSTER = os.path.join(ROOT, "docs", "card_roster.csv")
OUT = os.path.join(ROOT, "data", "import", "source_index.json")

LEVEL = re.compile(r"\b(?:lv|level)\.?\s*(\d)\b", re.IGNORECASE)


def normalise(text):
    text = text.lower()
    text = re.sub(r"['’`]", "", text)
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def digest(text):
    return hashlib.sha256(normalise(text).encode("utf-8")).hexdigest()


def split_source(source):
    """Name and set hint. The bracket holds the set, a level and sometimes a print number; only the
    set, without its number, is kept as a hint."""
    source = source.strip()
    name, bracket = source, ""
    match = re.match(r"^(.*?)\s*\(([^()]*)\)?\s*$", source)
    if match and "(" in source:
        name, bracket = match.group(1), match.group(2)
    hint = LEVEL.sub("", bracket).split(";")[0].replace(",", " ")
    hint = re.sub(r"\d+\s*$", "", hint.strip())
    return name, normalise(hint)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--roster", default=ROSTER, help="CSV with id and Source card columns")
    parser.add_argument("--out", default=OUT)
    args = parser.parse_args()
    names = {}
    with open(args.roster, encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            source = row["Source card"].strip()
            if not source:
                continue
            name, hint = split_source(source)
            entry = {"id": row["id"]}
            if hint:
                entry["set"] = hashlib.sha256(hint.encode("utf-8")).hexdigest()
            names.setdefault(digest(name), []).append(entry)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"names": dict(sorted(names.items()))}, handle, indent=1, sort_keys=True)
        handle.write("\n")
    shared = sum(1 for v in names.values() if len(v) > 1)
    print("%d names, %d shared by more than one card -> %s" % (len(names), shared, args.out))


if __name__ == "__main__":
    main()
