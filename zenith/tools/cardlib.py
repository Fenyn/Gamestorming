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


def ally(id, title, alignment, top, step, power, surge=1, **k):
    add(id=id, title=title, type="personality", school="", character=title, alignment_only=alignment, limit_per_deck=1,
        aspects=[{"aspect": 1, "surge": surge, "might": might(top, step), "power": power}], **k)


def duelist(id, character, aspects, titles, **k):
    """A Duelist and their Aspect ladder. `titles` is one epithet per Aspect, shown as
    "Bram Ashmark, Unquenchable". Vigil duelists harden into the watch; Pact duelists come due.
    A title is read off what that Aspect's power does, never off the school the deck fields."""
    assert len(titles) == len(aspects), id
    for a, name in zip(aspects, titles):
        a["title"] = name
    add(id=id, title=character, type="personality", school="", character=character, aspects=aspects, **k)


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
