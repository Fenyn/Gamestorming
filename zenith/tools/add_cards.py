"""Adds or replaces the cards one module defines, and leaves every other card alone.

    python tools/add_cards.py decks/pyre_attrition        # write
    python tools/add_cards.py decks/pyre_attrition --dry  # say what would change

Run from zenith/. The module is imported for its side effects: it calls the helpers in
`cardlib`, which collect into `cardlib.CARDS`. Only those ids are written. Cards already in
`data/cards/starter/starter_set.json` keep their position and their key order, so a card someone
edited by hand is never quietly reverted, which is exactly what the old whole-world generator did.

The file is written back in the style it is kept in: json indent 1, then each leading group of
four spaces as a tab.
"""
import importlib, json, os, sys

SET_PATH = "data/cards/starter/starter_set.json"


def tabify(text):
    out = []
    for line in text.split("\n"):
        n = len(line) - len(line.lstrip(" "))
        out.append("\t" * (n // 4) + " " * (n % 4) + line[n:])
    return "\n".join(out)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    dry = "--dry" in sys.argv
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import cardlib
    importlib.import_module(sys.argv[1].replace("/", ".").replace("\\", "."))
    new = cardlib.CARDS
    if not new:
        print("module defined no cards")
        return 1

    with open(SET_PATH, encoding="utf-8") as f:
        data = json.load(f)
    cards = data["cards"]
    by_id = {c["id"]: i for i, c in enumerate(cards)}

    added, replaced, same = [], [], []
    for card in new:
        i = by_id.get(card["id"])
        if i is None:
            cards.append(card)
            added.append(card["id"])
        elif cards[i] == card:
            same.append(card["id"])
        else:
            cards[i] = card
            replaced.append(card["id"])

    for label, ids in (("add", added), ("replace", replaced), ("unchanged", same)):
        if ids:
            print("%-9s %d: %s" % (label, len(ids), ", ".join(ids)))
    if dry:
        print("dry run, nothing written")
        return 0
    if not added and not replaced:
        return 0
    text = tabify(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    with open(SET_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote %s, %d cards" % (SET_PATH, len(cards)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
