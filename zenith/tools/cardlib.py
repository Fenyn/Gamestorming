"""The card-authoring shorthand, for writing a new card compactly.

`data/cards/starter/starter_set.json` is the source of truth for cards; this is only a way to
write new ones without hand-building the JSON. A spec module imports these helpers and calls them
at import time; `tools/add_card.py` then adds what it built, one card at a time, and refuses to
rewrite any card that already exists unless you name it. Once the cards are in the data the spec
has no further job, so a spec is fine to write in a scratch directory and throw away.

Names are original. Mechanics come from the printed card; check the text against
`tools/source_cards.tsv` and the rulings document before writing one.
"""

CARDS = []
IDS = set()


def add(**k):
    assert k["id"] not in IDS, k["id"]
    IDS.add(k["id"])
    CARDS.append(k)


def might(top, step):
    """The Might ladder: index 0 is a spent duelist, index 10 is full Energy."""
    return [0] + [top - step * (10 - i) for i in range(1, 11)]


# --- effect helpers -------------------------------------------------------
def E(op, who="self", **k):
    d = {"op": op}
    if who != "self":
        d["who"] = who
    d.update(k)
    return d


def OPP(op, **k): return E(op, "opponent", **k)
def IFS(d): return {"trigger": "if_successful", **d}
def IFSTOP(d): return {"trigger": "if_stopped", **d}
def USE(d): return {"trigger": "use", **d}
def PLACE(d): return {"trigger": "on_place", **d}
def ENTER(d, role=None):
    d = {"trigger": "entering_combat", **d}
    if role:
        d["role"] = role
    return d
def WHEN(d, **cond): return {**d, "when": cond}
def AFTER_EMPOWER(d): return {**d, "after_empower": True}
def ACC(n): return E("fervor", amount=n)
def OPP_ACC(n): return OPP("fervor", amount=n)
def VIG(n, target=None):
    d = E("energy", amount=n)
    if target:
        d["target"] = target
    return d
def FORBID(what, who="self", duration="combat"): return E("forbid", who, what=what, duration=duration)
def FLOAT(what, who="self", duration="combat", **params):
    d = E("float", who, what=what, duration=duration)
    if params:
        d["params"] = params
    return d
def SEARCH(**k): return E("search", **k)
def DISCARD_IN_PLAY(card_type, who="opponent", **k): return E("discard_in_play", who, card_type=card_type, **k)


# A born line as a play gate, for the cards the source prints as "<Heritage> only". The gate reads
# the personality holding Combat, not the player, so a following can reach a card its duelist
# cannot. Only a minority of a school's cards carry one, and the source stopped printing them
# after the middle sets, so add it per card from the scan and never by school.
DRACONIC = {"bloodline": "draconic"}
VERDANT = {"bloodline": "verdant"}


# --- card helpers ---------------------------------------------------------
def strike(id, title, school="", atk=None, **k):
    add(id=id, title=title, type="strike", school=school, attack={"kind": "strike", **(atk or {})}, **k)


def art(id, title, school="", atk=None, **k):
    add(id=id, title=title, type="art", school=school, attack={"kind": "art", **(atk or {})}, **k)


def block(id, title, stops, typ, school="", defense=None, **k):
    add(id=id, title=title, type=typ, school=school, defense={"stops": stops, **(defense or {})}, **k)


def combat(id, title, effects, school="", **k):
    add(id=id, title=title, type="combat", school=school, effects=effects, **k)


def noncombat(id, title, effects=None, school="", **k):
    d = dict(id=id, title=title, type="non_combat", school=school, **k)
    if effects:
        d["effects"] = effects
    add(**d)


def drill(id, title, school="", **k):
    add(id=id, title=title, type="drill", school=school, **k)


def grounds(id, title, **k):
    add(id=id, title=title, type="grounds", school="", limit_per_deck=3, **k)


def seal(id, title, seal_set, number, effects, **k):
    add(id=id, title=title, type="seal", school="", seal_set=seal_set, seal_number=number,
        effects=effects, limit_per_deck=1, **k)


HONORIFICS = {"sir", "dame", "lord", "lady", "master", "the"}


def _slug(s):
    out = "".join(ch if ch.isalnum() else "_" for ch in s.replace("'", "").replace("’", ""))
    while "__" in out:
        out = out.replace("__", "_")
    return out.strip("_").lower()


def personality_id(character, aspect_n, title="", variant=""):
    """The id rule, decided 2026-09-21: personality_<first>_<last>_<tier>_<title>.

    Honorifics are left out, apostrophes are dropped, spaces and hyphens become underscores. A
    card with no Aspect title uses its variant word, or nothing. A card two printed lines share
    carries no variant and so needs an Aspect title to tell it apart.
    """
    words = [w for w in character.split(",")[0].split() if w]
    if words and words[0].lower() in HONORIFICS and len(words) > 1:
        words = words[1:]
    tail = _slug(title or variant or (character.split(",", 1)[1] if "," in character else ""))
    base = "personality_%s_%d" % (_slug(" ".join(words)), aspect_n)
    return "%s_%s" % (base, tail) if tail else base


def personality(character, aspect_n, surge, top, step, power=None, title="", **k):
    """One Aspect of one character, which is one card. `title` is the Aspect's epithet, read off
    what that Aspect's Power does and never off the school the deck fields."""
    card = dict(id=personality_id(character, aspect_n, title, str(k.get("variant", ""))),
                title=character, type="personality", school="", character=character,
                aspect=aspect_n, surge=surge, might=might(top, step))
    if title:
        card["aspect_title"] = title
    if power:
        card["power"] = power
    card.update(k)
    add(**card)


def ally(title, alignment, top, step, power, surge=1, **k):
    """A personality printed at a single Aspect. Any personality card can be an Ally; this is
    only the shorthand for the ones that never climb."""
    personality(title, 1, surge, top, step, power=power,
                alignment_only=alignment, limit_per_deck=1, **k)


def duelist(character, aspects, titles, **k):
    """A character's whole printed ladder, as one card per Aspect. `titles` is one epithet per
    Aspect. Vigil duelists harden into the watch; Pact duelists come due."""
    assert len(titles) == len(aspects), character
    for a, name in zip(aspects, titles):
        a["title"] = name
        row = dict(a)
        n = row.pop("aspect")
        name_arg = row.pop("title")
        card = dict(id=personality_id(character, n, name_arg, str(k.get("variant", ""))),
                    title=character, type="personality", school="", character=character,
                    aspect=n, aspect_title=name_arg)
        card.update(row)
        card.update(k)
        add(**card)


def aspect(n, surge, top, step, power=None, constant=None, shield=None, power_alt=None):
    d = {"aspect": n, "surge": surge, "might": might(top, step)}
    if power:
        d["power"] = power
    if power_alt:
        # An Aspect the source prints with two Powers. The duelist uses one or the other, and the
        # Power is still once a turn either way.
        d["power_alt"] = power_alt
    if constant:
        d["constant"] = constant
    if shield:
        d["shield"] = shield
    return d


# The cast, for `character=` on a named card and for the conditions that read one. Adding a name
# here is not the same as placing the person; see docs/cast_backlog.md.
ALPHA = "Bram Ashmark"
BETA = "Dame Alder Rooke"
GAMMA = "Siphon"
DELTA = "Sable Draik"
EPSILON = "Halden Quarr"
ZETA = "Caedan Vale"
ETA = "Osric Thornwald"
THETA = "Marrow"
IOTA = "Sir Edric Rooke"
KAPPA = "Emrys Rooke"
EMRYS = KAPPA
HASK = "Torvan Hask"
CORIN = "Corin Thrace"
MOURNE = "Gideon Mourne"
