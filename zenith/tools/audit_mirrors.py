"""Checks the two rules that keep our cast honest against the source cast. Run from zenith/
after tools/gen_roster.py has rebuilt docs/card_roster.csv:

    python tools/audit_mirrors.py

RULE 1, character anchors. Every character in our set mirrors exactly one character from the
reference game, and every card attributed to them stands in for a card of that same character.
A character wearing two different source characters' cards is the bug: it means one of our people
is quietly two of theirs, and the anchor stops meaning anything.

RULE 2, named-card titles. A card belonging to a character leads with that character's name, the
way the reference game prints named cards ("Vegeta's Physical Stance", "Android 16 Smiles"). The
title may use the surname alone.

Neither rule says our characters must map one-to-one onto theirs in the other direction: two of
ours may be built from one of theirs, and a character may play a card that was not printed with
anyone's name on it. Those cases are reported separately as notes, not failures.
"""
import csv
import re
import sys
import collections

ROSTER = "docs/card_roster.csv"

# Source titles that open with a word that is not a personality. Without this the parser reads
# "Cookie..." or "Saiyan..." as people and reports noise.
SOURCE_DB = "tools/source_cards.tsv"

NOT_PEOPLE = {
    "the", "a", "an", "super", "cookie", "wedding", "looking", "motherly", "saiyan", "namekian",
    "black", "blue", "red", "orange", "freestyle", "dende", "earth", "namek", "alt", "gathering",
    "time", "battle", "drills", "don", "hero", "expectant", "winter", "trunks", "confrontation",
    "majin",
}

# One character the reference game printed under more than one name, usually across forms. Folding
# these keeps the audit from reporting a character who is legitimately one person as two.
SAME_PERSON = {
    "Kid Buu": "Majin Buu",
    "Majin Vegeta": "Vegeta",
    "Chi": "Chi-Chi",
}

# The database also names a personality by the form they are in, so "Super Saiyan Goku" and "Goku"
# are one man and "Future Gohan" is Gohan later. Strip the form and keep the result only when what
# is left is itself a personality, which leaves "Majin Buu" and "Kid Buu" alone (there is no
# personality called "Buu") and leaves "Broly, Super Saiyan" alone (the form is not a prefix).
FORMS = ("Super Saiyan ", "Future ", "Ultimate ", "Great ")
FORM_SUFFIXES = (" on Namek",)


def _source_people():
    """Every personality name in the reference card database, so "is this a person" is answered
    from the data rather than from a hand-kept word list. Personalities are the rows with a Level."""
    out = set()
    with open(SOURCE_DB, encoding="cp1252", errors="replace") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            if not (r.get("Level") or "").strip():
                continue
            name = re.sub(r"\s*\(.*$", "", r["Name"]).strip()
            name = re.sub(r",.*$", "", name).strip()
            if name and not name.lower().startswith("alt"):
                out.add(name)
    return out


PEOPLE = _source_people()


def source_person(source):
    """The character a printed card belongs to, or "" when it belongs to nobody. Matched against
    the database's personality names, longest first, so "Majin Buu" wins over "Majin"."""
    s = re.sub(r"\s*\(.*$", "", source or "").strip()
    if not s:
        return ""
    who = ""
    for p in PEOPLE:
        if len(p) <= len(who):
            continue
        if s == p or s.startswith(p + "'s ") or s.startswith(p + ", ") or s.startswith(p + " "):
            who = p
    if who.lower() in NOT_PEOPLE:
        return ""
    return SAME_PERSON.get(who, _base_form(who))


def _base_form(who):
    """The personality behind a form name: "Super Saiyan Goku" is Goku, "Goku on Namek" is Goku."""
    for f in FORMS:
        if who.startswith(f) and who[len(f):] in PEOPLE:
            return who[len(f):]
    for f in FORM_SUFFIXES:
        if who.endswith(f) and who[: -len(f)] in PEOPLE:
            return who[: -len(f)]
    return who


def _words(s):
    return re.sub(r"[^a-z0-9 ]", " ", s.lower()).split()


def leads_with(title, character):
    """True when the title opens with the character's full name or either part of it, possessive
    or not. "Ashmark's Wall of Flame" and "Brann's Shakedown" both lead; "Cut Short" does not."""
    t = _words(title)
    # Any part of the name will do, so an honorific in front of it ("Sir Edric Rooke") does not
    # force the card to carry the honorific too.
    for name in {character} | set(character.split()):
        n = _words(name)
        if not n or len(t) < len(n):
            continue
        head = t[: len(n)]
        if head == n or (head[:-1] == n[:-1] and head[-1] == n[-1] + "s"):
            return True
    return False


def main():
    rows = list(open(ROSTER, encoding="utf-8"))
    rows = list(csv.DictReader(rows))
    mirrors = collections.defaultdict(list)   # our character -> [(source person, id, title)]
    failures = 0

    for r in rows:
        who = (r["Shows"] or "").strip()
        if not who:
            continue
        mirrors[who].append((source_person(r["Source card"]), r["id"], r["Name"], r["Source card"]))

    print("RULE 1  one source character per character of ours")
    for who in sorted(mirrors):
        people = sorted({p for p, _, _, _ in mirrors[who] if p})
        if len(people) <= 1:
            continue
        failures += 1
        print("  FAIL %s mirrors %s" % (who, ", ".join(people)))
        for p, cid, name, src in sorted(mirrors[who]):
            if p:
                print("        %-22s %-32s %s" % (cid, name, src))
    if failures == 0:
        print("  ok, %d characters" % len(mirrors))

    print("\nRULE 2  a character's cards lead with their name")
    title_fails = 0
    for who in sorted(mirrors):
        for _, cid, name, _ in sorted(mirrors[who]):
            # Personality cards are titled with the character outright, sometimes with an Aspect
            # title after a comma; those always pass.
            if leads_with(name, who):
                continue
            title_fails += 1
            print("  FAIL %-22s %-32s should lead with %s" % (cid, name, who))
    if title_fails == 0:
        print("  ok")

    print("\nRULE 3  a card standing in for a named printed card is attributed to our mirror of them")
    mirror_of = {}
    for who, entries in mirrors.items():
        for p, _, _, _ in entries:
            if p:
                mirror_of.setdefault(p, set()).add(who)
    gap = collections.defaultdict(list)
    for r in rows:
        p = source_person(r["Source card"])
        if p and not (r["Shows"] or "").strip():
            gap[p].append(r["id"])
    known = sorted(p for p in gap if p in mirror_of)
    fresh = sorted(p for p in gap if p not in mirror_of)
    gap_fails = sum(len(v) for v in gap.values())
    if known:
        print("  we already mirror these, so the cards only need attributing and retitling:")
        for p in sorted(known, key=lambda k: -len(gap[k])):
            print("    FAIL %-16s -> %-24s %2d  %s" % (p, ", ".join(sorted(mirror_of[p])), len(gap[p]), ", ".join(gap[p])))
    if fresh:
        print("  no mirror character exists for these yet:")
        for p in sorted(fresh, key=lambda k: -len(gap[k])):
            print("    FAIL %-16s %2d  %s" % (p, len(gap[p]), ", ".join(gap[p])))
    if not gap:
        print("  ok")

    print("\nNOTES  not failures, listed so they stay deliberate")
    for p in sorted(mirror_of):
        if len(mirror_of[p]) > 1:
            print("  %s is mirrored by %s" % (p, " and ".join(sorted(mirror_of[p]))))
    unnamed = [r["id"] for r in rows if (r["Shows"] or "").strip() and not source_person(r["Source card"])]
    if unnamed:
        print("  %d cards attributed to a character stand in for an unnamed printed card, which is"
              " fine: a character may play a card nobody's name is on." % len(unnamed))

    total = failures + title_fails + gap_fails
    print("\n%d failures" % total)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
