"""Adds cards to the card set one at a time, and refuses to change one you did not name.

    python tools/add_card.py <spec>                  # add ids that are not there yet
    python tools/add_card.py <spec> --only a,b       # only these ids
    python tools/add_card.py <spec> --replace a,b    # and rewrite these, which it names
    python tools/add_card.py <spec> --dry            # say what it would do
    python tools/add_card.py --retire a,b            # take cards out, if no deck runs them

`data/cards/starter/starter_set.json` is the source of truth. A card in it may be edited by hand
at any time, so this tool never rewrites one unless `--replace` says that exact id. A spec is a
Python module that calls the helpers in `cardlib`; write it wherever you like, including a
scratch directory, because once its cards are in the data the spec has no further job.

The file is written back in the style it is kept in: json indent 1, then each leading group of
four spaces as a tab.
"""
import importlib.util, json, os, sys

SET_PATH = "data/cards/starter/starter_set.json"
DECKS_DIR = "data/decks"


def tabify(text):
    out = []
    for line in text.split("\n"):
        n = len(line) - len(line.lstrip(" "))
        out.append("\t" * (n // 4) + " " * (n % 4) + line[n:])
    return "\n".join(out)


def load_spec(path):
    """Imports a spec module by file path or dotted name, for its side effects on cardlib.CARDS."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    if os.path.exists(path):
        spec = importlib.util.spec_from_file_location("card_spec", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    else:
        importlib.import_module(path.replace("/", ".").replace("\\", "."))


def differing_keys(old, new):
    return sorted(k for k in set(old) | set(new) if old.get(k) != new.get(k))


def decks_running(card_id):
    out = []
    for name in sorted(os.listdir(DECKS_DIR)):
        with open(os.path.join(DECKS_DIR, name), encoding="utf-8") as f:
            deck = json.load(f)
        if card_id in [c["id"] for c in deck["cards"]] + list(deck.get("reserve", [])):
            out.append(name)
    return out


def arg_value(flag):
    """The raw argument after `flag`, which is one comma-joined string, or "" when absent."""
    if flag not in sys.argv:
        return ""
    i = sys.argv.index(flag)
    return sys.argv[i + 1] if i + 1 < len(sys.argv) else ""


def arg_list(flag):
    return [s.strip() for s in arg_value(flag).split(",") if s.strip()]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry" in sys.argv
    only = set(arg_list("--only"))
    allowed = set(arg_list("--replace"))
    retiring = arg_list("--retire")

    with open(SET_PATH, encoding="utf-8") as f:
        data = json.load(f)
    cards = data["cards"]
    by_id = {c["id"]: i for i, c in enumerate(cards)}

    added, replaced, same, refused, retired = [], [], [], [], []

    for dead in retiring:
        if dead not in by_id:
            print("not there: %s" % dead)
            continue
        in_use = decks_running(dead)
        if in_use:
            print("refused: %s is still run by %s" % (dead, ", ".join(in_use)))
            return 1
        cards.pop(by_id[dead])
        by_id = {c["id"]: i for i, c in enumerate(cards)}
        retired.append(dead)

    if args:
        # A flag's value sits in argv like a positional, so drop it before reading spec paths.
        values = [arg_value(f) for f in ("--only", "--replace", "--retire")]
        specs = [a for a in args if a not in values]
        import cardlib
        for path in specs:
            load_spec(path)
        for card in cardlib.CARDS:
            cid = card["id"]
            if only and cid not in only:
                continue
            i = by_id.get(cid)
            if i is None:
                cards.append(card)
                by_id[cid] = len(cards) - 1
                added.append(cid)
            elif cards[i] == card:
                same.append(cid)
            elif cid in allowed:
                cards[i] = card
                replaced.append(cid)
            else:
                refused.append((cid, differing_keys(cards[i], card)))

    for label, ids in (("add", added), ("replace", replaced), ("retire", retired), ("unchanged", same)):
        if ids:
            print("%-9s %d: %s" % (label, len(ids), ", ".join(ids)))
    for cid, keys in refused:
        print("refused   %s already exists and differs on %s; pass --replace %s to rewrite it"
              % (cid, ", ".join(keys), cid))
    if refused and not (added or replaced or retired):
        return 1
    if dry:
        print("dry run, nothing written")
        return 0
    if not (added or replaced or retired):
        return 0
    with open(SET_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(tabify(json.dumps(data, indent=1, ensure_ascii=False) + "\n"))
    print("wrote %s, %d cards" % (SET_PATH, len(cards)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
