"""Generates zenith/data/cards/starter/starter_set.json and the starter decks in
zenith/data/decks/, card-for-card on the community sample decks with each card's real
mechanics expressed in the Zenith effect schema. Original names only. Run from zenith/."""
import json, os

CARDS = []
IDS = set()


def add(**k):
    assert k["id"] not in IDS, k["id"]
    IDS.add(k["id"])
    CARDS.append(k)


def might(top, step):
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


def seal(id, title, seal_set, number, effects):
    add(id=id, title=title, type="seal", school="", seal_set=seal_set, seal_number=number, effects=effects, limit_per_deck=1)


def ally(id, title, alignment, top, step, power, surge=1, **k):
    add(id=id, title=title, type="ally", school="", character=title, alignment_only=alignment, limit_per_deck=1,
        aspects=[{"aspect": 1, "surge": surge, "might": might(top, step), "power": power}], **k)


# Each Aspect carries its own title, shown as "Bram Ashmark, Unquenchable". Vigil duelists harden
# into the watch; Pact duelists come due. See designs/zenith.md, Setting.
ASPECT_TITLES = {
    "duelist_alpha": ["Kindled", "Wildfire", "Unquenchable"],
    "duelist_beta": ["Matriarch", "Rising Water", "the Flood"],
    "duelist_gamma": ["Dormant", "Charged", "Unbound"],
    "duelist_delta": ["Captain", "Shrouded", "Lightless"],
    "duelist_epsilon": ["the Grinder", "Tempered", "Ironheart"],
    "duelist_zeta": ["Last Heir", "Unparried", "Spellcutter", "the Quiet Blade", "Peerless"],
    "duelist_eta": ["Greybeard", "Overgrown", "Deep-Rooted", "Heartwood", "Grovelord"],
}


def duelist(id, title, aspects):
    for a, name in zip(aspects, ASPECT_TITLES[id]):
        a["title"] = name
    add(id=id, title=title, type="duelist", school="", character=title, aspects=aspects)


def aspect(n, surge, top, step, power=None, constant=None, shield=None):
    d = {"aspect": n, "surge": surge, "might": might(top, step)}
    if power:
        d["power"] = power
    if constant:
        d["constant"] = constant
    if shield:
        d["shield"] = shield
    return d


ALPHA, BETA, GAMMA, DELTA, EPSILON, ZETA = "Bram Ashmark", "Dame Alder Rooke", "The Ninth Vessel", "Sable Draik", "Halden Quarr", "Caedan Vale"
ETA = "Osric Thornwald"

# ============================================================================
# Duelists
# ============================================================================
# Might is on the compact scale of data/strike_table.json (one band per ten points). Each aspect
# keeps the shape of the source ladder (where it crosses a band, how fast it climbs) but the
# spread between duelists at one aspect is at most a band or two, not five.
duelist("duelist_alpha", ALPHA, [
    aspect(1, 2, 24, 1, power={"attack": {"kind": "strike", "stages": 3}, "effects": [VIG(5), IFSTOP(E("draw", amount=1))]}),
    aspect(2, 5, 34, 1, power={"attack": {"kind": "art", "focused": True, "stages_from_table": True, "cost_stages": 0}, "effects": [OPP_ACC(-2)]}),
    aspect(3, 6, 46, 2, constant={"first_styled_unstoppable": True}),
])
duelist("duelist_beta", BETA, [
    aspect(1, 1, 12, 1, constant={"protect_allies": True, "turn_start": [WHEN(E("advance_aspect"), allies_min=5)]}),
    aspect(2, 2, 16, 1, power={"attack": {"kind": "strike", "variants": [{"when": {"ally_present": "Sir Edric Rooke"}, "stages": 4}]}}),
    aspect(3, 1, 40, 2, power={"effects": [ENTER(DISCARD_IN_PLAY("non_combat", all=True, remove=True))]}),
])
duelist("duelist_gamma", GAMMA, [
    aspect(1, 2, 16, 1, power={"defense": {"stops": "art"}, "effects": [VIG(3)]}),
    aspect(2, 1, 20, 1, shield="strike", power={"effects": [ENTER(VIG(5))]}),
    aspect(3, 2, 26, 1, power={"attack": {"kind": "art", "cost_stages": 0}, "effects": [E("draw", amount=2)]}),
])
duelist("duelist_delta", DELTA, [
    aspect(1, 2, 20, 1, constant={"allies_share": True, "ally_control_any_stage": True, "modifiers": [{"scope": "own", "kind": "any", "stages": 1, "per_ally": True}]}),
    aspect(2, 3, 28, 1, constant={"allies_share": True, "ally_control_any_stage": True, "damage_removes": True, "modifiers": [{"scope": "own", "kind": "any", "stages": 3}]}),
    aspect(3, 5, 36, 1, constant={"allies_share": True, "ally_control_any_stage": True, "attacks_focused": True}),
])
duelist("duelist_epsilon", EPSILON, [
    aspect(1, 1, 18, 1, constant={"on_attack": [ACC(1)]}),
    aspect(2, 2, 30, 1, constant={"entering_combat": [WHEN(E("remove_discard", amount=1), discard_top_school="steel"), WHEN(ACC(2), discard_top_school="steel"),
                                                    WHEN(FLOAT("modifier", scope="own", kind="strike", stages=2), discard_top_school="steel")]}),
    aspect(3, 4, 40, 1, power={"attack": {"kind": "strike", "stages": 4}, "uses": 2,
                             "effects": [WHEN(FLOAT("modifier", scope="own", kind="any", life=2), discard_top_school="steel")]}),
])
duelist("duelist_zeta", ZETA, [
    aspect(1, 2, 12, 1, power={"effects": [ENTER(E("look_at", amount=8, pick={"title_contains": "Sword"}, to="hand", play_if={"title_contains": "Swordplay"}, shuffle_after=True, **{"from": "top"}))]}),
    aspect(2, 2, 16, 1, power={"attack": {"kind": "strike", "only_first_attack": True, "stops_needed": 2}}),
    aspect(3, 3, 28, 1, power={"attack": {"kind": "strike", "stages": 5}, "effects": [IFS(FORBID("art_attacks", "opponent"))]}),
    aspect(4, 4, 34, 2, constant={"forbid_opponent": ["art_attacks"]}),
    aspect(5, 5, 40, 1, power={"effects": [ENTER(E("draw", amount=3), "active")]}),
])
# Low Might for its aspect all the way up; the powers feed on the discard pile instead.
duelist("duelist_eta", ETA, [
    aspect(1, 1, 14, 1, power={"effects": [ENTER(E("draw_discard", amount=1, **{"from": "bottom"}), "opposing")]}),
    aspect(2, 3, 20, 1, power={"attack": {"kind": "strike", "printed_life": 6}}),
    aspect(3, 3, 30, 2, power={"attack": {"kind": "strike", "stages": 6}, "effects": [IFS(E("draw_discard", amount=1, **{"from": "bottom"}))]}),
    aspect(4, 4, 33, 2, power={"attack": {"kind": "strike"}, "effects": [E("recover", amount=3, **{"from": "bottom"})]}),
    aspect(5, 5, 40, 1, constant={"modifiers": [{"scope": "own", "kind": "strike", "stages": 5}]}),
])

# ============================================================================
# Allies
# ============================================================================
ally("henchman_alpha", "Vesna Draik", "pact", 19, 1, {"attack": {"kind": "art", "printed_life": 6}, "effects": [IFS(DISCARD_IN_PLAY("ally", amount=1, choose=True))]})
ally("henchman_beta", "Brann Draik", "pact", 20, 1, {"attack": {"kind": "strike", "stages": 5}, "effects": [IFS(DISCARD_IN_PLAY("drill", amount=1, choose=True))]})
ally("henchman_gamma", "Quill Draik", "pact", 18, 1, {"attack": {"kind": "art", "printed_life": 6}, "effects": [IFS(WHEN({"may": True, "then": [OPP("choose_forbid_type", unless_energy_min=5)], **E("discard_hand", amount=1, random=False)}, hand_min=1))]})
ally("henchman_delta", "Halvard Draik", "pact", 17, 1, {"attack": {"kind": "strike", "stages": 5}, "effects": [IFS(OPP("discard_hand", amount=1, random=False))]})
ally("henchman_epsilon", "Pim", "pact", 6, 0, {"attack": {"kind": "strike"}, "effects": [IFS(E("draw_discard", amount=2, **{"from": "bottom"}))]})
ally("henchman_zeta", "The Fourteenth Vessel", "pact", 19, 1, {"attack": {"kind": "strike", "life": 2}, "effects": [E("discard_hand", amount=1, random=False)], "no_control_needed": True}, tags=["automaton"])
ally("companion_alpha", "Wren Rooke", "vigil", 18, 1, {"effects": [E("shuffle_discard", amount=1, per_personality=True)]})
ally("companion_beta", "Sir Edric Rooke", "vigil", 16, 1, {"attack": {"kind": "strike", "focused": True, "stages": 2, "life_per_opponent_seal": 2}})
ally("companion_gamma", "Tavin Vale", "vigil", 18, 1, {"attack": {"kind": "art", "printed_life": 6}, "effects": [E("recover", amount=2, **{"from": "bottom"})]}, surge=3)
ally("companion_delta", "Ansel Rooke", "vigil", 13, 1, {"attack": {"kind": "strike", "printed_stages": 5}, "effects": [IFSTOP(VIG("max"))]})

# ============================================================================
# Seals: two sets of seven
# ============================================================================
SUN = [
    [VIG("max", "duelist"), E("draw", amount=1)],
    [ACC(1), VIG(3)],
    [E("draw", amount=3), E("recover", amount=1)],
    [DISCARD_IN_PLAY("non_combat", all=True)],
    [VIG("max", "duelist"), ACC(2), E("draw", amount=2), E("recover", amount=2)],
    [OPP("discard_hand", amount=1), ACC(1)],
    [E("draw", amount=2), ACC(2)],
]
MOTH = [
    [E("draw_until", amount=3), ACC(2), OPP_ACC(-2)],
    [VIG(5), E("draw", amount=1)],
    [E("draw_discard", amount=3, **{"from": "bottom"}), VIG(5), OPP("remove_discard", amount=6)],
    [DISCARD_IN_PLAY("non_combat", all=True)],
    [E("recover", amount=3), ACC(1)],
    [OPP("discard_life", amount=3)],
    [E("draw", amount=3)],
]
MARBLE = [
    [E("draw_until", amount=3), E("recover", amount=2)],
    [OPP("lose_aspect")],
    [E("draw_discard", amount=3, **{"from": "bottom"})],
    [DISCARD_IN_PLAY("non_combat", all=True)],
    [VIG("max", "duelist"), ACC(1), E("recover", amount=2)],
    [{"may": True, **ACC(2), "otherwise": [OPP_ACC(-2)]}],
    [E("capture_seal")],
]
for i, eff in enumerate(MARBLE, 1):
    seal("marble_seal_%d" % i, "Marble Seal %d" % i, "marble", i, eff)
for i, eff in enumerate(SUN, 1):
    seal("sun_seal_%d" % i, "Sun Seal %d" % i, "sun", i, eff)
for i, eff in enumerate(MOTH, 1):
    seal("moth_seal_%d" % i, "Moth Seal %d" % i, "moth", i, eff)

# ============================================================================
# Grounds
# ============================================================================
grounds("trampled_crossroads", "Trampled Crossroads", forbid=[{"who": "all", "what": "non_combats"}])
grounds("ancient_grove", "Ancient Grove", modifiers=[{"scope": "own", "kind": "any", "stages": 2}],
        effects=[ENTER(SEARCH(card_type="drill", school="", to="play"))])
grounds("tollgate_yard", "Tollgate Yard", double_costs=True)
grounds("winter_fields", "Winter Fields", fervor_gain_cap=1)

# ============================================================================
# Relics and Masteries
# ============================================================================
add(id="blank_mask", title="The Blank Mask", type="relic", school="", reserve_size=13, uses_per_game=2, limit_per_deck=1,
    effects=[{"trigger": "relic_use", "op": "forbid", "who": "opponent", "what": "mastery", "duration": "turn"}])
add(id="debtors_ring", title="The Debtor's Ring", type="relic", school="", reserve_size=5, uses_per_game=1, limit_per_deck=1,
    effects=[{"trigger": "relic_use", "op": "search", "card_type": "ally", "to": "play", "stages": 3}])
add(id="lodestone_heart", title="The Lodestone Heart", type="relic", school="", reserve_size=10, limit_per_deck=1,
    relic_flags={"no_ascension_win": True, "fervor_shield": True, "aspect_shield": True})

# The latest printing: pay a life card to make an Pyre attack Focused, and Pyre blocks that stay
# in the game go under the Life Deck. The duelist's table damage is already high, so the Mastery
# spends on getting attacks past blocks instead of adding damage.
add(id="pyre_mastery", title="Pyre Mastery", type="mastery", school="pyre", limit_per_deck=1, blocks_to_bottom="pyre",
    effects=[{"trigger": "on_attack", "may": True, "op": "discard_life", "amount": 1, "when": {"source_school": "pyre", "attack_focused": False},
              "then": [{"op": "focus_attack"}]}])
# The later printing: a life card is thrown away on entering Combat and pays back in cards, two
# for a Steel card, one otherwise. It suits the 85-card build, which has the Life Deck to spend.
add(id="steel_mastery", title="Steel Mastery", type="mastery", school="steel", limit_per_deck=1,
    effects=[ENTER(E("draw_check", school="steel", discard=True, effects=[E("draw", amount=2)], else_effects=[E("draw", amount=1)]))])
add(id="shade_mastery", title="Shade Mastery", type="mastery", school="shade", limit_per_deck=1,
    modifiers=[{"scope": "own", "kind": "any", "stages": 1, "life": 1}, {"scope": "own", "kind": "any", "stages": 1, "life": 1, "school": "shade"}])
add(id="tide_mastery", title="Tide Mastery", type="mastery", school="tide", limit_per_deck=1, opponent_aspect_threshold=6,
    effects=[{"trigger": "on_success", "op": "fervor", "who": "opponent", "amount": -1, "when": {"source_school": "tide"}}])
add(id="freestyle_mastery", title="Freestyle Mastery", type="mastery", school="", limit_per_deck=1, protect_drills=True,
    effects=[ENTER(WHEN({"may": True, "then": [SEARCH(signature_of="duelist", to="hand")], **E("discard_hand", amount=1, random=False, filter="signature")}, hand_min=1))])
add(id="root_mastery", title="Root Mastery", type="mastery", school="root", limit_per_deck=1,
    effects=[ENTER({"may": True, **E("draw_discard", amount=1, if_school="root", effects=[VIG("max", "duelist")], **{"from": "bottom"})})])
add(id="storm_mastery", title="Storm Mastery", type="mastery", school="storm", limit_per_deck=1, art_cost_delta=-1,
    modifiers=[{"scope": "own", "kind": "art", "life": 1}])

# ============================================================================
# Freestyle staples
# ============================================================================
strike("no_quarter", "No Quarter", atk={"stages": 3},
       effects=[FORBID("end_combat"), FORBID("end_combat", "opponent"), FORBID("stop_all"), FORBID("stop_all", "opponent")])
# A named card in the source, so the duelist it is named for may run a fourth copy.
strike("relentless_fury", "Relentless Fury", atk={"stages": 4}, empower=2, character=ALPHA, effects=[AFTER_EMPOWER(FORBID("non_attack_actions")), AFTER_EMPOWER(FORBID("non_attack_actions", "opponent")), AFTER_EMPOWER(ACC(1))])
block("stillness", "Stillness", "any", "combat", defense={"stop_all": "any"}, limit_per_deck=1, use_in_attack=True, effects=[E("stop_all", kind="any")])
block("planted_feet", "Planted Feet", "strike", "strike", defense={"stop_all": "strike"}, remove_after_use=True, limit_per_deck=1)
block("unyielding_guard", "Unyielding Guard", "strike", "strike", defense={"stop_all": "strike"}, remove_after_use=True, limit_per_deck=1)
block("grounding_step", "Grounding Step", "art", "art", defense={"stop_all": "art"}, remove_after_use=True, limit_per_deck=1)
block("dead_air", "Dead Air", "art", "art", defense={"stop_all": "art"}, effects=[FORBID("art_attacks")], limit_per_deck=1)
add(id="will_not_break", title="Ashmark Will Not Break", type="combat", school="", only={"duelist_character": ALPHA}, limit_per_deck=1, use_in_attack=True,
    defense={"stops": "any"}, effects=[FLOAT("prevent_all")])
combat("terms_of_the_pact", "Terms of the Pact", [E("choose_stop_all_kind")], alignment_only="pact", remove_after_use=True, limit_per_deck=1)
block("wall_of_flame", "Ashmark's Wall of Flame", "any", "strike", defense={"stop_focused": True}, only={"duelist_character": ALPHA}, remove_after_use=True)
# A named card in the source, so the duelist it is named for may run a fourth copy and search for it.
add(id="cut_short", title="Cut Short", type="combat", school="", counter="combat", character=ZETA)
combat("cold_appraisal", "Cold Appraisal", [OPP("discard_hand", amount=1, random=False, chooser="owner")], alignment_only="pact")
combat("sever_the_leyline", "Sever the Leyline", [OPP("set_aspect", aspect=1)], alignment_only="pact", remove_after_use=True, limit_per_deck=1)
combat("respite", "Respite", [E("draw_discard", amount=2, **{"from": "top"}), OPP("energy", amount=5)], limit_per_deck=1)
combat("challenge", "Challenge", [OPP("discard_hand", amount=1, random=False, chooser="owner", to="deck")], alignment_only="vigil")
combat("overwhelming_aura", "Overwhelming Aura", [FORBID("strike_attacks", "opponent")], limit_per_deck=1)
combat("dragons_reckoning", "Dragon's Reckoning", [SEARCH(card_type="ally", source="either", to="play", stages=3), DISCARD_IN_PLAY("seal", all=True)], limit_per_deck=1)
combat("guardians_wrath", "Rooke's Wrath", [DISCARD_IN_PLAY("non_combat", all=True)], only={"duelist_character": BETA}, remove_after_use=True)
combat("desperate_ruin", "Desperate Ruin", [E("set_energy", amount=0), E("remove_discard", all=True), OPP("discard_life", amount=5)], remove_after_use=True, limit_per_deck=1)
# Played by Sir Edric while he is in control, onto Dame Alder wherever she stands.
combat("oath", "Husband's Vow", [E("attach", to="named", character=BETA)], only={"character": "Sir Edric Rooke"},
       attachment={"target": "named", "limit_attached": 1, "effects": [ENTER({"may": True, **E("draw_discard", amount=1, **{"from": "bottom"})})]})
combat("showmans_trick", "Showman's Trick", [SEARCH(card_type="attack", source="reserve", to="hand")], remove_after_use=True, limit_per_deck=2)
combat("clash_of_blood", "Clash of Blood", [FLOAT("modifier", scope="own", kind="any", life=2, per_ally=True, once=True), E("draw", amount=1)], remove_after_use=True)
combat("muster", "Muster", [VIG("max", "duelist"), SEARCH(card_type="ally", source="either", to="play", stages=3)], remove_after_use=True)
combat("sudden_reinforcement", "Sudden Reinforcement", [SEARCH(card_type="ally", source="either", to="play", stages=10)])
combat("sly_smirk", "Sly Smirk", [DISCARD_IN_PLAY("drill", all=True, remove=True)], alignment_only="pact", remove_after_use=True, limit_per_deck=1)
combat("truce", "Truce", [E("end_combat"), E("end_turn"), FLOAT("keep_hand", duration="next_turn_end")], school="steel", remove_after_use=True, limit_per_deck=1)
combat("mutual_escalation", "Mutual Escalation", [ACC(6), OPP_ACC(6), E("no_ascension_win")])
combat("transformation", "Transformation", [E("no_ascension_win"), E("set_aspect", aspect="fervor")])
combat("seekers_eye", "Seeker's Eye", [E("draw_check", check="named", effects=[E("draw", amount=1)])], remove_after_use=True, limit_per_deck=1)
combat("contemplation", "Contemplation", [E("draw_check", check="signature", effects=[E("draw", amount=1)])], limit_per_deck=1)
combat("grand_sweep", "Grand Sweep", [DISCARD_IN_PLAY("ally", "self", all=True, remove=True), DISCARD_IN_PLAY("ally", all=True, remove=True)], remove_after_use=True, limit_per_deck=2)

# Freestyle attacks
art("homing_bolt", "Homing Bolt", atk={"unstoppable": True, "no_prevent": True}, remove_after_use=True)
art("crashing_dive", "Crashing Dive", atk={"focused": True}, empower=2,
    effects=[IFS(AFTER_EMPOWER(OPP("remove_discard", all=True))), AFTER_EMPOWER(ACC(1))])
art("surging_blast", "Surging Blast", atk={}, alignment_only="pact", effects=[DISCARD_IN_PLAY("drill", amount=1, remove=True, choose=True)], tags=["automaton"])
strike("all_or_nothing", "All or Nothing", atk={"focused": True, "stages": 4, "no_stop_by": "strike"}, effects=[ACC(1)], remove_after_use=True)
strike("backhand", "Backhand", atk={}, effects=[E("draw_discard", amount=1, **{"from": "bottom"})], remove_after_use=True)
add(id="power_strike", title="Power Strike", type="art", school="", endurance=3,
    attack={"kind": "strike", "stages": 4, "variants": [{"when": {"aspect_min": 2}, "life": 4, "focused": True}]},
    effects=[IFS(SEARCH(card_type="drill", to="play"))])
art("lobbed_bolt", "Lobbed Bolt", atk={}, endurance=1,
    effects=[DISCARD_IN_PLAY("non_combat_only", "self", amount=1, choose=True, up_to=True), SEARCH(card_type="non_combat", to="play")], remove_after_use=True)
strike("erasure", "Erasure", atk={"stages": 6, "cost_stages": 6}, effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=6, up_to=True, choose=True))], remove_after_use=True)
art("supreme_push", "Supreme Push", atk={"focused": True}, effects=[WHEN({"may": True, "then": [FLOAT("modifier", scope="own", kind="any", life=7, once=True)], **E("lose_aspect")}, aspect_min=2)], remove_after_use=True)
art("extreme_assailment", "Draik's Assailment", atk={"focused": True, "printed_life": 5}, effects=[E("set_fervor", amount=2), OPP("set_fervor", amount=2), IFS({"may": True, **E("return_removed", card_type="ally")})], remove_after_use=True)
art("twin_palm_blitz", "Draik's Twin Palm", atk={"printed_life": 6}, only={"duelist_character": DELTA}, effects=[FLOAT("no_prevent")],
    remain_when={"when": {"allies_min": 2}, "remain": 1}, remove_after_use=True)
art("triple_torpedo", "Triple Torpedo", atk={"life_per_ally": 2}, endurance=2, effects=[ACC(1)], remain=1, remove_after_use=True)
art("captains_volley", "Captain's Volley", atk={"cost_stages": 3}, effects=[ACC(2)], remove_after_use=True)
art("clear_statement", "Clear Statement", atk={}, effects=[ACC(2), OPP_ACC(-2)], remove_after_use=True, limit_per_deck=1)
art("palm_charge", "Draik's Palm Charge", atk={"printed_life": 5}, effects=[IFS(E("attach", to="in_control"))],
    attachment={"target": "in_control", "modifiers": [{"scope": "own", "kind": "art", "life": 2}]})
art("prepared_stance", "Vessel's Prepared Stance", atk={}, effects=[WHEN(SEARCH(tag="automaton", exclude_title="Vessel's Prepared Stance", to="hand"), duelist_character=GAMMA)], remove_after_use=True, tags=["automaton"])
strike("focused_crushing_dive", "Crushing Dive", atk={"focused": True, "stages": 3}, endurance=2, empower=3,
       effects=[AFTER_EMPOWER(ACC(1)), AFTER_EMPOWER(OPP_ACC(-1)), AFTER_EMPOWER(DISCARD_IN_PLAY("ally", amount=1, choose=True)), AFTER_EMPOWER(VIG(3))], bottom_after_use=True)
strike("focused_sword_strike", "Focused Sword Strike", atk={"focused": True, "stages": 3}, effects=[IFS(OPP_ACC(-3))], remove_after_use=True)
strike("sword_slash", "Sword Slash", atk={"focused": True}, effects=[IFS(SEARCH(title_contains="Swordplay", to="play"))], remove_after_use=True)
strike("sword_sweep", "Sword Sweep", atk={"stages": 2}, effects=[IFS(DISCARD_IN_PLAY("ally", amount=4, up_to=True, choose=True))])
strike("sword_thrust", "Sword Thrust", atk={"stages": 2}, effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=2, choose=True))])
strike("sword_slice", "Vale's Sword Slice", atk={"stages": 4}, character=ZETA, effects=[ACC(1), IFS(SEARCH(title_contains="Sword", exclude_title="Vale's Sword Slice", to="hand"))])
strike("speedy_flight", "Vale's Speedy Flight", atk={"stages": 4}, character=ZETA, empower=2,
       effects=[AFTER_EMPOWER(OPP_ACC(-2)), AFTER_EMPOWER(WHEN(SEARCH(signature_of="duelist", source="discard", to="hand"), duelist_character=ZETA))], remove_after_use=True)
strike("back_bash", "Vale's Back Bash", atk={"stages": 4, "variants": [{"when": {"duelist_character": ZETA, "stopped_last_phase": True}, "effects": [OPP("skip_next_attack_phase")]}]},
       character=ZETA, endurance=2, effects=[ACC(1)])
strike("henchmans_charge", "Brann's Charge", atk={"stages": 4, "variants": [{"when": {"character": "Brann Draik"}, "effects": [DISCARD_IN_PLAY("non_combat", amount=1, choose=True), E("capture_seal")]}]},
       effects=[IFS(SEARCH(card_type="ally", to="play", stages=4))])
add(id="dual_strike", title="Halvard's Dual Strike", type="strike", school="", attack={"kind": "strike", "focused": True, "stages": 4, "variants": [{"when": {"character": "Halvard Draik"}, "effects": [OPP("discard_hand", amount=1, random=False)]}]},
    defense={"stops": "strike", "when": {"character": "Halvard Draik"}}, effects=[IFS(SEARCH(card_type="ally", to="play", stages=4))])
strike("leaping_rush", "Vesna's Leaping Rush", atk={"focused": True, "stages": 4, "variants": [{"when": {"character": "Vesna Draik"}, "effects": [FLOAT("no_ally_control", "opponent")]}]},
       effects=[IFS(SEARCH(card_type="ally", to="play", stages=4))])
strike("scatters_the_ashes", "Ashmark Scatters the Ashes", atk={"stages": 4}, endurance=1, effects=[OPP("remove_discard", amount=5), VIG(3)])
strike("reckless_lunge", "Reckless Lunge", atk={"stages": 1}, effects=[IFS(ACC(1))], remain=1, remove_after_use=True)
strike("steel_headshot", "Steel Headshot", "steel", atk={"life": 3, "no_prevent": True}, effects=[E("draw", amount=1), ACC(1)], limit_per_deck=1)

# Freestyle defenses
block("last_ward", "Last Ward", "any", "strike", defense={"stop_focused": "discard_hand"})
block("swift_counter", "Vale's Swift Counter", "strike", "strike", defense={"copy_attack": True}, character=ZETA)
block("elbow_block", "Elbow Block", "strike", "strike", effects=[SEARCH(card_type="hand_combat", source="discard", to="hand")], remove_after_use=True)
block("leg_catch", "Leg Catch", "strike", "strike", effects=[VIG("max", "duelist"), E("shuffle_discard", amount=3)])
block("swift_flight", "Swift Flight", "any", "strike", effects=[ACC(1), FLOAT("stop_next")])
block("storm_dodge", "Vessel's Dodge", "strike", "strike", character=GAMMA, effects=[SEARCH(school="storm", to="hand")], remove_after_use=True, tags=["automaton"])
add(id="knowing_smile", title="Vessel's Knowing Smile", type="non_combat", school="", defense={"stops": "strike"},
    effects=[WHEN(SEARCH(tag="automaton", source="discard", to="hand"), duelist_character=GAMMA)], remove_after_use=True, tags=["automaton"])
block("steel_supreme_power", "Quarr's Supreme Power", "any", "strike", "steel", only={"duelist_character": EPSILON}, remain=1, remove_after_use=True, limit_per_deck=2, unused_return="shuffle")

# Freestyle non-combats and drills
noncombat("recalled_lesson", "Recalled Lesson", [USE(SEARCH(card_type="attack", source="either", to="hand"))], limit_per_deck=1)
noncombat("focus_of_mind", "Focus of Mind", [USE(SEARCH(card_type="combat", to="hand"))], limit_per_deck=1)
noncombat("anticipation", "Anticipation", [ENTER(SEARCH(card_type="hand_combat", source="discard", to="hand"))], limit_per_deck=1)
noncombat("fortune", "Fortune", [USE(SEARCH(card_type="non_combat", to="play"))], limit_per_deck=1)
noncombat("bonding_rite", "Bonding Rite", [USE(E("bond", card="bonded_pair"))])
ally("bonded_pair", "Ansel and Tavin, Back to Back", "vigil", 44, 2,
     {"attack": {"kind": "strike", "printed_stages": 7}, "uses": 2, "effects": [WHEN({"may": True, "then": [E("focus_attack")], **E("discard_hand", amount=1, random=False)}, hand_min=1)]},
     surge=4, bond_of=["Ansel Rooke", "Tavin Vale"], bond_timer_max=5)
noncombat("seek_the_answer", "Vale Finds the Answer", [USE(SEARCH(signature_of="duelist", amount=2, to="hand"))], remove_after_use=True)
noncombat("stokes_the_coals", "Ashmark Stokes the Coals", [USE(VIG("max", "duelist")), USE(E("shuffle_discard", amount=5)), USE(ACC(1))], only={"duelist_character": ALPHA})
noncombat("open_challenge", "An Open Challenge", [{"trigger": "opponent_declare", **E("discard_hand", amount=1, random=False)}, {"trigger": "opponent_declare", **OPP("force_declare")}],
          start_in_play=True, limit_per_deck=1, remove_after_use=True)
noncombat("doubt", "Doubt", [USE(DISCARD_IN_PLAY("seal", amount=1, remove=True, choose=True))], remove_after_use=True, limit_per_deck=1)
add(id="heirloom_blade", title="The Vale Heirloom", type="non_combat", school="", effects=[USE(E("attach", to="duelist"))], limit_per_deck=1,
    attachment={"target": "duelist", "title_contains": "Sword", "damage_removes": True, "modifiers": [{"scope": "own", "kind": "any", "life": 3, "title_contains": "Sword"}]})
drill("bravado_drill", "Bravado Drill", start_in_play=True, limit_per_deck=1, effects=[ENTER(OPP_ACC(-2)), ENTER(VIG(2, "duelist"))])
drill("revision_drill", "Revision Drill", once_per_combat=True, limit_per_deck=1, effects=[USE(E("discard_hand", amount=1, random=False)), USE(E("draw", amount=2))])
drill("swordplay_drill", "Swordplay Drill", modifiers=[{"scope": "own", "kind": "any", "stages": 2, "title_contains": "Sword"}], promote_if_successful="Sword")
drill("devastation_drill", "Devastation Drill", modifiers=[{"scope": "own", "kind": "strike", "stages": 5}], discard_if_other_non_combats=True)
drill("ambush_drill", "Ambush Drill", alignment_only="vigil", limit_per_deck=2, effects=[PLACE(E("name_card"))])
drill("breakthrough_drill", "Breakthrough Drill", limit_per_deck=1, forbid=[{"who": "all", "what": "end_combat"}])
drill("absorbing_drill", "Absorbing Drill", defense={"stops": "art", "cost_life": 2})
drill("quickness_drill", "Quickness Drill", limit_per_deck=1, effects=[ENTER(E("draw_discard", amount=1, **{"from": "bottom"}))])
drill("confusion_drill", "Confusion Drill", limit_per_deck=1, forbid=[{"who": "all", "what": "seals"}])

# Freestyle cards of the Seal deck
block("schooled_block", "Schooled Block", "strike", "strike", effects=[ACC(1), SEARCH(card_type="drill", source="discard", to="play")])
combat("dream_duel", "Dream Duel", [E("end_combat"), E("recover", amount=1, **{"from": "bottom"})], remove_after_use=True)
# A Strike-type card that is no attack: playing it is the whole action.
add(id="seal_seizure", title="Seal Seizure", type="strike", school="", effects=[E("capture_seal")])
art("timely_advice", "Timely Advice", atk={"printed_life": 8}, effects=[OPP_ACC(-3)], remove_after_use=True, limit_per_deck=1)
art("power_burst", "Power Burst", atk={}, effects=[IFS(FORBID("art_attacks", "opponent"))])
art("blinding_flare", "Blinding Flare", atk={}, effects=[IFS(FORBID("strike_cards", "opponent"))])
art("sun_flare", "Sun Flare", atk={}, effects=[IFS(E("end_combat"))])
noncombat("dashed_plans", "Dashed Plans", [USE(DISCARD_IN_PLAY("non_combat", amount=2, remove=True, choose=True))], remove_after_use=True, limit_per_deck=1)
noncombat("gates_boon", "The Gate's Boon", [USE(E("end_combat")), USE(SEARCH(source="discard", amount=3, to="deck_shuffle"))], remove_after_use=True, limit_per_deck=1)
noncombat("windfall", "Windfall", [USE(SEARCH(card_type="seal", to="play"))])
noncombat("laid_plans", "Laid Plans", [USE(SEARCH(card_type="seal", to="play"))], remove_after_use=True)
noncombat("thin_smile", "Thin Smile", [USE(SEARCH(card_type="seal", to="play"))])
noncombat("borrowed_gauge", "Borrowed Gauge", [USE(SEARCH(card_type="seal", to="play"))], alignment_only="vigil", remove_after_use=True, limit_per_deck=1)
noncombat("sleight", "Sleight", [USE(E("capture_seal"))], remove_after_use=True)
noncombat("kins_rescue", "Kin's Rescue", [USE(FLOAT("prevent_all"))], alignment_only="vigil", remove_after_use=True, limit_per_deck=1,
          discard_if_seal="marble_seal_7", discard_if_seal_title="Marble Seal 7")
# Waits in play for an Art to land, then spends itself.
noncombat("eyes_beyond_the_gate", "Eyes Beyond the Gate", [{"trigger": "on_success", "may": True, "when": {"attack_kind": "art"},
          **SEARCH(card_type="seal", to="play"), "then": [E("capture_seal"), E("spend_source")]}], limit_per_deck=1)
drill("keepers_drill", "Keeper's Drill", protect_seals=True)
drill("guardian_drill", "Guardian Drill", alignment_only="vigil", once_per_combat=True, effects=[USE(SEARCH(source="hand", card_type="non_combat_any", to="play"))])

# ============================================================================
# Pyre
# ============================================================================
block("pyre_cinder_guard", "Pyre Cinder Guard", "strike", "strike", "pyre", effects=[ACC(2), VIG(2)])
block("pyre_searing_guard", "Pyre Searing Guard", "strike", "strike", "pyre", endurance=1, effects=[OPP("discard_life", amount=1), ACC(1), VIG(5)])
art("pyre_immolation", "Pyre Immolation", "pyre", atk={}, effects=[DISCARD_IN_PLAY("drill_or_ally", amount=1, remove=True, choose=True), ACC(1)])
art("pyre_ashfall", "Pyre Ashfall", "pyre", atk={"printed_life": 3}, empower=3,
    effects=[AFTER_EMPOWER(DISCARD_IN_PLAY("drill_or_ally", amount=1, remove=True, choose=True)), AFTER_EMPOWER(OPP_ACC(-2))])
strike("pyre_backdraft", "Pyre Backdraft", "pyre", atk={"stages": 3}, effects=[E("stop_all", kind="art"), FORBID("art_attacks"), OPP_ACC(-1)])
strike("pyre_comet_fall", "Pyre Comet Fall", "pyre", atk={"stages": 4}, remain=1, remove_after_use=True)
strike("pyre_scouring_flame", "Pyre Scouring Flame", "pyre", atk={}, effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=1, remove=True, choose=True)), ACC(1)])
strike("pyre_firestorm", "Pyre Firestorm", "pyre", atk={}, effects=[{"trigger": "before_damage", "may": True, "skip_damage": True, **DISCARD_IN_PLAY("drill_or_ally", all=True)}, ACC(1)])
strike("pyre_blazing_charge", "Pyre Blazing Charge", "pyre", atk={"stages": 3, "no_stop_by": "strike"}, effects=[ACC(1)], remove_after_use=True)
strike("pyre_furnace_breath", "Pyre Furnace Breath", "pyre", atk={"stages": 4}, effects=[ACC(2)], remove_after_use=True)
add(id="pyre_twin_flames", title="Pyre Twin Flames", type="combat", school="pyre", attack={"kind": "strike"}, effects=[ACC(1)], remain=1)
strike("pyre_snuffing", "Pyre Snuffing", "pyre", atk={"stages": 3, "variants": [{"when": {"opponent_fervor": 0}, "no_prevent": True, "effects": [ACC(1)]}]}, effects=[FORBID("powers", "opponent")])
strike("pyre_flashover", "Pyre Flashover", "pyre", atk={"stages": 3}, remain_when={"when": {"opponent_used_combat_card": True}, "remain": 2}, remove_after_use=True)
strike("pyre_flame_lash", "Pyre Flame Lash", "pyre", atk={"stages": 4}, endurance=2, empower=2, effects=[AFTER_EMPOWER(ACC(1)), IFSTOP(AFTER_EMPOWER(E("look_at", amount=5, pick={"card_type": "strike"}, to="hand", **{"from": "bottom"})))])
strike("pyre_kindling", "Pyre Kindling", "pyre", atk={"life": 3}, effects=[ACC(1), FLOAT("make_focused", school="pyre")])
strike("pyre_rekindling", "Pyre Rekindling", "pyre", atk={"stages": 6}, effects=[ACC(1), SEARCH(card_type="attack", school="pyre", source="discard", exclude_title="Pyre Rekindling", to="hand")], remove_after_use=True)

# ============================================================================
# Steel
# ============================================================================
block("steel_perfect_defense", "Steel Perfect Defense", "strike", "strike", "steel", defense={"when": {"higher_might": True}}, remain=9, remove_after_use=True, limit_per_deck=1)
block("steel_stop", "Steel Stop", "any", "strike", "steel", effects=[VIG(7)])
block("steel_brace", "Steel Brace", "any", "art", "steel", effects=[ACC(1), SEARCH(title_contains="Truce", to="hand")], remove_after_use=True)
block("steel_wrist_block", "Steel Wrist Block", "strike", "strike", "steel", effects=[OPP("energy", amount=-3, no_overflow=True)])
art("steel_power_beam", "Steel Power Beam", "steel", atk={}, empower=3, effects=[AFTER_EMPOWER(FORBID("mastery", "opponent")), AFTER_EMPOWER(FORBID("drills", "opponent"))], remove_after_use=True)
art("steel_might", "Quarr's Might", "steel", atk={"printed_life": 6}, effects=[WHEN(FORBID("combat_cards", "opponent"), character=EPSILON)], remove_after_use=True)
strike("steel_crushing_smash", "Quarr's Crushing Smash", "steel", character=EPSILON,
       atk={"life": 2, "variants": [{"when": {"character": EPSILON}, "stages": 3, "effects": [DISCARD_IN_PLAY("non_combat", amount=1, choose=True)]}]},
       endurance_when={"value_if": {"duelist_character": EPSILON}, "then": 6, "else": 3})
strike("steel_gut_kick", "Steel Gut Kick", "steel", atk={"stages": 3}, endurance=2, effects=[OPP_ACC(-1), IFS(SEARCH(card_type="seal", to="play"))], remove_after_use=True)
strike("steel_dashing_kick", "Steel Dashing Kick", "steel", atk={"stages": 8}, effects=[ACC(1)])
strike("steel_destiny", "Steel Destiny", "steel", atk={"stages": 3}, remain=1, remove_after_use=True)
strike("steel_bulk", "Steel Bulk", "steel", atk={"stages": 3}, empower=2, effects=[AFTER_EMPOWER(FLOAT("no_gain", "opponent", "next_turn_end"))], remove_after_use=True)
strike("steel_face_jab", "Steel Face Jab", "steel", atk={"stages": 3}, effects=[IFS(OPP("next_attack_tax", amount=2))])
add(id="steel_youth_bruise", title="Steel Youth Bruise", type="art", school="steel", endurance=2, attack={"kind": "strike", "stages": 4}, effects=[E("shuffle_discard", amount=3)], remove_after_use=True)
strike("steel_rapid_slam", "Steel Rapid Slam", "steel", atk={"focused": True, "stages": 5}, effects=[FLOAT("after_use_bottom", school="steel")])
art("steel_triple_blast", "Steel Triple Blast", "steel", atk={"focused": True, "printed_life": 3}, effects=[IFS(E("draw", amount=1))])
strike("steel_heads_up","Steel Heads Up", "steel", atk={}, effects=[IFS(DISCARD_IN_PLAY("non_combat_or_ally", amount=2, choose=True, up_to=True))])
strike("steel_charge", "Steel Charge", "steel", atk={"printed_stages": 7, "variants": [{"when": {"higher_might": True}, "effects": [FORBID("mastery", "opponent", "turn")]}]})
strike("steel_fist_attack", "Steel Fist Attack", "steel", atk={"stages": 4}, endurance=3)
strike("steel_direct_strike", "Steel Direct Strike", "steel", atk={"stages": 3, "life": 2}, endurance=4)
strike("steel_cliff_slam", "Steel Cliff Slam", "steel", atk={"stages": 3, "variants": [{"when": {"higher_might": True}, "effects": [DISCARD_IN_PLAY("non_combat", amount=1, choose=True)]}]})

# ============================================================================
# Shade
# ============================================================================
strike("shade_pivot_kick", "Shade Pivot Kick", "shade", atk={"stages": 3}, effects=[DISCARD_IN_PLAY("non_combat_or_ally", amount=1, choose=True), OPP("discard_hand", amount=1, random=False)])
block("shade_defensive_aura", "Shade Defensive Aura", "any", "combat", "shade", defense={"cost_stages": 1})
block("shade_buffer_block", "Shade Buffer Block", "any", "strike", "shade", effects=[SEARCH(source="discard", has_effect={"op": "discard_hand", "who": "opponent"}, to="hand")], remove_after_use=True)
add(id="shade_turning_kick", title="Shade Turning Kick", type="art", school="shade", attack={"kind": "art", "printed_life": 5}, defense={"stops": "strike"}, effects=[ACC(1)])
art("shade_chaos_detonation", "Shade Chaos Detonation", "shade", atk={"cost_stages": 3}, effects=[IFS(OPP("discard_hand", amount=2, random=False))])
add(id="shade_body_ruin", title="Shade Body Ruin", type="strike", school="shade", attack={"kind": "strike", "stages": 4}, defense={"stops": "strike"},
    effects=[OPP("discard_hand", amount=1)], remove_after_use=True)
strike("shade_swivel_kick", "Shade Swivel Kick", "shade", atk={"stages": 3}, effects=[OPP("remove_hand", amount=1)])
strike("shade_right_kick", "Shade Right Kick", "shade", atk={"stages": 2}, endurance=1, empower=3, alignment_only="pact", effects=[AFTER_EMPOWER(OPP("discard_hand", amount=1, random=False))], remove_after_use=True)

# ============================================================================
# Tide
# ============================================================================
block("tide_energy_guard", "Tide Energy Guard", "art", "art", "tide", effects=[FLOAT("prevent_art_life")], remove_after_use=True, limit_per_deck=1)
block("tide_defensive_flight", "Tide Defensive Flight", "strike", "strike", "tide", effects=[E("pay_energy", per=1, then=[OPP_ACC(-1)])])
add(id="tide_round_throw", title="Tide Round Throw", type="strike", school="tide", attack={"kind": "strike", "stages": 5}, defense={"stops": "art"}, effects=[OPP_ACC(-1)])
strike("tide_betrayal", "Tide Betrayal", "tide", atk={}, effects=[DISCARD_IN_PLAY("non_combat_or_ally", amount=1, remove=True, choose=True)])
add(id="tide_arm_blast", title="Tide Arm Blast", type="art", school="tide", attack={"kind": "art", "printed_life": 5}, defense={"stops": "strike"})
art("tide_double_blast", "Tide Double Blast", "tide", atk={"printed_life": 3, "life_from_surge": True}, remain=1)
art("tide_draining_blast", "Tide Draining Blast", "tide", atk={"cost_stages": 0, "pay_stages": {"per": 2, "life": 1}})
art("tide_healing_ray", "Tide Healing Ray", "tide", atk={}, effects=[SEARCH(card_type="ally", source="discard", to="play", stages=3), IFS(VIG("max", "last_searched"))], remove_after_use=True)
art("tide_terror", "Tide Terror", "tide", atk={"printed_life": 3}, effects=[SEARCH(to="hand")], remove_after_use=True, limit_per_deck=1)
art("tide_transformation", "Tide Transformation", "tide", atk={"printed_life": 5}, effects=[ACC(1), IFS(SEARCH(card_type="grounds", to="play"))])
art("tide_alliance", "Tide Alliance", "tide", atk={"printed_life": 5, "variants": [{"when": {"performed_by": "ally"}, "focused": True}]}, empower=3,
    effects=[AFTER_EMPOWER(WHEN(DISCARD_IN_PLAY("drill", amount=1, choose=True), allies_min=1))])
art("twin_blow", "Twin Blow", "tide", atk={"printed_life": 5, "variants": [{"when": {"ally_present": "Sir Edric Rooke"}, "focused": True, "life": 4}]},
    effects=[OPP_ACC(-2), ACC(1), {"trigger": "on_wound", "at": "fight_back", "may": True, **SEARCH(card_type="ally", to="play")}])

# ============================================================================
# Storm
# ============================================================================
block("storm_energy_guard", "Storm Energy Guard", "art", "art", "storm", endurance=3, effects=[FLOAT("modifier", scope="own", kind="any", stages=2), ACC(1)])
add(id="storm_setup", title="Storm Setup", type="art", school="storm", attack={"kind": "art"}, defense={"stops": "strike"}, remove_after_use=True)
art("storm_scatter_shot", "Storm Scatter Shot", "storm", atk={"printed_life": 5}, remain=1, remove_after_use=True)
art("storm_glaring_bolt", "Storm Glaring Bolt", "storm", atk={}, effects=[DISCARD_IN_PLAY("non_combat_or_ally", amount=1, remove=True, choose=True)])
art("storm_obliteration", "Storm Obliteration", "storm", atk={}, empower=3, effects=[AFTER_EMPOWER(DISCARD_IN_PLAY("drill", amount=3, up_to=True, choose=True)), AFTER_EMPOWER(FLOAT("endurance_boost"))])
art("storm_rage", "Storm Rage", "storm", atk={"printed_life": 5}, effects=[ACC(2)])
strike("storm_massacre", "Storm Massacre", "storm", atk={"stages": 4}, endurance=2, empower=2, effects=[AFTER_EMPOWER(FLOAT("no_prevent")), IFS(AFTER_EMPOWER(DISCARD_IN_PLAY("freestyle_drill", "self", all=True, remove=True))), IFS(AFTER_EMPOWER(DISCARD_IN_PLAY("freestyle_drill", all=True, remove=True)))])
strike("storm_uppercut", "Storm Uppercut", "storm", atk={"stages": 4}, effects=[WHEN({"may": True, "then": [SEARCH(card_type="art", to="hand")], **E("energy", amount=-2)}, energy_min=2)], remove_after_use=True, limit_per_deck=1)
strike("storm_strength", "Storm Strength", "storm", atk={"stages": 2}, endurance=2, effects=[VIG("max", "duelist")])

# ============================================================================
# Root
# ============================================================================
add(id="root_bolt", title="Root Thorn Volley", type="combat", school="root", attack={"kind": "art"}, effects=[SEARCH(card_type="art", to="hand")], remove_after_use=True)
strike("root_dash", "Root Boar Rush", "root", atk={"stages": 5}, effects=[VIG("max", "duelist"), E("shuffle_discard", amount=4)], remove_after_use=True)
block("root_energy_deflection", "Root Barkskin Deflection", "art", "art", "root", effects=[E("shuffle_discard", amount=2, **{"from": "top_and_bottom"})])
block("root_energy_catch", "Root Rain Catch", "art", "art", "root", effects=[VIG(3)])
block("root_firm_stance", "Root Oaken Stance", "strike", "strike", "root", effects=[OPP_ACC(-1)])
combat("root_energy_focus", "Root Grove Focus", [E("draw_discard", amount=1, if_school="root", effects=[SEARCH(card_type="art", to="hand")], **{"from": "bottom"})],
       school="root", remove_after_use=True)
drill("root_preparation_drill", "Root Tracker's Drill", "root", effects=[ENTER(E("look_at", amount=5, rearrange=True, **{"from": "top"}), "opposing")])
art("root_destruction_blast", "Root Uprooting Blast", "root", atk={"printed_life": 7, "cost_stages": 4})
art("root_dragon_blast", "Root Wyrmwood Blast", "root", atk={"life_per_set_seal": "marble"},
    effects=[SEARCH(source="discard", amount_per_set_seal="marble", to="deck_bottom")])

# ============================================================================
# Decks
# ============================================================================
os.makedirs("data/cards/starter", exist_ok=True)
with open("data/cards/starter/starter_set.json", "w", encoding="utf-8", newline="\n") as f:
    json.dump({"_note": "Starter set. Generated; mechanics follow the reference sample decks, names are original.", "cards": CARDS}, f, indent=1)
    f.write("\n")
print("cards:", len(CARDS))

VALID = {c["id"] for c in CARDS}


# Playstyle file under data/ai/profiles for an AI playing the deck. Decks not listed play the defaults.
AI_PROFILES = {"shade_henchmen": "shade_henchmen", "steel_beatdown": "steel_beatdown", "pyre_beatdown": "pyre_beatdown",
               "storm_volley": "storm_volley", "tide_companions": "tide_companions",
               "freestyle_swords": "freestyle_swords", "root_seals": "root_seals"}


# What kind of deck each loadout is, as the sample-deck sheet labels them: (archetype, difficulty,
# subthemes). Ids are the ones engine/archetype.gd knows. Shown on the select screen and in the
# duel, and read by the AI's Reserve swap.
DECK_KINDS = {
    "pyre_beatdown": ("strike_beatdown", "easy", ["fervor"]),
    "steel_beatdown": ("strike_beatdown", "easy", ["energy", "draw", "might"]),
    "shade_henchmen": ("allies", "easy", ["disruption"]),
    "tide_companions": ("allies", "medium", ["bond", "arts"]),
    "freestyle_swords": ("drills", "medium", ["strikes", "swords"]),
    "storm_volley": ("art_beatdown", "medium", ["automatons", "draw", "fervor"]),
    "root_seals": ("seals", "medium", ["arts", "drills"]),
}


def deck(fname, name, duelist_id, aspects, style, alignment, mastery_id, relic_id, reserve, entries):
    for i, _ in entries:
        assert i in VALID, i
    for i in reserve:
        assert i in VALID, i
    total = sum(n for _, n in entries)
    d = {"name": name, "duelist": duelist_id, "aspects": aspects, "style": style, "alignment": alignment,
         "mastery": mastery_id, "relic": relic_id, "reserve": reserve}
    if fname in DECK_KINDS:
        d["archetype"], d["difficulty"], d["subthemes"] = DECK_KINDS[fname]
    if fname in AI_PROFILES:
        d["ai_profile"] = AI_PROFILES[fname]
    d["cards"] = [{"id": i, "count": n} for i, n in entries]
    with open("data/decks/%s.json" % fname, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    print("%-18s life %d, reserve %d" % (fname, total, len(reserve)))


deck("pyre_beatdown", "Ashmark the Pyromancer", "duelist_alpha", 3, "pyre", "pact", "pyre_mastery", "blank_mask",
     ["open_challenge", "pyre_ashfall", "pyre_ashfall", "pyre_ashfall", "revision_drill", "scatters_the_ashes", "scatters_the_ashes", "scatters_the_ashes", "tollgate_yard",
      "pyre_searing_guard", "pyre_searing_guard", "pyre_searing_guard"], [
    ("trampled_crossroads", 3),
    ("stokes_the_coals", 3), ("recalled_lesson", 1), ("bravado_drill", 1),
    ("cold_appraisal", 3), ("cut_short", 3), ("sever_the_leyline", 1),
    ("stillness", 1), ("will_not_break", 1), ("terms_of_the_pact", 1), ("planted_feet", 1), ("unyielding_guard", 1), ("grounding_step", 1), ("dead_air", 1),
    ("pyre_cinder_guard", 3), ("wall_of_flame", 3),
    ("pyre_immolation", 3),
    ("pyre_backdraft", 3), ("pyre_comet_fall", 3), ("pyre_scouring_flame", 3), ("pyre_firestorm", 3), ("pyre_blazing_charge", 3),
    ("pyre_furnace_breath", 3), ("no_quarter", 3), ("all_or_nothing", 3), ("pyre_twin_flames", 3), ("relentless_fury", 4), ("reckless_lunge", 3),
    ("pyre_snuffing", 3), ("pyre_flashover", 3), ("pyre_flame_lash", 3), ("pyre_kindling", 3), ("pyre_rekindling", 3)])

deck("steel_beatdown", "Quarr the Ironblood", "duelist_epsilon", 3, "steel", "pact", "steel_mastery", "blank_mask",
     ["open_challenge", "steel_headshot", "mutual_escalation", "mutual_escalation", "mutual_escalation", "doubt", "sly_smirk"], [
    ("trampled_crossroads", 3),
    ("moth_seal_1", 1), ("moth_seal_3", 1), ("moth_seal_4", 1),
    ("cold_appraisal", 3), ("cut_short", 3), ("truce", 1),
    ("stillness", 1), ("steel_perfect_defense", 1), ("steel_stop", 3), ("steel_brace", 3), ("steel_supreme_power", 2),
    ("steel_power_beam", 3), ("steel_might", 3),
    ("no_quarter", 3), ("relentless_fury", 3), ("steel_crushing_smash", 4), ("steel_gut_kick", 3), ("backhand", 1),
    ("steel_dashing_kick", 3), ("steel_destiny", 3), ("steel_bulk", 3), ("steel_face_jab", 3),
    # The 85-card build: more Steel attacks to feed the Mastery, Endurance in place of blocks.
    ("steel_youth_bruise", 3), ("steel_rapid_slam", 3), ("steel_heads_up", 2), ("steel_charge", 3),
    ("steel_fist_attack", 3), ("steel_direct_strike", 3), ("steel_cliff_slam", 3), ("steel_wrist_block", 3), ("steel_triple_blast", 2)])

deck("shade_henchmen", "The Draik Company", "duelist_delta", 3, "shade", "pact", "shade_mastery", "debtors_ring",
     ["doubt", "shade_pivot_kick", "shade_pivot_kick", "shade_pivot_kick"], [
    ("trampled_crossroads", 3),
    ("henchman_alpha", 1), ("henchman_beta", 1), ("henchman_gamma", 1), ("henchman_delta", 1), ("henchman_epsilon", 1),
    ("sun_seal_3", 1), ("sun_seal_5", 1),
    ("cold_appraisal", 3), ("cut_short", 3), ("sly_smirk", 1), ("muster", 3), ("sudden_reinforcement", 3),
    ("stillness", 1), ("shade_defensive_aura", 3), ("shade_buffer_block", 3),
    ("shade_turning_kick", 3), ("shade_chaos_detonation", 3), ("extreme_assailment", 3), ("palm_charge", 1), ("twin_palm_blitz", 3),
    ("triple_torpedo", 3), ("surging_blast", 3), ("homing_bolt", 3), ("crashing_dive", 3), ("captains_volley", 1),
    ("no_quarter", 3), ("relentless_fury", 3), ("shade_body_ruin", 3), ("shade_swivel_kick", 3), ("shade_right_kick", 3),
    ("henchmans_charge", 3), ("dual_strike", 3), ("leaping_rush", 3)])

deck("tide_companions", "The Rooke Coven", "duelist_beta", 3, "tide", "vigil", "tide_mastery", "debtors_ring",
     ["supreme_push", "lobbed_bolt", "erasure", "bonded_pair"], [
    ("companion_alpha", 1), ("companion_beta", 1), ("companion_gamma", 1), ("companion_delta", 1),
    ("trampled_crossroads", 3),
    ("challenge", 3), ("cut_short", 3), ("overwhelming_aura", 1), ("dragons_reckoning", 1), ("muster", 3), ("guardians_wrath", 3),
    ("desperate_ruin", 1), ("oath", 2), ("showmans_trick", 2), ("clash_of_blood", 3),
    ("stillness", 1), ("unyielding_guard", 1), ("planted_feet", 1), ("grounding_step", 1), ("tide_energy_guard", 1), ("tide_defensive_flight", 3), ("last_ward", 2),
    ("no_quarter", 3), ("tide_round_throw", 3), ("tide_betrayal", 3), ("erasure", 1),
    ("tide_arm_blast", 3), ("homing_bolt", 3), ("tide_double_blast", 3), ("tide_draining_blast", 3), ("tide_healing_ray", 3), ("tide_terror", 1),
    ("twin_blow", 3), ("tide_transformation", 3), ("tide_alliance", 3),
    ("recalled_lesson", 1), ("fortune", 1), ("focus_of_mind", 1), ("bonding_rite", 2)])

deck("freestyle_swords", "Vale the Swordmaster", "duelist_zeta", 5, "freestyle", "vigil", "freestyle_mastery", "blank_mask",
     ["open_challenge", "doubt", "confusion_drill", "revision_drill", "fortune", "mutual_escalation"], [
    ("ancient_grove", 3),
    ("challenge", 3), ("cut_short", 4), ("seekers_eye", 1), ("overwhelming_aura", 1), ("contemplation", 1),
    ("stillness", 1), ("unyielding_guard", 1), ("planted_feet", 1), ("swift_counter", 4), ("elbow_block", 3), ("leg_catch", 3), ("swift_flight", 3),
    ("no_quarter", 3), ("relentless_fury", 3), ("power_strike", 3), ("sword_slice", 4), ("speedy_flight", 3), ("back_bash", 2),
    ("focused_sword_strike", 3), ("sword_slash", 3), ("sword_sweep", 3), ("sword_thrust", 3),
    ("lobbed_bolt", 1),
    ("swordplay_drill", 3), ("devastation_drill", 3), ("ambush_drill", 2), ("breakthrough_drill", 1), ("absorbing_drill", 1), ("quickness_drill", 1),
    ("seek_the_answer", 3), ("anticipation", 1), ("recalled_lesson", 1), ("heirloom_blade", 1), ("bravado_drill", 1)])

deck("storm_volley", "The Corven Collegium", "duelist_gamma", 3, "storm", "pact", "storm_mastery", "lodestone_heart",
     ["doubt", "grand_sweep", "grand_sweep", "storm_glaring_bolt", "storm_massacre", "lobbed_bolt", "clear_statement", "focused_crushing_dive", "storm_obliteration"], [
    ("henchman_zeta", 1),
    ("trampled_crossroads", 3),
    ("sun_seal_1", 1), ("sun_seal_3", 1), ("sun_seal_5", 1),
    ("cold_appraisal", 3), ("cut_short", 3), ("sly_smirk", 1), ("showmans_trick", 2), ("respite", 1), ("mutual_escalation", 3), ("transformation", 3), ("overwhelming_aura", 1),
    ("stillness", 1), ("storm_dodge", 4), ("knowing_smile", 3), ("leg_catch", 3), ("storm_energy_guard", 3),
    ("storm_setup", 1), ("storm_scatter_shot", 2), ("storm_glaring_bolt", 2), ("storm_obliteration", 1), ("storm_rage", 3), ("extreme_assailment", 3),
    ("captains_volley", 3), ("crashing_dive", 3), ("prepared_stance", 3), ("surging_blast", 3), ("homing_bolt", 3), ("palm_charge", 2),
    ("no_quarter", 3), ("relentless_fury", 3), ("storm_massacre", 1), ("storm_uppercut", 1), ("storm_strength", 1),
    ("recalled_lesson", 1), ("focus_of_mind", 1), ("anticipation", 1), ("bravado_drill", 1)])
# No Relic and no Reserve: the list this follows runs none, and the Root allowance of 90 is
# spent on 84 life cards.
deck("root_seals", "The Thornwald Grove", "duelist_eta", 5, "root", "vigil", "root_mastery", "", [], [
    ("winter_fields", 3),
    ("marble_seal_1", 1), ("marble_seal_2", 1), ("marble_seal_3", 1), ("marble_seal_4", 1), ("marble_seal_5", 1), ("marble_seal_6", 1), ("marble_seal_7", 1),
    ("windfall", 1), ("laid_plans", 1), ("thin_smile", 1), ("borrowed_gauge", 1), ("sleight", 1), ("eyes_beyond_the_gate", 1), ("seal_seizure", 3),
    ("fortune", 1), ("dashed_plans", 1), ("gates_boon", 1), ("kins_rescue", 1), ("anticipation", 1),
    ("keepers_drill", 3), ("guardian_drill", 1), ("absorbing_drill", 1), ("quickness_drill", 1), ("root_preparation_drill", 1),
    ("challenge", 3), ("cut_short", 3), ("dream_duel", 3), ("grand_sweep", 2), ("overwhelming_aura", 1), ("respite", 1), ("root_energy_focus", 1),
    ("stillness", 1), ("planted_feet", 1), ("unyielding_guard", 1), ("grounding_step", 1), ("schooled_block", 2), ("leg_catch", 3),
    ("root_energy_deflection", 3), ("root_energy_catch", 3), ("root_firm_stance", 2),
    ("root_bolt", 3), ("root_dash", 3), ("root_destruction_blast", 3), ("root_dragon_blast", 3),
    ("power_burst", 3), ("blinding_flare", 3), ("sun_flare", 3), ("timely_advice", 1)])
print("decks written")
