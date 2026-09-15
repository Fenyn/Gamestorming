"""Inventory class-tagged feats without treating pack descriptions as executable rules.

Run from the workspace root. Outputs a conservative, reproducible review backlog;
an authored ID reference is evidence to inspect, never a conformance verdict.
"""
import argparse
import csv
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

CLASSES = sorted("fighter rogue cleric wizard barbarian champion witch monk ranger druid magus oracle thaumaturge bard psychic swashbuckler summoner sorcerer".split())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("delve/design/class_audit"))
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    references = {}
    for folder in ("presets", "rules"):
        for path in sorted((project / "scripts" / folder).glob("*.cs")):
            for slug in re.findall(r'FeatureId\s*=\s*"([^"]+)"', path.read_text(encoding="utf-8-sig")):
                references.setdefault(slug, []).append(path.relative_to(project).as_posix())
    tracks = project / "scripts" / "presets" / "RosterFeats.cs"
    if tracks.exists():
        for slug in re.findall(r'new\(\d+,"([^"]+)"\)', tracks.read_text(encoding="utf-8")):
            references.setdefault(slug, []).append(tracks.relative_to(project).as_posix())
    rows, digest = [], hashlib.sha256()
    for path in sorted((args.pack_root / "feats").rglob("*.json")):
        raw = path.read_bytes()
        entry = json.loads(raw)
        if not isinstance(entry, dict) or "system" not in entry:
            continue
        system = entry["system"]
        classes = sorted(set(CLASSES) & set(system.get("traits", {}).get("value", [])))
        if not classes:
            continue
        digest.update(path.relative_to(args.pack_root).as_posix().encode())
        digest.update(raw)
        slug = path.stem
        publication = system.get("publication", {})
        for name in classes:
            rows.append(dict(class_name=name, slug=slug, name=entry.get("name", slug),
                level=system.get("level", {}).get("value", 0),
                publication=publication.get("title", ""), remaster=publication.get("remaster", False),
                status="authored-reference-needs-verification" if slug in references else "no-literal-feature-id-match",
                evidence=";".join(references.get(slug, [])), pack_path=path.relative_to(args.pack_root).as_posix()))
    rows.sort(key=lambda r: (r["class_name"], r["level"], r["slug"]))
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output / "class_feats.csv").open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    summary = {"scope": "All class-tagged feats in the local pack, including legacy and supplement entries. Counts are NOT supported feat counts.",
        "feat_content_sha256": digest.hexdigest(), "classes": {}}
    for name in CLASSES:
        entry = json.loads((args.pack_root / "classes" / f"{name}.json").read_text())
        feats = [r for r in rows if r["class_name"] == name]
        summary["classes"][name] = dict(publication=entry["system"].get("publication"),
            feat_levels=entry["system"].get("classFeatLevels", {}).get("value", []),
            feats_through_10=sum(r["level"] <= 10 for r in feats), feats_all_levels=len(feats),
            statuses=dict(Counter(r["status"] for r in feats)))
    (args.output / "inventory.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(f"Inventoried {len(rows)} class/feat associations across {len(CLASSES)} classes.")
    for name, data in summary["classes"].items():
        print(f"{name}: {data['feats_through_10']} through L10 / {data['feats_all_levels']} total; {data['statuses']}")


if __name__ == "__main__":
    main()
