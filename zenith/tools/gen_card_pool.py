"""Rebuilds docs/card_pool.md: every card a deck can build from, one section per school, with the
approved expansion (docs/expansion_batch2_review.md) folded in under its proposed titles. Run from
zenith/ after dumping the shipped cards:

    godot --headless --path . -s tools/dump_cards.gd -- <cards.jsonl>
    python tools/gen_card_pool.py <cards.jsonl>

Subtheme tags come from regexes over the rules text, so a tag can be a near miss.
"""
import json, re, collections, sys

DUMP = sys.argv[1] if len(sys.argv) > 1 else "cards.jsonl"
SHEET = "docs/expansion_batch2_review.md"

dump = [json.loads(l) for l in open(DUMP, encoding="utf-8")]

# Batch 2 rows from the review doc: school header then table rows.
b2 = collections.defaultdict(list)
school = None
for line in open(SHEET, encoding="utf-8"):
    m = re.match(r"## (?:Batch 3: )?(Pyre|Steel|Tide|Storm|Shade|Root),", line)
    if m:
        school = m.group(1).lower()
        continue
    if line.startswith("## "):
        school = None
    if school and line.startswith("| ") and not line.startswith("| Title") and not line.startswith("| Subtheme") and not line.startswith("|---"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 5 and cells[0].startswith(school.capitalize()):
            b2[school].append({"title": cells[0], "type": cells[1], "text": cells[2], "serves": cells[3]})

TYPE_ORDER = ["Strike", "Art", "Combat", "Non-Combat", "Drill"]

# Placeholder titles of cards not built yet, renamed by the review sheet's rename sections. Shipped
# cards carry their final titles in the data since 2026-09-23.
RENAME_TITLE = {}
in_r = False
for line in open(SHEET, encoding="utf-8"):
    if line.startswith("## "):
        in_r = "rename" in line.lower()
        continue
    if not in_r or not line.startswith("| ") or line.startswith("|---"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if not cells[0].startswith("`") and len(cells) >= 2 and cells[0] not in ("Placeholder", "id"):
        RENAME_TITLE[cells[0]] = cells[1]
# Mastery rows: | School | Title | What it does | Serves | Engine | Verdict |
NEW_MASTERIES = []
in_m = False
for line in open(SHEET, encoding="utf-8"):
    if line.startswith("## ") or line.startswith("### "):
        in_m = line.startswith("## Masteries")
        continue
    if in_m and line.startswith("| ") and not line.startswith("| School") and not line.startswith("|---"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        NEW_MASTERIES.append((cells[0], cells[1], cells[2]))
NEW_MASTERIES = [(s, RENAME_TITLE.get(t, t), x) for s, t, x in NEW_MASTERIES]
for rows_ in b2.values():
    for r in rows_:
        r["title"] = RENAME_TITLE.get(r["title"], r["title"])


def t(c):
    return c["text"]


def has(c, *pats):
    return any(re.search(p, t(c)) for p in pats)


def is_type(c, *names):
    return c["type"] in names


def stops(c):
    return has(c, r"Stops (a|an|all) ")


DROWNING = {"Tide Salt Burn Drill", "Tide Dead Calm", "Tide Pounding Surf", "Tide Leeching Brine",
             "Tide Riptide", "Tide Frozen Over", "Tide Sinking Blow"}
DENIAL = r"Lower your opponent's Fervor|opponent's Fervor to 0|[Tt]heir Fervor"

# Ordered (label, test) per school. A card takes every label it matches, first one is its group.
RULES = {
    "pyre": [
        ("Fervor as a number", lambda c: has(c, r"X = your .*Fervor", r"equal to your Fervor")),
        ("Drills", lambda c: is_type(c, "Drill") or has(c, r"Pyre Drill")),
        ("Ash", lambda c: has(c, r"opponent's discard pile.*from the game", r"cards of your opponent's discard pile from the game")),
        ("Burning the board", lambda c: has(c, r"(Drill|Ally|Allies|Non-Combat).* in play", r"in play of your choice")),
        ("Pyre Arts", lambda c: is_type(c, "Art") and has(c, r"\d wounds")),
        ("Art answers", lambda c: has(c, r"Stops an Art", r"Stops all Arts", r"or an Art")),
        ("Climbing blocks", lambda c: has(c, r"Stops a Strike") and has(c, r"Fervor")),
        ("Fervor attacks", lambda c: True),
    ],
    "steel": [
        ("Might comparison", lambda c: has(c, r"Might is higher", r"Might")),
        ("Endurance armour", lambda c: has(c, r"Endurance")),
        ("Energy squeeze", lambda c: has(c, r"opponent('s duelist)? loses \d+ Energy", r"pays \d+ more Energy", r"cannot gain Energy", r"cost \+\d", r"gain 1 less")),
        ("Empower", lambda c: has(c, r"Empower")),
        ("Raw Strikes", lambda c: True),
    ],
    "tide": [
        ("Drowning", lambda c: c["title"] in DROWNING),
        ("Allies", lambda c: has(c, r"Ally", r"Allies")),
        ("Guard", lambda c: stops(c) or has(c, r"Defense Shield", r"Stops a Strike", r"stops an Art", r"is stopped")),
        ("Digging", lambda c: has(c, r"Search your Life Deck", r"Look at the top", r"[Ll]ook at your top", r"your discard pile", r"your top \d", r"your deck")),
        ("Board strip", lambda c: has(c, r"[Oo]pponent (removes|discards).* in play", r"their Drills", r"Drill in play leaves", r"only 1 Non-Combat")),
        ("Tide attacks", lambda c: True),
    ],
    "storm": [
        ("Art cost engine", lambda c: has(c, r"[Cc]osts? \d", r"cost \d", r"Costs 0", r"Arts cost", r"cost 1 less", r"Storm cards")),
        ("Art boosts", lambda c: has(c, r"your (other )?Arts do", r"Arts do \+")),
        ("Table defense", lambda c: has(c, r"Defense Shield")),
        ("Drills", lambda c: is_type(c, "Drill")),
        ("Endurance", lambda c: has(c, r"Endurance")),
        ("Energy refill", lambda c: has(c, r"Gain \d+ Energy", r"Energy to full")),
        ("Strike answers", lambda c: has(c, r"Stops a Strike", r"Strike cards")),
        ("Art answers", lambda c: has(c, r"Stops an Art")),
        ("Storm Arts", lambda c: True),
    ],
    "shade": [
        ("Whisper", lambda c: "Whisper" in c["title"]),
        ("Life Deck attack", lambda c: has(c, r"their Life Deck", r"opponent's Life Deck", r"Name a card")),
        ("Hexes", lambda c: has(c, r"[Aa]ttach")),
        ("Hand attack", lambda c: has(c, r"hand")),
        ("Paying Energy", lambda c: has(c, r"Costs \d", r"pay any amount")),
        ("Answers", lambda c: stops(c)),
        ("Shade attacks", lambda c: True),
    ],
    "root": [
        ("Recursion", lambda c: has(c, r"discard pile") and has(c, r"Life Deck|into your hand|Draw the bottom|draw the")),
        ("Seals", lambda c: has(c, r"Seal") and not has(c, r"not a Seal")),
        ("Table defense", lambda c: is_type(c, "Drill") or has(c, r"Endurance [4-9]|Endurance 10")),
        ("Fervor denial", lambda c: has(c, r"Lower your opponent's Fervor")),
        ("Board strip", lambda c: has(c, r"[Oo]pponent (removes|discards).* in play")),
        ("Costly Arts", lambda c: has(c, r"Costs \d")),
        ("Root attacks", lambda c: True),
    ],
}

# Batch 2 "Serves" wording -> the group labels above.
SERVES_MAP = {
    "pyre": [("Fervor as a number", "Fervor as a number"), ("Drills", "Drills"), ("ash", "Ash"), ("Ash", "Ash"),
             ("Burning the board", "Burning the board"), ("Art answers", "Art answers"), ("Art body", "Fervor attacks")],
    "steel": [("Might", "Might comparison"), ("Endurance", "Endurance armour"), ("Energy squeeze", "Energy squeeze"),
              ("Empower", "Empower"), ("Non-Combat", "Might comparison")],
    "tide": [("Fervor denial", "Fervor denial"), ("Allies", "Allies"), ("Digging", "Digging"), ("attack-or-stop", "Attack or stop")],
    "shade": [("Whisper", "Whisper"), ("Life Deck", "Life Deck attack"), ("hexes", "Hexes"), ("Hexes", "Hexes"),
              ("Hand attack", "Hand attack"), ("Energy gain", "Shade attacks"), ("Board removal", "Shade attacks"),
              ("Recursion", "Answers")],
    "root": [("Cost", "Costly Arts"), ("Seals", "Seals")],
}

TYPE_FIX = {"Art stop": "Art", "Strike stop": "Strike"}


def labels_for(school, c):
    labs = [lab for lab, fn in RULES[school][:-1] if fn(c)]
    return labs or [RULES[school][-1][0]]


# Printed in the Physical Combat band although they stop an Art, so they are Strikes.
STRIKE_TITLES = {"Pyre Choking Smoke", "Pyre Heat Haze", "Shade Gathered Hexes"}


def b2_labels(school, row):
    out = [lab for lab, _ in RULES[school] if lab.lower() in row["serves"].lower()]
    for key, lab in SERVES_MAP.get(school, []):
        if key in row["serves"] and lab not in out:
            out.append(lab)
    return out or [RULES[school][-1][0]]


def row(title, typ, text, labels, status, cid):
    return {"title": title, "type": typ, "text": text, "labels": labels, "status": status, "id": cid}


SHIPPED_TITLES = {c["title"] for c in dump}


def school_rows(school):
    rows = []
    # A sheet row that has since been built is the shipped card now. It keeps the subthemes the
    # sheet gave it, which were checked by eye, and takes its text from the engine.
    sheet = {r["title"]: r for r in b2[school]}
    for c in dump:
        if c["school"] != school or c["type"] == "Mastery" or c["character"]:
            continue
        labs = labels_for(school, c)
        if c["title"] in sheet and school != "tide":
            labs = b2_labels(school, sheet[c["title"]])
        rows.append(row(c["title"], c["type"], c["text"], labs, "", c["id"]))
    for r in b2[school]:
        if r["title"] in SHIPPED_TITLES:
            continue
        typ = "Strike" if r["title"] in STRIKE_TITLES else TYPE_FIX.get(r["type"], r["type"])
        labs = labels_for(school, {"title": r["title"], "type": typ, "text": r["text"]}) if school == "tide" else b2_labels(school, r)
        rows.append(row(r["title"], typ, r["text"], labs, "new", ""))
    return rows


def esc(s):
    return s.replace("|", "\\|")


def table(rows, group_order):
    out = ["| Title | Type | What it does | Subthemes | New | id |", "|---|---|---|---|---|---|"]
    def key(r):
        g = r["labels"][0]
        return (group_order.index(g) if g in group_order else 99, TYPE_ORDER.index(r["type"]) if r["type"] in TYPE_ORDER else 9, r["title"])
    for r in sorted(rows, key=key):
        out.append("| %s | %s | %s | %s | %s | %s |" % (esc(r["title"]), r["type"], esc(r["text"]), ", ".join(r["labels"]),
                                                   "new" if r["status"] else "", "`%s`" % r["id"] if r["id"] else ""))
    return "\n".join(out)


SCHOOLS = [("pyre", "Pyre", "fire"), ("steel", "Steel", "Draconic manifestation; needs a Draconic Duelist"),
           ("tide", "Tide", "water"), ("storm", "Storm", "lightning and wind"),
           ("shade", "Shade", "shadow and hexes"), ("root", "Root", "thorn, sap, stone and frost; needs a Verdant Duelist")]

md = []
md.append("# Eidolarch card pool by school\n")
md.append("Every card a deck can build from, one section per school, with batches 2 and 3 and the new Masteries folded in (marked "
          "`new`, not built yet, no id until it is). Rebuilt by `tools/gen_card_pool.py`. Ids are generic "
          "(`pyre_strike_07`) and never follow a title. Rules "
          "text of shipped cards is the engine's own wording (`tools/dump_cards.gd`); new cards use the review "
          "sheet's summary.\n")
md.append("Counts leave out Masteries and signature cards and include gated cards. Rows are grouped by their first "
          "subtheme. Subthemes were tagged by a script reading the rules text and then checked by eye, so a tag can "
          "be a near miss.\n")

summary = ["| School | Cards | New | Strike | Art | Combat | Non-Combat | Drill |", "|---|---|---|---|---|---|---|---|"]
sections = []
for sid, name, elem in SCHOOLS:
    rows = school_rows(sid)
    tc = collections.Counter(r["type"] for r in rows)
    new = sum(1 for r in rows if r["status"])
    summary.append("| %s | %d | %d | %s |" % (name, len(rows), new, " | ".join(str(tc.get(x, 0)) for x in TYPE_ORDER)))
    order = [lab for lab, _ in RULES[sid]]
    counts = collections.Counter(l for r in rows for l in r["labels"])
    masteries = [c for c in dump if c["school"] == sid and c["type"] == "Mastery"]
    s = ["## %s (%s): %d cards\n" % (name, elem, len(rows))]
    s.append("Subthemes: " + ", ".join("%s %d" % (lab, counts[lab]) for lab in order if counts[lab]) + ".\n")
    if sid == "tide":
        n = sum(1 for r in rows if re.search(DENIAL, r["text"]))
        s.append("Fervor denial is a trait here, not a subtheme: %d cards carry it as a rider. It stops a climb; "
                 "Drowning is what turns low Fervor into a win.\n" % n)
    ml = ["Masteries:\n"]
    ml += ["- **%s** (`%s`): %s" % (m["title"], m["id"], esc(m["text"])) for m in masteries]
    ml += ["- **%s** (new): %s" % (title, esc(text)) for sch, title, text in NEW_MASTERIES
           if sch == name and title not in SHIPPED_TITLES]
    s.append("\n".join(ml) + "\n")
    s.append(table(rows, order))
    sections.append("\n".join(s))

# Freestyle
free = [c for c in dump if c["school"] == "" and not c["character"] and c["type"] in TYPE_ORDER]
FREE_RULES = [
    ("Search", lambda c: has(c, r"Search your Life Deck", r"Look at the top", r"Draw")),
    ("Board removal", lambda c: has(c, r"in play")),
    ("Recursion", lambda c: has(c, r"discard pile")),
    ("Seals", lambda c: has(c, r"Seal")),
    ("Allies", lambda c: has(c, r"Ally|Allies")),
    ("Fervor", lambda c: has(c, r"Fervor")),
    ("Stops", lambda c: stops(c)),
    ("Other", lambda c: True),
]
frows = [row(c["title"], c["type"], c["text"], [l for l, fn in FREE_RULES if fn(c)], "", c["id"]) for c in free]
tc = collections.Counter(r["type"] for r in frows)
summary.append("| Freestyle | %d | 0 | %s |" % (len(frows), " | ".join(str(tc.get(x, 0)) for x in TYPE_ORDER)))
fm = [c for c in dump if c["school"] == "" and c["type"] == "Mastery"]
fs = ["## Freestyle (shared, mundane): %d cards\n" % len(frows),
      "Legal in every deck. Grouped by what the card is for rather than by subtheme.\n",
      "Mastery: " + "; ".join("**%s** (`%s`): %s" % (m["title"], m["id"], esc(m["text"])) for m in fm) + "\n",
      table(frows, [l for l, _ in FREE_RULES])]
sections.append("\n".join(fs))

# Signature by character
sig = [c for c in dump if c["character"] and c["type"] in TYPE_ORDER]
by = collections.defaultdict(list)
for c in sig:
    by[c["character"]].append(c)
ss = ["## Signature: %d cards\n" % len(sig),
      "Tied to a named character, schoolless unless noted. Listed by character, largest kit first.\n",
      "| Character | Title | Type | What it does | id |", "|---|---|---|---|---|"]
for ch in sorted(by, key=lambda k: (-len(by[k]), k)):
    for c in sorted(by[ch], key=lambda c: (TYPE_ORDER.index(c["type"]), c["title"])):
        school_note = " (%s)" % c["school"].capitalize() if c["school"] else ""
        ss.append("| %s | %s%s | %s | %s | `%s` |" % (ch, esc(c["title"]), school_note, c["type"], esc(c["text"]), c["id"]))
sections.append("\n".join(ss))

other = collections.Counter(c["type"] for c in dump if c["type"] not in TYPE_ORDER + ["Mastery"])
md.append("## At a glance\n")
md.append("\n".join(summary) + "\n")
md.append("Not listed below: " + ", ".join("%d %s" % (v, k) for k, v in sorted(other.items())) + ".\n")
md.append("\n\n".join(sections) + "\n")
open("docs/card_pool.md", "w", encoding="utf-8", newline="\n").write("\n".join(md))
print("\n".join(summary))
