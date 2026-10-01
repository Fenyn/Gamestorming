"""Scale a multiplayer precon down to any deck size, for adventure mode.

Every opponent tier of a family is a prefix of one ordered slot list, so a tier-2 opponent is
strictly a superset of a tier-1 one and the curve is monotone by construction. See
`designs/zenith_adventure.md` section 6.4.

Method:
  1. Expand the precon into slots. A card at count 3 contributes 3 slots. Only the precon's own
     counts cap copies, and those already obey the printed limits (3, 4 for the duelist's own
     named cards, lower where a card prints one). There is no house copy cap.
  2. Drop what adventure decks never hold: Grounds, and allies outside the deck's kept pair.
  3. Rank the slots. Core first, then copy 1 of everything before any copy 2, then the precon's
     own workhorses (high count), then weakest first, so bombs land last and low tiers are basics.
  4. Build the tiers in order, each one adding to the last. A tier's additions hold the precon's
     own role ratios, then meet the family's stop floor, then bring about a third of the stops to
     stop-any. The additions are taken in rank order except where the floor or the stop-any share
     pulls a stop forward, so the final order is the ranking with those promotions applied.

The stop floor and the stop-any share are the construction standards the hand-built starters
were rebuilt to on 2026-09-21 (`docs/adventure_starters.md`).

Run it with no arguments to write every opponent tier, or name the families to write:
    python tools/scale_deck.py
    python tools/scale_deck.py --only=mercenary_lord
Starters are hand-authored and are not written by this tool.
"""

import json
import glob
import os

STARTER_SIZE = 40
STARTER_SIZE_BY_DECK = {"root_seals": 45}
STARTER_MAX_COPIES = 2

# The ladder. The player starts at 50 (Root 55) and grows toward the precon, so tier 1 sits a
# little under that: the opening stages are meant to be won while the deck is still a starter.
# 2026-09-21: 40 to the full precon (about 80), from 32 to 66. The per-tier copy cap (2 at t1) was
# dropped the same day: only the printed limits apply, as for the starters.
OPPONENT_TIERS = [
    # name, size (0 = the whole precon), lockouts allowed, aspects
    ("t1", 40, False, 2),
    ("t2", 48, False, 2),
    ("t3", 56, True, 3),
    ("t4", 64, True, 3),
    ("t5", 72, True, 3),
    ("boss", 0, True, 0),   # 0 aspects means take the precon's own
]

# Minimum stopping cards in a 50-card deck, by how aggressive the deck is (user ruling
# 2026-09-21): most aggressive 8, beatdown 10, midrange 12, control or setup 14. A smaller tier
# scales it by size / 50, a tier of 50 or more takes it whole, and the precon caps it.
STOP_FLOOR = {
    "pyre_beatdown": 8,
    "steel_beatdown": 10, "shade_mind_siege": 10, "steel_heir": 10,
    "pyre_attrition": 12, "freestyle_swords": 12, "tide_deepwater": 12, "shade_henchmen": 12,
    "mercenary_lord": 12,
    "pyre_ascent": 14, "storm_volley": 14, "storm_unbound": 14, "shade_salvage": 14,
    "tide_companions": 14, "root_seals": 14,
}
STOP_FLOOR_SIZE = 50
# About this share of a deck's stops stop either kind, so a Focused attack means something.
STOP_ANY_SHARE = 1.0 / 3.0

# Allies a starter keeps. A deck absent here keeps every ally it runs; the rest are unlocks.
KEPT_ALLIES = {
    # Tavin Vale and Ansel Rooke: the pair `personality_ansel_and_tavin_1_back_to_back` fuses. Keeping any other two leaves
    # Tide's Bonding card dead.
    "tide_companions": ["personality_51", "personality_52"],
    "shade_henchmen": ["personality_40", "personality_41"],
    "shade_salvage": ["personality_46", "personality_47"],
    "storm_unbound": ["personality_46", "personality_47"],
}

# Roles the quota is kept in proportion for. `special` is core and sits outside the quota.
# This maps the printed type only; `role()` overrides it for any card with a defense block.
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


def _num(value):
    """A printed number, or 0 for a computed one ("max", a per-Ally rate and the like)."""
    return value if isinstance(value, int) and not isinstance(value, bool) else 0


def damage(attack):
    """Life and Energy damage an attack prints, Energy counted in full."""
    return sum(_num(attack.get(k, 0)) for k in ("life", "stages", "printed_life", "printed_stages"))


def role(card):
    """The job a card does. A card with a defense block is an answer whatever band it is printed
    in: a Strike or Art that stops is a defense card, not offense."""
    if card.get("defense"):
        return "answer"
    return ROLE.get(card.get("type"), "support")


def is_stop(card):
    return bool((card.get("defense") or {}).get("stops"))


def is_stop_any(card):
    return (card.get("defense") or {}).get("stops") == "any"


def refunds_energy(card):
    """True if the card gives its own side Energy back when used. Drains aimed at the opponent do
    not count."""
    for e in _effects(card.get("effects")):
        if e.get("op") != "energy" or e.get("who") == "opponent":
            continue
        amount = e.get("amount")
        if amount == "max" or _num(amount) > 0:
            return True
    return False


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
    # Energy damage counts as pseudo-damage, worth the same as life damage (2026-09-21). The
    # printed_ fields are the same damage for cards whose number is printed rather than computed.
    s += damage(attack)
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
    duelist_character = lib[deck["duelist"][0]].get("character", "")
    out = []
    for position, entry in enumerate(deck["cards"]):
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
                "id": entry["id"], "position": position, "role": role(card), "core": is_core,
                "copy": copy_index, "precon_count": entry["count"], "power": power(card),
                "lockout": not is_core and is_lockout(card),
                "stop": is_stop(card), "any": is_stop_any(card),
                # Stops the stop-any share may never push out: Energy refunds and the duelist's own.
                "protected": is_stop(card) and (refunds_energy(card) or (
                    duelist_character != "" and card.get("character") == duelist_character)),
            })
    # The last tie-break is the card's place in the precon list, not its id, so renaming a card
    # never reshuffles a tier.
    out.sort(key=lambda s: (not s["core"], s["copy"], -s["precon_count"], s["power"], s["position"]))
    for i, s in enumerate(out):
        s["rank"] = i
    return out


def stop_floor(deck_id, size):
    """The fewest stops a tier of `size` cards should hold, before the precon's own cap."""
    floor = STOP_FLOOR.get(deck_id, 0)
    if size >= STOP_FLOOR_SIZE:
        return floor
    return int(floor * size / STOP_FLOOR_SIZE + 0.5)


def _share(counts):
    total = sum(counts.values())
    return {r: (counts.get(r, 0) / total if total else 0.0) for r in QUOTA_ROLES}


def _grow(have, pool, target, floor):
    """The slots to add to `have` (a tier already built) to reach `target` cards from `pool` (the
    slots this tier may take that `have` does not hold, in rank order).

    Order of rules: role ratios set how many of each role to add, the stop floor raises the answer
    count if it has to, then the stop-any share swaps plain stops for stop-any ones. Nothing in
    `have` is ever removed, which is what keeps the tiers monotone."""
    budget = target - len(have)
    if budget <= 0 or not pool:
        return []
    budget = min(budget, len(pool))
    by_role = {r: [s for s in pool if s["role"] == r] for r in QUOTA_ROLES}
    have_role = {r: sum(1 for s in have if s["role"] == r and not s["core"]) for r in QUOTA_ROLES}
    # Ratios from every non-core slot the tier may hold, so a scaled deck is a smaller precon.
    everything = {r: have_role[r] + len(by_role[r]) for r in QUOTA_ROLES}
    share = _share(everything)
    non_core_target = sum(have_role.values()) + budget
    want = {r: max(0.0, share[r] * non_core_target - have_role[r]) for r in QUOTA_ROLES}
    scale = budget / sum(want.values()) if sum(want.values()) > 0 else 0.0
    want = {r: want[r] * scale for r in QUOTA_ROLES}
    add = {r: min(int(want[r]), len(by_role[r])) for r in QUOTA_ROLES}
    while sum(add.values()) < budget:  # remainders go to the largest unmet share with room
        open_roles = [r for r in QUOTA_ROLES if add[r] < len(by_role[r])]
        r = max(open_roles, key=lambda r: (want[r] - add[r], share[r]))
        add[r] += 1

    # The stop floor. Answers are the only role that holds stops, so the floor raises that count
    # and the other roles give way, the largest first.
    have_stops = sum(1 for s in have if s["stop"])
    pool_stops = [s for s in pool if s["stop"]]
    need = max(0, min(floor, have_stops + len(pool_stops)) - have_stops)
    while add["answer"] < need and add["answer"] < len(by_role["answer"]):
        donor = max((r for r in QUOTA_ROLES if r != "answer"), key=lambda r: add[r])
        if add[donor] == 0:
            break
        add[donor] -= 1
        add["answer"] += 1

    answers = list(by_role["answer"][:add["answer"]])
    # Meet the floor inside the answer picks: the weakest non-stop answer gives way to the next stop.
    while sum(1 for s in answers if s["stop"]) < need:
        spare = [s for s in answers if not s["stop"]]
        nxt = [s for s in pool_stops if s not in answers]
        if not spare or not nxt:
            break
        answers.remove(max(spare, key=lambda s: s["rank"]))
        answers.append(nxt[0])

    # The stop-any share. The weakest plain stop added this tier gives way to the next stop-any,
    # but never an Energy refund or the duelist's own stop.
    def any_short():
        stops = have_stops + sum(1 for s in answers if s["stop"])
        anys = sum(1 for s in have if s["any"]) + sum(1 for s in answers if s["any"])
        return int(stops * STOP_ANY_SHARE + 0.5) - anys
    while any_short() > 0:
        plain = [s for s in answers if s["stop"] and not s["any"] and not s["protected"]]
        nxt = [s for s in pool if s["any"] and s not in answers]
        if not plain or not nxt:
            break
        answers.remove(max(plain, key=lambda s: s["rank"]))
        answers.append(nxt[0])

    picked = answers
    for r in QUOTA_ROLES:
        if r != "answer":
            picked += by_role[r][:add[r]]
    return sorted(picked, key=lambda s: s["rank"])


def ladder(deck_id, deck, lib):
    """Every opponent tier of one family, as (tier, slots). Each tier holds the one before it."""
    ranked = slots(deck_id, deck, lib, drop_lockouts=False)
    core = [s for s in ranked if s["core"]]
    order = list(core)
    out = []
    for tier, size, lockouts, _aspects in OPPONENT_TIERS:
        allowed = [s for s in ranked if not s["core"] and (lockouts or not s["lockout"])]
        taken = set(id(s) for s in order)
        pool = [s for s in allowed if id(s) not in taken]
        target = size if size > 0 else len(core) + len(allowed)
        order += _grow(order, pool, target, stop_floor(deck_id, target))
        out.append((tier, list(order)))
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


def write_opponents(out_dir="data/adventure/opponents", only=None):
    lib = load_library()
    os.makedirs(out_dir, exist_ok=True)
    for path in sorted(glob.glob("data/decks/*.json")):
        deck_id = os.path.basename(path)[:-5]
        if only and deck_id not in only:
            continue
        deck = json.load(open(path, encoding="utf-8"))
        aspects_by_tier = {t[0]: t[3] for t in OPPONENT_TIERS}
        lockouts_by_tier = {t[0]: t[2] for t in OPPONENT_TIERS}
        for tier, picked in ladder(deck_id, deck, lib):
            aspects = aspects_by_tier[tier]
            counts = {}
            for s in picked:
                counts[s["id"]] = counts.get(s["id"], 0) + 1
            # Banned cards are never in a precon; a deck lists them as adventure bombs instead, one
            # copy each, from the tiers that allow lockouts.
            if lockouts_by_tier[tier]:
                for bomb in deck.get("adventure_bombs", []):
                    counts[bomb] = 1
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
    # `--only=a,b` writes those families' tiers and leaves every other family's files alone.
    only = None
    for arg in sys.argv[1:]:
        if arg.startswith("--only="):
            only = set(arg.split("=", 1)[1].split(","))
    sizes = {}
    for name, total in write_opponents(only=only):
        sizes.setdefault(name.rsplit("_", 1)[1], []).append(total)
    print("opponent tiers written:", {k: (min(v), max(v)) for k, v in sizes.items()})
