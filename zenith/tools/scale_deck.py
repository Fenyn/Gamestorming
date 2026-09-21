"""Scale a multiplayer precon down to any deck size, for adventure mode.

One ordering serves both jobs. The player's stripped starter and every opponent tier are prefixes
of the same ranked slot list, so a tier-2 opponent is strictly a superset of a tier-1 one and the
curve is monotone by construction. See `designs/zenith_adventure.md` section 6.

Method:
  1. Expand the precon into slots. A card at count 3 contributes 3 slots.
  2. Drop what adventure decks never hold: Grounds, and allies outside the deck's kept pair.
  3. Rank the slots. Core first, then copy 1 of everything before any copy 2, then the precon's
     own workhorses (high count), then weakest first, so bombs land last and low tiers are basics.
  4. Fill to the target using role quotas taken from the precon's own ratios, so a beatdown deck
     stays a beatdown deck at every size instead of drifting toward whatever scores well.

Run it with no arguments to write every opponent tier:
    python tools/scale_deck.py
Starters are hand-authored and are not written by this tool.
"""

import json
import glob
import os

STARTER_SIZE = 40
STARTER_SIZE_BY_DECK = {"root_seals": 45}
STARTER_MAX_COPIES = 2

# The ladder. The player starts at 40 and grows toward 70, so tiers 1 and 2 sit under that on
# purpose: the opening stages are meant to be won while the deck is still a starter.
OPPONENT_TIERS = [
    # name, size (0 = the whole precon), lockouts allowed, max copies, aspects
    ("t1", 32, False, 2, 2),
    ("t2", 38, False, 2, 2),
    ("t3", 46, True, 3, 3),
    ("t4", 56, True, 3, 3),
    ("t5", 66, True, 3, 3),
    ("boss", 0, True, 0, 0),   # 0 aspects means take the precon's own
]

# Allies a starter keeps. A deck absent here keeps every ally it runs; the rest are unlocks.
KEPT_ALLIES = {
    # Tavin Vale and Ansel Rooke: the pair `personality_ansel_and_tavin_1_back_to_back` fuses. Keeping any other two leaves
    # Tide's Bonding card dead.
    "tide_companions": ["personality_tavin_vale_1", "personality_ansel_rooke_1"],
    "shade_henchmen": ["personality_vesna_draik_1", "personality_brann_draik_1"],
    "shade_salvage": ["personality_cull_1", "personality_orvath_kell_1"],
    "storm_unbound": ["personality_cull_1", "personality_orvath_kell_1"],
}

# Roles the quota is kept in proportion for. `special` is core and sits outside the quota.
ROLE = {
    "strike": "offense", "art": "offense",
    "combat": "answer",
    "non_combat": "support", "drill": "support",
    "seal": "special", "personality": "special", "grounds": "special",
}
QUOTA_ROLES = ("offense", "answer", "support")

# Effects that shut a whole card type off rather than answering one card. Starters keep none of
# them: a starter should be Strikes, Arts, and blocks that name Strikes or Arts. These stay in the
# precons, so the player meets them on the ladder before they can own them.
LOCKOUT_OPS = {
    "stop_all",               # stops every attack, or every attack of a kind, for the Combat
    "forbid",                 # "may not use X for the remainder of Combat"
    "choose_forbid_type",     # same, with the type chosen on resolution
    "choose_stop_all_kind",   # choose Strikes or Arts, all of them stop
    "cannot_declare_combat",
    "skip_next_attack_phase",
    "name_card",              # neither player may play the named card
}


def load_library(root="data/cards"):
    lib = {}
    for path in glob.glob(f"{root}/**/*.json", recursive=True):
        blob = json.load(open(path, encoding="utf-8"))
        items = blob if isinstance(blob, list) else blob.get("cards", blob.get("defs", []))
        if isinstance(items, dict):
            items = list(items.values())
        for card in items:
            if isinstance(card, dict) and "id" in card:
                lib[card["id"]] = card
    return lib


def power(card):
    """Rough power score from printed fields. `limit_per_deck` is the strongest signal: a card
    printed at 1 is one a designer already judged too strong at three copies."""
    s = 0
    attack = card.get("attack") or {}
    defense = card.get("defense") or {}
    if card.get("forbid"):
        s += 6
    if attack.get("unstoppable"):
        s += 5
    if attack.get("no_prevent"):
        s += 3
    if card.get("remain") or card.get("remain_when"):
        s += 3
    if defense.get("stops") == "any":
        s += 3
    if defense.get("stop_focused"):
        s += 2
    if card.get("shield"):
        s += 3
    if card.get("start_in_play"):
        s += 2
    if card.get("counter") == "combat":
        s += 3
    s += int(attack.get("life", 0)) + int(attack.get("stages", 0)) // 2
    s -= int(attack.get("cost_stages", 0)) // 2 + int(attack.get("cost_life", 0))
    s += sum(2 for m in (card.get("modifiers") or []) if not m.get("when"))
    s += len(card.get("effects") or [])
    # Personalities and Seals are limit 1 by nature, so the printed tell does not apply to them.
    if card.get("type") not in ("personality", "seal", "grounds", "mastery", "relic"):
        limit = card.get("limit_per_deck", 3)
        s += 5 if limit == 1 else (3 if limit == 2 else 0)
    if card.get("remove_after_use"):
        s -= 2
    if card.get("bottom_after_use"):
        s -= 1
    return s + int(card.get("empower", 0))


def _effects(effects):
    """Every effect dict, including the ones nested inside a choice or a conditional."""
    for e in effects or []:
        if not isinstance(e, dict):
            continue
        yield e
        for key in ("effect", "then", "else"):
            if isinstance(e.get(key), dict):
                yield from _effects([e[key]])
        for key in ("effects", "choices"):
            if isinstance(e.get(key), list):
                yield from _effects([x for x in e[key] if isinstance(x, dict)])


def is_lockout(card):
    """True if the card turns off a whole card type instead of answering one card.

    Seals are exempt. A Seal is a win condition, not a combat trick, and Root's set has to stay
    whole."""
    if card.get("type") == "seal":
        return False
    if (card.get("defense") or {}).get("stop_all"):
        return True
    if card.get("forbid"):
        return True
    return any(e.get("op") in LOCKOUT_OPS for e in _effects(card.get("effects")))


def slots(deck_id, deck, lib, drop_lockouts=True, max_copies=0):
    """Every card copy in the precon, ranked. The top N is a coherent deck at size N."""
    kept = KEPT_ALLIES.get(deck_id, None)
    out = []
    for entry in deck["cards"]:
        card = lib[entry["id"]]
        kind = card.get("type")
        if kind == "grounds":
            continue  # Grounds are optional cards and are unlocked, never in a starter
        is_core = kind == "seal" or (kind == "personality" and (kept is None or entry["id"] in kept))
        if kind == "personality" and not is_core:
            continue  # a rationed ally is an unlock, not a cut
        if drop_lockouts and not is_core and is_lockout(card):
            continue
        copies = entry["count"] if max_copies <= 0 else min(entry["count"], max_copies)
        for copy_index in range(copies):
            out.append({
                "id": entry["id"], "role": ROLE.get(kind, "support"), "core": is_core,
                "copy": copy_index, "precon_count": entry["count"], "power": power(card),
            })
    out.sort(key=lambda s: (not s["core"], s["copy"], -s["precon_count"], s["power"], s["id"]))
    return out


def scale(deck_id, deck, lib, target, drop_lockouts=True, max_copies=0):
    """Cull the precon to `target` cards, holding its own role ratios."""
    ranked = slots(deck_id, deck, lib, drop_lockouts, max_copies)
    core = [s for s in ranked if s["core"]]
    rest = [s for s in ranked if not s["core"]]
    if not rest:
        return {s["id"]: 1 for s in core}

    share = {r: sum(1 for s in rest if s["role"] == r) / len(rest) for r in QUOTA_ROLES}
    budget = max(0, min(target, len(ranked)) - len(core))
    quota = {r: int(share[r] * budget) for r in QUOTA_ROLES}
    while sum(quota.values()) < budget:  # remainders go to the largest unmet share
        r = max(QUOTA_ROLES, key=lambda r: (share[r] * budget - quota[r], share[r]))
        quota[r] += 1

    picked = list(core)
    for role in QUOTA_ROLES:
        picked += [s for s in rest if s["role"] == role][:quota[role]]

    counts = {}
    for s in picked:
        counts[s["id"]] = counts.get(s["id"], 0) + 1
    return counts


def write_starters(out_dir="data/adventure/generated_starters"):
    """The generated starters, for comparison only. Never point this at data/adventure/starters:
    those are hand-authored."""
    lib = load_library()
    os.makedirs(out_dir, exist_ok=True)
    for path in sorted(glob.glob("data/decks/*.json")):
        deck_id = os.path.basename(path)[:-5]
        deck = json.load(open(path, encoding="utf-8"))
        target = STARTER_SIZE_BY_DECK.get(deck_id, STARTER_SIZE)
        # A starter runs at most two of anything; thickening to three is reward content.
        counts = scale(deck_id, deck, lib, target, max_copies=STARTER_MAX_COPIES)
        aspects = 2
        out = {
            "name": deck["name"] + " (Starter)",
            "source_deck": deck_id,
            "mode": "adventure",
            "duelist": deck["duelist"][:aspects],
            "style": deck["style"],
            "alignment": deck["alignment"],
            "mastery": deck["mastery"],
            "relic": "",
            "reserve": [],
            "archetype": deck.get("archetype", ""),
            "difficulty": deck.get("difficulty", ""),
            "subthemes": deck.get("subthemes", []),
            "ai_profile": deck.get("ai_profile", ""),
            "tagline": deck.get("tagline", ""),
            "cards": [{"id": i, "count": counts[i]}
                      for i in sorted(counts, key=lambda x: (lib[x].get("type", ""), x))],
        }
        # A distinct id, so a deck id never resolves to both a precon and its starter.
        out_id = f"{deck_id}_start"
        json.dump(out, open(f"{out_dir}/{out_id}.json", "w", encoding="utf-8"), indent=2)
        yield out_id, sum(counts.values()), len(counts), aspects


def write_opponents(out_dir="data/adventure/opponents"):
    lib = load_library()
    os.makedirs(out_dir, exist_ok=True)
    for path in sorted(glob.glob("data/decks/*.json")):
        deck_id = os.path.basename(path)[:-5]
        deck = json.load(open(path, encoding="utf-8"))
        for tier, size, lockouts, max_copies, aspects in OPPONENT_TIERS:
            target = size if size > 0 else sum(c["count"] for c in deck["cards"])
            counts = scale(deck_id, deck, lib, target,
                           drop_lockouts=not lockouts, max_copies=max_copies)
            out = {
                "name": "%s (%s)" % (deck["name"], tier.upper()),
                "source_deck": deck_id,
                "tier": tier,
                "mode": "adventure",
                # A Duelist is a list of Aspect cards; a tier runs the bottom `aspects` of them,
                # and the boss runs the precon's whole stack.
                "duelist": deck["duelist"][:aspects] if aspects > 0 else deck["duelist"],
                "style": deck["style"],
                "alignment": deck["alignment"],
                "mastery": deck["mastery"],
                "relic": deck["relic"] if tier == "boss" else "",
                "reserve": deck["reserve"] if tier == "boss" else [],
                "archetype": deck.get("archetype", ""),
                "subthemes": deck.get("subthemes", []),
                "ai_profile": deck.get("ai_profile", ""),
                "tagline": deck.get("tagline", ""),
                "cards": [{"id": i, "count": counts[i]}
                          for i in sorted(counts, key=lambda x: (lib[x].get("type", ""), x))],
            }
            json.dump(out, open(f"{out_dir}/{deck_id}_{tier}.json", "w", encoding="utf-8"), indent=2)
            yield f"{deck_id}_{tier}", sum(counts.values())


if __name__ == "__main__":
    # Starters are hand-authored in data/adventure/starters since 2026-09-20, deck by deck around
    # each deck's plan and its bombs, and this tool must not overwrite them. `write_starters` stays
    # for comparison: `--starters` writes the generated versions to a scratch folder.
    import sys
    if "--starters" in sys.argv:
        for deck_id, total, unique, aspects in write_starters("data/adventure/generated_starters"):
            print(f"{deck_id:24} {total:3} cards, {unique:2} unique, {aspects} aspects")
    sizes = {}
    for name, total in write_opponents():
        sizes.setdefault(name.rsplit("_", 1)[1], []).append(total)
    print("opponent tiers written:", {k: (min(v), max(v)) for k, v in sizes.items()})
