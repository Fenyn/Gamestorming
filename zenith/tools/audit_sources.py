"""Line up every shipped card against the printed card it stands in for.

`docs/card_roster.csv` records a `Source card` per card. `tools/source_cards.tsv` is the reference
game's card database (name, set, number, type, text), pulled from the LackeyCCG plugin. This joins
the two and writes a review sheet: our generated rules text beside the printed text, so a mismatch
is read rather than guessed at.

    godot --headless --path zenith -s tests/print_text.gd > tools/our_text.txt
    python tools/audit_sources.py

Writes `tools/source_audit.tsv`, one row per card, `match` first:
  ok        name and set both resolved, texts are there to compare
  set       the name resolved but the roster's set label did not; check the row
  missing   no card of that name in the database; the roster label needs fixing

It does not judge whether the texts agree. That is a read, not a string compare: our wording is
deliberately different, only the mechanics have to match.
"""

import csv
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# Roster set labels to the database's set keys.
SETS = {
    "saiyan saga": "SaiyanSaga", "frieza saga": "FriezaSaga", "trunks saga": "TrunksSaga",
    "androids saga": "AndroidsSaga", "cell saga": "CellSaga", "cell games": "CellGamesSaga",
    "cell games saga": "CellGamesSaga", "world games": "WorldGamesSaga",
    "world games saga": "WorldGamesSaga", "babidi saga": "BabidiSaga", "buu saga": "BuuSaga",
    "fusion saga": "FusionSaga", "kid buu saga": "KidBuuSaga", "kid buu": "KidBuuSaga",
    "bojack unbound": "BojackUnbound", "broly subset": "BrolySubset", "bmovie": "BMovie",
    "b movie": "BMovie", "bsmovie promo": "BSMoviePromo", "buu promo": "BuuPromo",
    "kraft promo": "Kraft", "tuff enuff": "TuffEnough", "misc.": "Misc.", "misc": "Misc.",
    "shonen jump": "ShonenJump", "capsule corp power pack": "CCPP", "redemption": "Redemption",
    "collectors tin": "CollectorsTin", "fusion frenzy": "FusionFrenzy", "majin mayhem": "MajinMayhem",
    "lost villains": "LostVillains", "puppet show": "PuppetShow", "world championship": "WorldChampionship",
    "cosmic anthology": "CosmicAnthology", "irwin": "Irwin", "blast off kit": "BlastOffKit",
}


def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def strip_suffix(name):
    """The database appends a set tag to duplicated names, e.g. "Freestyle Mastery (BuS)"."""
    return re.sub(r"\s*\([A-Za-z]{2,5}\)\s*$", "", name)


def parse_source(raw):
    """"Name (Lv 2, Cell Saga)" -> ("Name", "cell saga", "2"); the set and level may be absent."""
    m = re.match(r"^(.*?)\s*\(([^)]*)\)\s*$", raw)
    if not m:
        return raw.strip(), "", ""
    name, inside = m.group(1).strip(), m.group(2).strip()
    level = ""
    lv = re.match(r"^[Ll]v\.?\s*(\d+)\s*,\s*(.*)$", inside)
    if lv:
        level, inside = lv.group(1), lv.group(2).strip()
    return name, inside.lower(), level


def load_rows(path, encoding, delimiter=","):
    with io.open(path, encoding=encoding, newline="") as fh:
        return list(csv.DictReader(fh, delimiter=delimiter))


def main():
    db = load_rows(os.path.join(HERE, "source_cards.tsv"), "latin-1", "\t")
    roster = load_rows(os.path.join(ROOT, "docs", "card_roster.csv"), "utf-8")

    by_name = {}
    for row in db:
        by_name.setdefault(norm(strip_suffix(row["Name"])), []).append(row)

    ours = {}
    text_path = os.path.join(HERE, "our_text.txt")
    if os.path.exists(text_path):
        for line in io.open(text_path, encoding="utf-8"):
            if ": " in line and not line.startswith(("Godot", "--")):
                card_id, text = line.split(": ", 1)
                ours[card_id.strip()] = text.strip()
    else:
        sys.stderr.write("no tools/our_text.txt; run print_text.gd first (see the docstring)\n")

    out = []
    counts = {"ok": 0, "set": 0, "missing": 0}
    for row in roster:
        raw = row["Source card"].strip()
        if not raw:
            continue
        name, set_label, level = parse_source(raw)
        cands = by_name.get(norm(name), [])
        want = SETS.get(set_label)
        picks = [c for c in cands if want and c["Set"] == want]
        if picks and level:
            levelled = [c for c in picks if c["Level"].strip() == level]
            picks = levelled or picks
        if picks:
            match = "ok"
        elif cands:
            match, picks = "set", cands
        else:
            match, picks = "missing", []
        counts[match] += 1
        found = picks[0] if picks else {}
        out.append({
            "match": match,
            "id": row["id"],
            "name": row["Name"],
            "source": raw,
            "found_set": found.get("Set", ""),
            "found_number": found.get("Number", ""),
            "our_text": ours.get(row["id"], row["Effect"]),
            "printed_text": found.get("Text", ""),
        })

    order = {"ok": 0, "set": 1, "missing": 2}
    out.sort(key=lambda r: (order[r["match"]], r["id"]))
    dest = os.path.join(HERE, "source_audit.tsv")
    with io.open(dest, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0].keys()), delimiter="\t")
        w.writeheader()
        w.writerows(out)
    print("%d rows -> %s" % (len(out), dest))
    print("ok %(ok)d, set unresolved %(set)d, missing %(missing)d" % counts)


if __name__ == "__main__":
    main()
