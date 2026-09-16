"""Generates zenith/data/cards/starter/starter_set.json and the six starter decks in
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
def ACC(n): return E("acclaim", amount=n)
def OPP_ACC(n): return OPP("acclaim", amount=n)
def VIG(n, target=None):
    d = E("vigor", amount=n)
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
def strike(id, title, guild="", atk=None, **k):
    add(id=id, title=title, type="strike", guild=guild, attack={"kind": "strike", **(atk or {})}, **k)


def art(id, title, guild="", atk=None, **k):
    add(id=id, title=title, type="art", guild=guild, attack={"kind": "art", **(atk or {})}, **k)


def block(id, title, stops, typ, guild="", defense=None, **k):
    add(id=id, title=title, type=typ, guild=guild, defense={"stops": stops, **(defense or {})}, **k)


def combat(id, title, effects, guild="", **k):
    add(id=id, title=title, type="combat", guild=guild, effects=effects, **k)


def noncombat(id, title, effects=None, guild="", **k):
    d = dict(id=id, title=title, type="non_combat", guild=guild, **k)
    if effects:
        d["effects"] = effects
    add(**d)


def drill(id, title, guild="", **k):
    add(id=id, title=title, type="drill", guild=guild, **k)


def grounds(id, title, **k):
    add(id=id, title=title, type="grounds", guild="", limit_per_deck=3, **k)


def token(id, title, token_set, number, effects):
    add(id=id, title=title, type="token", guild="", token_set=token_set, token_number=number, effects=effects, limit_per_deck=1)


def ally(id, title, alignment, top, step, power, surge=1, **k):
    add(id=id, title=title, type="ally", guild="", character=title, alignment_only=alignment, limit_per_deck=1,
        tiers=[{"tier": 1, "surge": surge, "might": might(top, step), "power": power}], **k)


def fighter(id, title, tiers):
    add(id=id, title=title, type="fighter", guild="", character=title, tiers=tiers)


def tier(n, surge, top, step, power=None, constant=None, shield=None):
    d = {"tier": n, "surge": surge, "might": might(top, step)}
    if power:
        d["power"] = power
    if constant:
        d["constant"] = constant
    if shield:
        d["shield"] = shield
    return d


ALPHA, BETA, GAMMA, DELTA, EPSILON, ZETA = "Bram Ashmark", "Dame Alder Rooke", "The Ninth Vessel", "Sable Draik", "Halden Quarr", "Caedan Vale"

# ============================================================================
# Fighters
# ============================================================================
fighter("fighter_alpha", ALPHA, [
    tier(1, 2, 4500000, 100000, power={"attack": {"kind": "strike", "stages": 3}, "effects": [VIG(5), IFSTOP(E("draw", amount=1))]}),
    tier(2, 6, 11200000, 25000, power={"attack": {"kind": "art", "focused": True, "stages_from_table": True, "cost_stages": 0}, "effects": [OPP_ACC(-2)]}),
    tier(3, 8, 15000000, 750000, constant={"first_styled_unstoppable": True}),
])
fighter("fighter_beta", BETA, [
    tier(1, 1, 1000000, 100000, constant={"protect_allies": True, "turn_start": [WHEN(E("advance_tier"), allies_min=5)]}),
    tier(2, 2, 1400000, 100000, power={"attack": {"kind": "strike", "variants": [{"when": {"ally_present": "Sir Edric Rooke"}, "stages": 4}]}}),
    tier(3, 1, 7000000, 500000, power={"effects": [ENTER(DISCARD_IN_PLAY("non_combat", all=True, remove=True))]}),
])
fighter("fighter_gamma", GAMMA, [
    tier(1, 2, 1200000, 100000, power={"defense": {"stops": "art"}, "effects": [WHEN(VIG(3), focus=True)]}),
    tier(2, 1, 1250000, 100000, shield="strike", power={"effects": [ENTER(WHEN(VIG(5), focus=True))]}),
    tier(3, 2, 1300000, 100000, power={"attack": {"kind": "art", "cost_stages": 0}, "effects": [E("draw", amount=1), WHEN(E("draw", amount=1), focus=True)]}),
])
fighter("fighter_delta", DELTA, [
    tier(1, 2, 1900000, 50000, constant={"allies_share": True, "ally_control_any_stage": True, "modifiers": [{"scope": "own", "kind": "any", "stages": 1, "per_ally": True}]}),
    tier(2, 3, 2900000, 100000, constant={"allies_share": True, "ally_control_any_stage": True, "damage_removes": True, "modifiers": [{"scope": "own", "kind": "any", "stages": 3}]}),
    tier(3, 5, 4000000, 100000, constant={"allies_share": True, "ally_control_any_stage": True, "attacks_focused": True}),
])
fighter("fighter_epsilon", EPSILON, [
    tier(1, 1, 340000, 20000, constant={"on_attack": [ACC(1)]}),
    tier(2, 2, 2800000, 20000, constant={"entering_combat": [WHEN(E("remove_discard", amount=1), discard_top_guild="steel"), WHEN(ACC(2), discard_top_guild="steel"),
                                                             WHEN(FLOAT("modifier", scope="own", kind="strike", stages=2), discard_top_guild="steel")]}),
    tier(3, 4, 4100000, 20000, power={"attack": {"kind": "strike", "stages": 4}, "uses": 2,
                                      "effects": [WHEN(FLOAT("modifier", scope="own", kind="any", life=2), discard_top_guild="steel")]}),
])
fighter("fighter_zeta", ZETA, [
    tier(1, 2, 1000000, 50000, power={"effects": [ENTER(E("look_at", amount=8, pick={"title_contains": "Sword"}, to="hand", play_if={"title_contains": "Swordplay"}, shuffle_after=True, **{"from": "top"}))]}),
    tier(2, 2, 1150000, 50000, power={"attack": {"kind": "strike", "only_first_attack": True, "stops_needed": 2}}),
    tier(3, 3, 3100000, 200000, power={"attack": {"kind": "strike", "stages": 5}, "effects": [IFS(FORBID("art_attacks", "opponent"))]}),
    tier(4, 4, 4100000, 300000, constant={"forbid_opponent": ["art_attacks"]}),
    tier(5, 5, 4700000, 100000, power={"effects": [ENTER(E("draw", amount=3), "active")]}),
])

# ============================================================================
# Allies
# ============================================================================
ally("henchman_alpha", "Vesna Draik", "knave", 1400000, 20000, {"attack": {"kind": "art", "printed_life": 6}, "effects": [IFS(DISCARD_IN_PLAY("ally", amount=1, choose=True))]})
ally("henchman_beta", "Brann Draik", "knave", 1800000, 100000, {"attack": {"kind": "strike", "stages": 5}, "effects": [IFS(DISCARD_IN_PLAY("drill", amount=1, choose=True))]})
ally("henchman_gamma", "Quill Draik", "knave", 1350000, 25000, {"attack": {"kind": "art", "printed_life": 6}, "effects": [IFS(WHEN({"may": True, "then": [OPP("choose_forbid_type", unless_vigor_min=5)], **E("discard_hand", amount=1, random=False)}, hand_min=1))]})
ally("henchman_delta", "Halvard Draik", "knave", 1450000, 75000, {"attack": {"kind": "strike", "stages": 5}, "effects": [IFS(OPP("discard_hand", amount=1, random=False))]})
ally("henchman_epsilon", "Pim", "knave", 50000, 2000, {"attack": {"kind": "strike"}, "effects": [IFS(E("draw_discard", amount=2, **{"from": "bottom"}))]})
ally("henchman_zeta", "The Fourteenth Vessel", "knave", 1400000, 10000, {"attack": {"kind": "strike", "life": 2}, "effects": [E("discard_hand", amount=1, random=False)], "no_control_needed": True}, tags=["automaton"])
ally("companion_alpha", "Wren Rooke", "knight", 1000000, 1000, {"effects": [E("shuffle_discard", amount=1, per_personality=True)]})
ally("companion_beta", "Sir Edric Rooke", "knight", 1100000, 50000, {"attack": {"kind": "strike", "focused": True, "stages": 2, "variants": [{"when": {"opponent_focus": True}, "life_per_opponent_token": 2}]}})
ally("companion_gamma", "Tavin Vale", "knight", 1200000, 30000, {"attack": {"kind": "art", "printed_life": 6}, "effects": [E("recover", amount=2, **{"from": "bottom"})]}, surge=3)
ally("companion_delta", "Ansel Rooke", "knight", 800000, 40000, {"attack": {"kind": "strike", "printed_stages": 5}, "effects": [IFSTOP(VIG("max"))]})

# ============================================================================
# Royal Tokens: two sets of seven
# ============================================================================
CROWN = [
    [VIG("max", "fighter"), E("draw", amount=1)],
    [ACC(1), VIG(3)],
    [E("draw", amount=3), E("recover", amount=1)],
    [DISCARD_IN_PLAY("non_combat", all=True)],
    [VIG("max", "fighter"), ACC(2), E("draw", amount=2), E("recover", amount=2)],
    [OPP("discard_hand", amount=1), ACC(1)],
    [E("draw", amount=2), ACC(2)],
]
SIGNET = [
    [E("draw_until", amount=3), ACC(2), OPP_ACC(-2)],
    [VIG(5), E("draw", amount=1)],
    [E("draw_discard", amount=3, **{"from": "bottom"}), VIG(5), OPP("remove_discard", amount=6)],
    [DISCARD_IN_PLAY("non_combat", all=True)],
    [E("recover", amount=3), ACC(1)],
    [OPP("discard_life", amount=3)],
    [E("draw", amount=3)],
]
for i, eff in enumerate(CROWN, 1):
    token("crown_token_%d" % i, "Crown Token %d" % i, "crown", i, eff)
for i, eff in enumerate(SIGNET, 1):
    token("signet_token_%d" % i, "Signet Token %d" % i, "signet", i, eff)

# ============================================================================
# Grounds
# ============================================================================
grounds("turmoil_square", "Turmoil Square", forbid=[{"who": "all", "what": "non_combats"}])
grounds("ancient_grove", "Ancient Grove", modifiers=[{"scope": "own", "kind": "any", "stages": 2}],
        effects=[ENTER(SEARCH(card_type="drill", guild="", to="play"))])
grounds("tollgate_yard", "Tollgate Yard", double_costs=True)

# ============================================================================
# Masters and Masteries
# ============================================================================
add(id="master_north", title="Master of the North", type="master", guild="", armory_size=13, uses_per_game=2, limit_per_deck=1,
    effects=[{"trigger": "master_use", "op": "forbid", "who": "opponent", "what": "mastery", "duration": "turn"}])
add(id="master_south", title="Master of the South", type="master", guild="", armory_size=5, uses_per_game=1, limit_per_deck=1,
    effects=[{"trigger": "master_use", "op": "search", "card_type": "ally", "to": "play", "stages": 3}])
add(id="master_steadfast", title="Master Steadfast", type="master", guild="", armory_size=10, limit_per_deck=1,
    master_flags={"no_favor_win": True, "acclaim_shield": True, "tier_shield": True})

add(id="ember_mastery", title="Ember Mastery", type="mastery", guild="ember", limit_per_deck=1, once_per_combat=True,
    effects=[USE(WHEN(ACC(2), discard_top_guild="ember")), USE(WHEN(ACC(1), discard_top_guild_not="ember", discard_min=1)), USE(WHEN(E("remove_discard", amount=1), discard_min=1))])
add(id="steel_mastery", title="Steel Mastery", type="mastery", guild="steel", limit_per_deck=1,
    effects=[ENTER(E("draw_check", guild="steel", effects=[{"may": True, **OPP("vigor", amount=-4, no_overflow=True)}]))])
add(id="shade_mastery", title="Shade Mastery", type="mastery", guild="shade", limit_per_deck=1,
    modifiers=[{"scope": "own", "kind": "any", "stages": 1, "life": 1}, {"scope": "own", "kind": "any", "stages": 1, "life": 1, "guild": "shade"}])
add(id="tide_mastery", title="Tide Mastery", type="mastery", guild="tide", limit_per_deck=1, opponent_tier_threshold=6,
    effects=[{"trigger": "on_success", "op": "acclaim", "who": "opponent", "amount": -1, "when": {"source_guild": "tide"}}])
add(id="freestyle_mastery", title="Freestyle Mastery", type="mastery", guild="", limit_per_deck=1, protect_drills=True,
    effects=[ENTER(WHEN({"may": True, "then": [SEARCH(signature_of="fighter", to="hand")], **E("discard_hand", amount=1, random=False, filter="signature")}, hand_min=1))])
add(id="storm_mastery", title="Storm Mastery", type="mastery", guild="storm", limit_per_deck=1, art_cost_delta=-1,
    modifiers=[{"scope": "own", "kind": "art", "life": 1}])

# ============================================================================
# Freestyle staples
# ============================================================================
strike("breaching_kick", "Breaching Kick", atk={"stages": 3},
       effects=[FORBID("end_combat"), FORBID("end_combat", "opponent"), FORBID("stop_all"), FORBID("stop_all", "opponent")])
strike("relentless_fury", "Relentless Fury", atk={"stages": 4}, empower=2, effects=[AFTER_EMPOWER(FORBID("non_attack_actions")), AFTER_EMPOWER(FORBID("non_attack_actions", "opponent")), AFTER_EMPOWER(ACC(1))])
block("stillness", "Stillness", "any", "combat", defense={"stop_all": "any"}, limit_per_deck=1, use_in_attack=True, effects=[E("stop_all", kind="any")])
block("ironclad_stance", "Ironclad Stance", "strike", "strike", defense={"stop_all": "strike"}, remove_after_use=True, limit_per_deck=1)
block("unyielding_guard", "Unyielding Guard", "strike", "strike", defense={"stop_all": "strike"}, remove_after_use=True, limit_per_deck=1)
block("bracing_stance", "Bracing Stance", "strike", "strike", defense={"stop_all": "strike"}, remove_after_use=True, limit_per_deck=1)
block("energy_veil", "Energy Veil", "art", "art", defense={"stop_all": "art"}, remove_after_use=True, limit_per_deck=1)
block("mirror_shell", "Mirror Shell", "art", "art", defense={"stop_all": "art"}, effects=[FORBID("art_attacks")], limit_per_deck=1)
add(id="iron_will", title="Ashmark's Iron Will", type="combat", guild="", only={"fighter_character": ALPHA}, limit_per_deck=1, use_in_attack=True,
    defense={"stops": "any"}, effects=[FLOAT("prevent_all")])
combat("chosen_wall", "Chosen Wall", [E("choose_stop_all_kind")], alignment_only="knave", remove_after_use=True, limit_per_deck=1)
block("perfect_guard", "Ashmark's Guard", "any", "strike", defense={"stop_focused": True}, only={"fighter_character": ALPHA}, remove_after_use=True)
add(id="interrupt", title="Interrupt", type="combat", guild="", counter="combat")
combat("hard_glare", "Hard Glare", [OPP("discard_hand", amount=1, random=False, chooser="owner")], alignment_only="knave")
combat("threatening_pose", "Threatening Pose", [OPP("set_tier", tier=1)], alignment_only="knave", remove_after_use=True, limit_per_deck=1)
combat("respite", "Respite", [E("draw_discard", amount=2, **{"from": "top"}), OPP("vigor", amount=5)], limit_per_deck=1)
combat("challenge", "Challenge", [OPP("discard_hand", amount=1, random=False, chooser="owner", to="deck")], alignment_only="knight")
combat("overwhelming_aura", "Overwhelming Aura", [FORBID("strike_attacks", "opponent")], limit_per_deck=1)
combat("dragons_reckoning", "Dragon's Reckoning", [SEARCH(card_type="ally", source="either", to="play", stages=3), DISCARD_IN_PLAY("token", all=True)], limit_per_deck=1)
combat("guardians_wrath", "Rooke's Wrath", [DISCARD_IN_PLAY("non_combat", all=True)], only={"fighter_character": BETA}, remove_after_use=True)
combat("desperate_ruin", "Desperate Ruin", [E("set_vigor", amount=0), E("remove_discard", all=True), OPP("discard_life", amount=5)], remove_after_use=True, limit_per_deck=1)
combat("oath", "Husband's Vow", [E("attach", to="fighter")], only={"character": "Sir Edric Rooke"},
       attachment={"target": "fighter", "effects": [ENTER(E("draw_discard", amount=1, **{"from": "bottom"}))]}, limit_per_deck=1)
combat("showmans_trick", "Showman's Trick", [SEARCH(card_type="attack", source="armory", to="hand")], remove_after_use=True, limit_per_deck=2)
combat("clash_of_blood", "Clash of Blood", [FLOAT("modifier", scope="own", kind="any", life=2, per_ally=True, once=True), E("draw", amount=1)], remove_after_use=True)
combat("muster", "Muster", [VIG("max", "fighter"), SEARCH(card_type="ally", source="either", to="play", stages=3)], remove_after_use=True)
combat("sudden_reinforcement", "Sudden Reinforcement", [SEARCH(card_type="ally", source="either", to="play", stages=10)])
combat("sly_smirk", "Sly Smirk", [DISCARD_IN_PLAY("drill", all=True, remove=True)], alignment_only="knave", remove_after_use=True, limit_per_deck=1)
combat("truce", "Truce", [E("end_combat"), E("end_turn"), FLOAT("keep_hand", duration="next_turn_end")], guild="steel", remove_after_use=True, limit_per_deck=1)
combat("mutual_escalation", "Mutual Escalation", [ACC(6), OPP_ACC(6), E("no_favor_win")])
combat("transformation", "Transformation", [E("no_favor_win"), E("set_tier", tier="acclaim")])
combat("seekers_eye", "Seeker's Eye", [E("draw_check", check="named", effects=[E("draw", amount=1)])], remove_after_use=True, limit_per_deck=1)
combat("contemplation", "Contemplation", [E("draw_check", check="signature", effects=[E("draw", amount=1)])], limit_per_deck=1)
combat("grand_sweep", "Grand Sweep", [DISCARD_IN_PLAY("ally", "self", all=True, remove=True), DISCARD_IN_PLAY("ally", all=True, remove=True)], remove_after_use=True, limit_per_deck=2)

# Freestyle attacks
art("homing_bolt", "Homing Bolt", atk={"unstoppable": True, "no_prevent": True}, remove_after_use=True)
art("crashing_dive", "Crashing Dive", atk={"focused": True}, empower=2,
    effects=[IFS(AFTER_EMPOWER(OPP("remove_discard", all=True))), AFTER_EMPOWER(ACC(1))])
art("surging_blast", "Surging Blast", atk={}, alignment_only="knave", effects=[DISCARD_IN_PLAY("drill", amount=1, remove=True, choose=True)], tags=["automaton"])
strike("power_hit", "Power Hit", atk={"focused": True, "stages": 4, "no_stop_by": "strike"}, effects=[ACC(1)], remove_after_use=True)
strike("backhand", "Backhand", atk={}, effects=[E("draw_discard", amount=1, **{"from": "bottom"})], remove_after_use=True)
add(id="power_strike", title="Power Strike", type="art", guild="", endurance=3,
    attack={"kind": "strike", "stages": 4, "variants": [{"when": {"tier_min": 2}, "life": 4, "focused": True}]},
    effects=[IFS(SEARCH(card_type="drill", to="play"))])
art("lobbed_bolt", "Lobbed Bolt", atk={}, endurance=1,
    effects=[DISCARD_IN_PLAY("non_combat_only", "self", amount=1, choose=True, up_to=True), SEARCH(card_type="non_combat", to="play")], remove_after_use=True)
strike("erasure", "Erasure", atk={"stages": 6, "cost_stages": 6}, effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=6, up_to=True, choose=True))], remove_after_use=True)
art("supreme_push", "Supreme Push", atk={"focused": True}, effects=[WHEN({"may": True, "then": [FLOAT("modifier", scope="own", kind="any", life=7, once=True)], **E("lose_tier")}, focus=True, tier_min=2)], remove_after_use=True)
art("extreme_assailment", "Draik's Assailment", atk={"focused": True, "printed_life": 5}, effects=[E("set_acclaim", amount=2), OPP("set_acclaim", amount=2), IFS({"may": True, **E("return_removed", card_type="ally")})], remove_after_use=True)
art("twin_palm_blitz", "Draik's Twin Palm", atk={"printed_life": 6}, only={"fighter_character": DELTA}, effects=[FLOAT("no_prevent")],
    remain_when={"when": {"allies_min": 2}, "remain": 1}, remove_after_use=True)
art("triple_torpedo", "Triple Torpedo", atk={"life_per_ally": 2}, endurance=2, effects=[ACC(1)], remain=1, remove_after_use=True)
art("captains_volley", "Captain's Volley", atk={"cost_stages": 3}, effects=[ACC(2)], remove_after_use=True)
art("clear_statement", "Clear Statement", atk={}, effects=[ACC(2), OPP_ACC(-2)], remove_after_use=True, limit_per_deck=1)
art("palm_charge", "Draik's Palm Charge", atk={"printed_life": 5}, effects=[IFS(E("attach", to="in_control"))],
    attachment={"target": "in_control", "modifiers": [{"scope": "own", "kind": "art", "life": 2}]})
art("prepared_stance", "Vessel's Prepared Stance", atk={}, effects=[WHEN(SEARCH(tag="automaton", exclude_title="Vessel's Prepared Stance", to="hand"), fighter_character=GAMMA)], remove_after_use=True, tags=["automaton"])
strike("focused_crushing_dive", "Crushing Dive", atk={"focused": True, "stages": 3}, endurance=2, empower=3,
       effects=[AFTER_EMPOWER(ACC(1)), AFTER_EMPOWER(OPP_ACC(-1)), AFTER_EMPOWER(DISCARD_IN_PLAY("ally", amount=1, choose=True)), AFTER_EMPOWER(VIG(3))], bottom_after_use=True)
strike("focused_sword_strike", "Focused Sword Strike", atk={"focused": True, "stages": 3}, effects=[IFS(OPP_ACC(-3))], remove_after_use=True)
strike("sword_slash", "Sword Slash", atk={"focused": True}, effects=[IFS(SEARCH(title_contains="Swordplay", to="play"))], remove_after_use=True)
strike("sword_sweep", "Sword Sweep", atk={"stages": 2}, effects=[IFS(DISCARD_IN_PLAY("ally", amount=4, up_to=True, choose=True))])
strike("sword_thrust", "Sword Thrust", atk={"stages": 2}, effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=2, choose=True))])
strike("sword_slice", "Vale's Sword Slice", atk={"stages": 4}, character=ZETA, effects=[ACC(1), IFS(SEARCH(title_contains="Sword", exclude_title="Vale's Sword Slice", to="hand"))])
strike("speedy_flight", "Vale's Speedy Flight", atk={"stages": 4}, character=ZETA, empower=2,
       effects=[AFTER_EMPOWER(OPP_ACC(-2)), AFTER_EMPOWER(WHEN(SEARCH(signature_of="fighter", source="discard", to="hand"), fighter_character=ZETA))], remove_after_use=True)
strike("back_bash", "Vale's Back Bash", atk={"stages": 4, "variants": [{"when": {"fighter_character": ZETA, "stopped_last_phase": True}, "effects": [OPP("skip_next_attack_phase")]}]},
       character=ZETA, endurance=2, effects=[ACC(1)])
strike("henchmans_charge", "Brann's Charge", atk={"stages": 4, "variants": [{"when": {"character": "Brann Draik"}, "effects": [DISCARD_IN_PLAY("non_combat", amount=1, choose=True), E("capture_token")]}]},
       effects=[IFS(SEARCH(card_type="ally", to="play", stages=4))])
add(id="dual_strike", title="Halvard's Dual Strike", type="strike", guild="", attack={"kind": "strike", "focused": True, "stages": 4, "variants": [{"when": {"character": "Halvard Draik"}, "effects": [OPP("discard_hand", amount=1, random=False)]}]},
    defense={"stops": "strike", "when": {"character": "Halvard Draik"}}, effects=[IFS(SEARCH(card_type="ally", to="play", stages=4))])
strike("leaping_rush", "Vesna's Leaping Rush", atk={"focused": True, "stages": 4, "variants": [{"when": {"character": "Vesna Draik"}, "effects": [FLOAT("no_ally_control", "opponent")]}]},
       effects=[IFS(SEARCH(card_type="ally", to="play", stages=4))])
strike("heel_kick", "Ashmark's Heel Kick", atk={"stages": 4}, endurance=1, effects=[OPP("remove_discard", amount=5), VIG(3)])
strike("frantic_assault", "Frantic Assault", atk={"stages": 1}, effects=[IFS(ACC(1))], remain=1, remove_after_use=True)
strike("steel_headshot", "Steel Headshot", "steel", atk={"life": 3, "no_prevent": True}, effects=[E("draw", amount=1), ACC(1)], limit_per_deck=1)

# Freestyle defenses
block("last_ward", "Last Ward", "any", "strike", defense={"stop_focused": "discard_hand"})
block("swift_counter", "Vale's Swift Counter", "strike", "strike", defense={"copy_attack": True}, character=ZETA)
block("elbow_block", "Elbow Block", "strike", "strike", effects=[SEARCH(card_type="hand_combat", source="discard", to="hand")], remove_after_use=True)
block("leg_catch", "Leg Catch", "strike", "strike", effects=[VIG("max", "fighter"), E("shuffle_discard", amount=3)])
block("swift_flight", "Swift Flight", "any", "strike", effects=[ACC(1), WHEN(FLOAT("stop_next"), focus=True)])
block("storm_dodge", "Vessel's Dodge", "strike", "strike", character=GAMMA, effects=[SEARCH(guild="storm", to="hand")], remove_after_use=True, tags=["automaton"])
add(id="knowing_smile", title="Vessel's Knowing Smile", type="non_combat", guild="", defense={"stops": "strike"},
    effects=[WHEN(SEARCH(tag="automaton", source="discard", to="hand"), fighter_character=GAMMA)], remove_after_use=True, tags=["automaton"])
block("steel_supreme_power", "Quarr's Supreme Power", "any", "strike", "steel", only={"fighter_character": EPSILON}, remain=1, remove_after_use=True, limit_per_deck=2, unused_return="shuffle")

# Freestyle non-combats and drills
noncombat("counsel", "Counsel", [USE(SEARCH(card_type="attack", source="either", to="hand"))], limit_per_deck=1)
noncombat("focus_of_mind", "Focus of Mind", [USE(SEARCH(card_type="combat", to="hand"))], limit_per_deck=1)
noncombat("anticipation", "Anticipation", [ENTER(SEARCH(card_type="hand_combat", source="discard", to="hand"))], limit_per_deck=1)
noncombat("fortune", "Fortune", [USE(SEARCH(card_type="non_combat", to="play"))], limit_per_deck=1)
noncombat("bonding_rite", "Bonding Rite", [USE(E("bond", card="bonded_pair"))])
ally("bonded_pair", "Ansel and Tavin, Back to Back", "knight", 7000000, 200000,
     {"attack": {"kind": "strike", "printed_stages": 7}, "uses": 2, "effects": [WHEN({"may": True, "then": [E("focus_attack")], **E("discard_hand", amount=1, random=False)}, hand_min=1)]},
     surge=4, bond_of=["Ansel Rooke", "Tavin Vale"], bond_timer_max=5)
noncombat("seek_the_answer", "Vale Finds the Answer", [USE(SEARCH(signature_of="fighter", amount=2, to="hand"))], remove_after_use=True)
noncombat("sweet_ration", "Ashmark's Ration", [USE(VIG("max", "fighter")), USE(E("shuffle_discard", amount=5)), USE(ACC(1))], only={"fighter_character": ALPHA})
noncombat("kings_invitation", "The King's Invitation", [{"trigger": "opponent_declare", **E("discard_hand", amount=1, random=False)}, {"trigger": "opponent_declare", **OPP("force_declare")}],
          start_in_play=True, limit_per_deck=1, remove_after_use=True)
noncombat("doubt", "Doubt", [USE(DISCARD_IN_PLAY("token", amount=1, remove=True, choose=True))], remove_after_use=True, limit_per_deck=1)
add(id="heirloom_blade", title="The Vale Heirloom", type="non_combat", guild="", effects=[USE(E("attach", to="fighter"))], limit_per_deck=1,
    attachment={"target": "fighter", "title_contains": "Sword", "damage_removes": True, "modifiers": [{"scope": "own", "kind": "any", "life": 3, "title_contains": "Sword"}]})
drill("victors_drill", "Victor's Drill", start_in_play=True, limit_per_deck=1, effects=[ENTER(OPP_ACC(-2)), ENTER(VIG(2, "fighter"))])
drill("champion_drill", "Champion's Drill", once_per_combat=True, limit_per_deck=1, effects=[USE(E("discard_hand", amount=1, random=False)), USE(E("draw", amount=2))])
drill("swordplay_drill", "Swordplay Drill", modifiers=[{"scope": "own", "kind": "any", "stages": 2, "title_contains": "Sword"}], promote_if_successful="Sword")
drill("devastation_drill", "Devastation Drill", modifiers=[{"scope": "own", "kind": "strike", "stages": 5}], discard_if_other_non_combats=True)
drill("ambush_drill", "Ambush Drill", alignment_only="knight", limit_per_deck=2, effects=[PLACE(E("name_card"))])
drill("breakthrough_drill", "Breakthrough Drill", limit_per_deck=1, forbid=[{"who": "all", "what": "end_combat"}])
drill("absorbing_drill", "Absorbing Drill", defense={"stops": "art", "cost_life": 2})
drill("quickness_drill", "Quickness Drill", limit_per_deck=1, effects=[ENTER(E("draw_discard", amount=1, **{"from": "bottom"}))])
drill("confusion_drill", "Confusion Drill", limit_per_deck=1, forbid=[{"who": "all", "what": "tokens"}])

# ============================================================================
# Ember
# ============================================================================
block("ember_blocking_hand", "Ember Blocking Hand", "strike", "strike", "ember", effects=[ACC(2), VIG(2)])
block("ember_passive_block", "Ember Passive Block", "strike", "strike", "ember", endurance=1, effects=[OPP("discard_life", amount=1), ACC(1), VIG(5)])
art("ember_blast", "Ember Blast", "ember", atk={}, effects=[DISCARD_IN_PLAY("drill_or_ally", amount=1, remove=True, choose=True), ACC(1)])
art("ember_vigor_orb", "Ember Vigor Orb", "ember", atk={"printed_life": 3}, empower=3,
    effects=[AFTER_EMPOWER(DISCARD_IN_PLAY("drill_or_ally", amount=1, remove=True, choose=True)), AFTER_EMPOWER(OPP_ACC(-2))])
strike("ember_back_kick", "Ember Back Kick", "ember", atk={"stages": 3}, effects=[E("stop_all", kind="art"), FORBID("art_attacks"), OPP_ACC(-1)])
strike("ember_shattering_leap", "Ember Shattering Leap", "ember", atk={"stages": 4}, remain=1, remove_after_use=True)
strike("ember_face_upheaval", "Ember Face Upheaval", "ember", atk={}, effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=1, remove=True, choose=True)), ACC(1)])
strike("ember_lightning_slash", "Ember Lightning Slash", "ember", atk={}, effects=[{"trigger": "before_damage", "may": True, "skip_damage": True, **DISCARD_IN_PLAY("drill_or_ally", all=True)}, ACC(1)])
strike("ember_power_rush", "Ember Power Rush", "ember", atk={"stages": 3, "no_stop_by": "strike"}, effects=[ACC(1)], remove_after_use=True)
strike("ember_overbearing_blow", "Ember Overbearing Blow", "ember", atk={"stages": 4}, effects=[WHEN(ACC(2), focus=True)], remove_after_use=True)
add(id="ember_double_strike", title="Ember Double Strike", type="combat", guild="ember", attack={"kind": "strike"}, effects=[ACC(1)], remain_when={"when": {"focus": True}, "remain": 1})
strike("ember_face_slap", "Ember Face Slap", "ember", atk={"stages": 3, "variants": [{"when": {"opponent_acclaim": 0}, "no_prevent": True, "effects": [ACC(1)]}]}, effects=[FORBID("powers", "opponent")])
strike("ember_tilted_punch", "Ember Tilted Punch", "ember", atk={"stages": 3}, remain_when={"when": {"focus": True, "opponent_used_combat_card": True}, "remain": 2}, remove_after_use=True)
strike("ember_whiplash", "Ember Whiplash", "ember", atk={"stages": 4}, endurance=2, empower=2, effects=[AFTER_EMPOWER(ACC(1)), IFSTOP(AFTER_EMPOWER(E("look_at", amount=5, pick={"card_type": "strike"}, to="hand", **{"from": "bottom"})))])
strike("ember_puppy_slap", "Ember Puppy Slap", "ember", atk={"life": 3}, effects=[ACC(1), FLOAT("make_focused", guild="ember")])
strike("ember_axe_heel_kick", "Ember Axe Heel Kick", "ember", atk={"stages": 6}, effects=[ACC(1), SEARCH(card_type="attack", guild="ember", source="discard", exclude_title="Ember Axe Heel Kick", to="hand")], remove_after_use=True)

# ============================================================================
# Steel
# ============================================================================
block("steel_perfect_defense", "Steel Perfect Defense", "strike", "strike", "steel", defense={"when": {"higher_might": True}}, remain_when={"when": {"focus": True}, "remain": 9}, remove_after_use=True, limit_per_deck=1)
block("steel_stop", "Steel Stop", "any", "strike", "steel", effects=[VIG(7)])
block("steel_brace", "Steel Brace", "any", "art", "steel", effects=[ACC(1), SEARCH(title_contains="Truce", to="hand")], remove_after_use=True)
block("steel_wrist_block", "Steel Wrist Block", "strike", "strike", "steel", effects=[WHEN(OPP("vigor", amount=-3, no_overflow=True), focus=True)])
art("steel_power_beam", "Steel Power Beam", "steel", atk={}, empower=3, effects=[AFTER_EMPOWER(WHEN(FORBID("mastery", "opponent"), focus=True)), AFTER_EMPOWER(WHEN(FORBID("drills", "opponent"), focus=True))], remove_after_use=True)
art("steel_might", "Quarr's Might", "steel", atk={"printed_life": 6}, effects=[WHEN(FORBID("combat_cards", "opponent"), character=EPSILON)], remove_after_use=True)
strike("steel_crushing_smash", "Quarr's Crushing Smash", "steel", character=EPSILON,
       atk={"life": 2, "variants": [{"when": {"character": EPSILON}, "stages": 3, "effects": [DISCARD_IN_PLAY("non_combat", amount=1, choose=True)]}]},
       endurance_when={"value_if": {"fighter_character": EPSILON}, "then": 6, "else": 3})
strike("steel_gut_kick", "Steel Gut Kick", "steel", atk={"stages": 3}, endurance=2, effects=[OPP_ACC(-1), IFS(WHEN(SEARCH(card_type="token", to="play"), focus=True))], remove_after_use=True)
strike("steel_dashing_kick", "Steel Dashing Kick", "steel", atk={"stages": 8}, effects=[ACC(1)])
strike("steel_destiny", "Steel Destiny", "steel", atk={"variants": [{"when": {"focus": True}, "stages": 3}]}, remain_when={"when": {"focus": True}, "remain": 1}, remove_after_use=True)
strike("steel_bulk", "Steel Bulk", "steel", atk={"stages": 3}, empower=2, effects=[AFTER_EMPOWER(FLOAT("no_gain", "opponent", "next_turn_end"))], remove_after_use=True)
strike("steel_face_jab", "Steel Face Jab", "steel", atk={"stages": 3}, effects=[IFS(OPP("next_attack_tax", amount=2))])
add(id="steel_youth_bruise", title="Steel Youth Bruise", type="art", guild="steel", endurance=2, attack={"kind": "strike", "stages": 4}, effects=[E("shuffle_discard", amount=3)], remove_after_use=True)
strike("steel_rapid_slam", "Steel Rapid Slam", "steel", atk={"focused": True, "stages": 5}, effects=[FLOAT("after_use_bottom", guild="steel")])
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
add(id="shade_turning_kick", title="Shade Turning Kick", type="art", guild="shade", attack={"kind": "art", "printed_life": 5}, defense={"stops": "strike"}, effects=[ACC(1)])
art("shade_chaos_detonation", "Shade Chaos Detonation", "shade", atk={"cost_stages": 3}, effects=[IFS(OPP("discard_hand", amount=2, random=False))])
add(id="shade_body_ruin", title="Shade Body Ruin", type="strike", guild="shade", attack={"kind": "strike", "stages": 4}, defense={"stops": "strike"},
    effects=[WHEN(OPP("discard_hand", amount=1), focus=True)], remove_after_use=True)
strike("shade_swivel_kick", "Shade Swivel Kick", "shade", atk={"stages": 3}, effects=[OPP("remove_hand", amount=1)])
strike("shade_right_kick", "Shade Right Kick", "shade", atk={"stages": 2}, endurance=1, empower=3, alignment_only="knave", effects=[AFTER_EMPOWER(OPP("discard_hand", amount=1, random=False))], remove_after_use=True)

# ============================================================================
# Tide
# ============================================================================
block("tide_energy_guard", "Tide Energy Guard", "art", "art", "tide", effects=[WHEN(FLOAT("prevent_art_life"), focus=True)], remove_after_use=True, limit_per_deck=1)
block("tide_defensive_flight", "Tide Defensive Flight", "strike", "strike", "tide", effects=[E("pay_vigor", per=1, then=[OPP_ACC(-1)])])
add(id="tide_round_throw", title="Tide Round Throw", type="strike", guild="tide", attack={"kind": "strike", "stages": 5}, defense={"stops": "art"}, effects=[OPP_ACC(-1)])
strike("tide_betrayal", "Tide Betrayal", "tide", atk={}, effects=[WHEN(DISCARD_IN_PLAY("non_combat_or_ally", amount=1, remove=True, choose=True), focus=True)])
add(id="tide_arm_blast", title="Tide Arm Blast", type="art", guild="tide", attack={"kind": "art", "printed_life": 5}, defense={"stops": "strike"})
art("tide_double_blast", "Tide Double Blast", "tide", atk={"printed_life": 3, "life_from_surge": True}, remain=1)
art("tide_draining_blast", "Tide Draining Blast", "tide", atk={"cost_stages": 0, "pay_stages": {"per": 2, "life": 1}})
art("tide_healing_ray", "Tide Healing Ray", "tide", atk={}, effects=[SEARCH(card_type="ally", source="discard", to="play", stages=3), IFS(VIG("max", "last_searched"))], remove_after_use=True)
art("tide_terror", "Tide Terror", "tide", atk={"printed_life": 3}, effects=[WHEN(SEARCH(to="hand"), focus=True)], remove_after_use=True, limit_per_deck=1)
art("tide_transformation", "Tide Transformation", "tide", atk={"printed_life": 5}, effects=[ACC(1), IFS(SEARCH(card_type="grounds", to="play"))])
art("tide_alliance", "Tide Alliance", "tide", atk={"printed_life": 5, "variants": [{"when": {"performed_by": "ally"}, "focused": True}]}, empower=3,
    effects=[AFTER_EMPOWER(WHEN(DISCARD_IN_PLAY("drill", amount=1, choose=True), allies_min=1))])
art("twin_blow", "Twin Blow", "tide", atk={"printed_life": 5, "variants": [{"when": {"ally_present": "Sir Edric Rooke"}, "focused": True, "life": 4}]},
    effects=[OPP_ACC(-2), ACC(1), {"trigger": "on_wound", "at": "fight_back", "may": True, **SEARCH(card_type="ally", to="play")}])

# ============================================================================
# Storm
# ============================================================================
block("storm_energy_guard", "Storm Energy Guard", "art", "art", "storm", endurance=3, effects=[FLOAT("modifier", scope="own", kind="any", stages=2), ACC(1)])
add(id="storm_setup", title="Storm Setup", type="art", guild="storm", attack={"kind": "art"}, defense={"stops": "strike", "when": {"focus": True}}, remove_after_use=True)
art("storm_scatter_shot", "Storm Scatter Shot", "storm", atk={"printed_life": 5}, remain_when={"when": {"focus": True}, "remain": 1}, remove_after_use=True)
art("storm_glaring_bolt", "Storm Glaring Bolt", "storm", atk={}, effects=[WHEN(DISCARD_IN_PLAY("non_combat_or_ally", amount=1, remove=True, choose=True), focus=True)])
art("storm_obliteration", "Storm Obliteration", "storm", atk={}, empower=3, effects=[AFTER_EMPOWER(DISCARD_IN_PLAY("drill", amount=3, up_to=True, choose=True)), AFTER_EMPOWER(FLOAT("endurance_boost"))])
art("storm_rage", "Storm Rage", "storm", atk={"printed_life": 5}, effects=[WHEN(ACC(2), focus=True)])
strike("storm_massacre", "Storm Massacre", "storm", atk={"stages": 4}, endurance=2, empower=2, effects=[AFTER_EMPOWER(FLOAT("no_prevent")), IFS(AFTER_EMPOWER(DISCARD_IN_PLAY("freestyle_drill", "self", all=True, remove=True))), IFS(AFTER_EMPOWER(DISCARD_IN_PLAY("freestyle_drill", all=True, remove=True)))])
strike("storm_uppercut", "Storm Uppercut", "storm", atk={"stages": 4}, effects=[WHEN({"may": True, "then": [SEARCH(card_type="art", to="hand")], **E("vigor", amount=-2)}, focus=True, vigor_min=2)], remove_after_use=True, limit_per_deck=1)
strike("storm_strength", "Storm Strength", "storm", atk={"stages": 2}, endurance=2, effects=[VIG("max", "fighter")])

# ============================================================================
# Decks
# ============================================================================
os.makedirs("data/cards/starter", exist_ok=True)
with open("data/cards/starter/starter_set.json", "w", encoding="utf-8", newline="\n") as f:
    json.dump({"_note": "Starter set. Generated; mechanics follow the reference sample decks, names are original.", "cards": CARDS}, f, indent=1)
    f.write("\n")
print("cards:", len(CARDS))

VALID = {c["id"] for c in CARDS}


def deck(fname, name, fighter_id, tiers, focus, alignment, mastery_id, master_id, armory, entries):
    for i, _ in entries:
        assert i in VALID, i
    for i in armory:
        assert i in VALID, i
    total = sum(n for _, n in entries)
    d = {"name": name, "fighter": fighter_id, "tiers": tiers, "focus": focus, "alignment": alignment,
         "mastery": mastery_id, "master": master_id, "armory": armory,
         "cards": [{"id": i, "count": n} for i, n in entries]}
    with open("data/decks/%s.json" % fname, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    print("%-18s life %d, armory %d" % (fname, total, len(armory)))


deck("ember_beatdown", "House Ashmark", "fighter_alpha", 3, "ember", "knave", "ember_mastery", "master_north",
     ["kings_invitation", "ember_vigor_orb", "ember_vigor_orb", "ember_vigor_orb", "champion_drill", "heel_kick", "heel_kick", "heel_kick", "tollgate_yard",
      "ember_tilted_punch", "ember_tilted_punch", "ember_tilted_punch"], [
    ("turmoil_square", 3),
    ("sweet_ration", 3), ("counsel", 1), ("victors_drill", 1),
    ("hard_glare", 3), ("interrupt", 3), ("threatening_pose", 1),
    ("stillness", 1), ("iron_will", 1), ("chosen_wall", 1), ("bracing_stance", 1), ("unyielding_guard", 1), ("energy_veil", 1), ("mirror_shell", 1),
    ("ember_blocking_hand", 3), ("perfect_guard", 3), ("ember_passive_block", 3),
    ("ember_blast", 3),
    ("ember_back_kick", 3), ("ember_shattering_leap", 3), ("ember_face_upheaval", 3), ("ember_lightning_slash", 3), ("ember_power_rush", 3),
    ("ember_overbearing_blow", 3), ("breaching_kick", 3), ("power_hit", 3), ("ember_double_strike", 3), ("relentless_fury", 3), ("frantic_assault", 3),
    ("ember_face_slap", 3), ("ember_whiplash", 3), ("ember_puppy_slap", 3), ("ember_axe_heel_kick", 3)])

deck("steel_beatdown", "House Quarr", "fighter_epsilon", 3, "steel", "knave", "steel_mastery", "master_north",
     ["kings_invitation", "steel_headshot", "mutual_escalation", "mutual_escalation", "mutual_escalation", "steel_youth_bruise", "steel_rapid_slam", "steel_charge",
      "steel_fist_attack", "steel_direct_strike", "steel_cliff_slam", "steel_wrist_block"], [
    ("turmoil_square", 3),
    ("signet_token_1", 1), ("signet_token_3", 1), ("signet_token_4", 1),
    ("hard_glare", 3), ("interrupt", 3), ("truce", 1),
    ("stillness", 1), ("steel_perfect_defense", 1), ("steel_stop", 3), ("steel_brace", 3), ("steel_supreme_power", 2),
    ("steel_power_beam", 3), ("steel_might", 3),
    ("breaching_kick", 3), ("relentless_fury", 3), ("steel_crushing_smash", 4), ("steel_gut_kick", 3), ("backhand", 1),
    ("steel_dashing_kick", 3), ("steel_destiny", 3), ("steel_bulk", 3), ("steel_face_jab", 3)])

deck("shade_henchmen", "The Draik Company", "fighter_delta", 3, "shade", "knave", "shade_mastery", "master_south",
     ["doubt", "shade_pivot_kick", "shade_pivot_kick", "shade_pivot_kick"], [
    ("turmoil_square", 3),
    ("henchman_alpha", 1), ("henchman_beta", 1), ("henchman_gamma", 1), ("henchman_delta", 1), ("henchman_epsilon", 1),
    ("crown_token_3", 1), ("crown_token_5", 1),
    ("hard_glare", 3), ("interrupt", 3), ("sly_smirk", 1), ("muster", 3), ("sudden_reinforcement", 3),
    ("stillness", 1), ("shade_defensive_aura", 3), ("shade_buffer_block", 3),
    ("shade_turning_kick", 3), ("shade_chaos_detonation", 3), ("extreme_assailment", 3), ("palm_charge", 1), ("twin_palm_blitz", 3),
    ("triple_torpedo", 3), ("surging_blast", 3), ("homing_bolt", 3), ("crashing_dive", 3), ("captains_volley", 1),
    ("breaching_kick", 3), ("relentless_fury", 3), ("shade_body_ruin", 3), ("shade_swivel_kick", 3), ("shade_right_kick", 3),
    ("henchmans_charge", 3), ("dual_strike", 3), ("leaping_rush", 3)])

deck("tide_companions", "House Rooke", "fighter_beta", 3, "tide", "knight", "tide_mastery", "master_south",
     ["supreme_push", "lobbed_bolt", "erasure", "bonded_pair"], [
    ("companion_alpha", 1), ("companion_beta", 1), ("companion_gamma", 1), ("companion_delta", 1),
    ("turmoil_square", 3),
    ("challenge", 3), ("interrupt", 3), ("overwhelming_aura", 1), ("dragons_reckoning", 1), ("muster", 3), ("guardians_wrath", 3),
    ("desperate_ruin", 1), ("oath", 1), ("showmans_trick", 2), ("clash_of_blood", 3),
    ("stillness", 1), ("unyielding_guard", 1), ("ironclad_stance", 1), ("energy_veil", 1), ("tide_energy_guard", 1), ("tide_defensive_flight", 3), ("last_ward", 3),
    ("breaching_kick", 3), ("tide_round_throw", 3), ("tide_betrayal", 3), ("erasure", 1),
    ("tide_arm_blast", 3), ("homing_bolt", 3), ("tide_double_blast", 3), ("tide_draining_blast", 3), ("tide_healing_ray", 3), ("tide_terror", 1),
    ("twin_blow", 3), ("tide_transformation", 3), ("tide_alliance", 3),
    ("counsel", 1), ("fortune", 1), ("focus_of_mind", 1), ("bonding_rite", 2)])

deck("freestyle_swords", "House Vale", "fighter_zeta", 5, "freestyle", "knight", "freestyle_mastery", "master_north",
     ["confusion_drill", "ancient_grove", "seekers_eye", "champion_drill"], [
    ("ancient_grove", 2),
    ("challenge", 3), ("interrupt", 3), ("overwhelming_aura", 1), ("contemplation", 1),
    ("stillness", 1), ("unyielding_guard", 1), ("ironclad_stance", 1), ("swift_counter", 4), ("elbow_block", 3), ("leg_catch", 3), ("swift_flight", 3),
    ("breaching_kick", 3), ("relentless_fury", 3), ("power_strike", 3), ("sword_slice", 4), ("speedy_flight", 3), ("back_bash", 2),
    ("focused_sword_strike", 3), ("sword_slash", 3), ("sword_sweep", 3), ("sword_thrust", 3), ("guardians_wrath", 2),
    ("lobbed_bolt", 1),
    ("swordplay_drill", 3), ("devastation_drill", 3), ("ambush_drill", 2), ("breakthrough_drill", 1), ("absorbing_drill", 1), ("quickness_drill", 1),
    ("seek_the_answer", 3), ("anticipation", 1), ("counsel", 1), ("heirloom_blade", 1), ("victors_drill", 1)])

deck("storm_volley", "House Corven", "fighter_gamma", 3, "storm", "knave", "storm_mastery", "master_steadfast",
     ["doubt", "grand_sweep", "grand_sweep", "storm_glaring_bolt", "storm_massacre", "lobbed_bolt", "clear_statement", "focused_crushing_dive", "storm_obliteration"], [
    ("henchman_zeta", 1),
    ("turmoil_square", 3),
    ("crown_token_1", 1), ("crown_token_3", 1), ("crown_token_5", 1),
    ("hard_glare", 3), ("interrupt", 3), ("sly_smirk", 1), ("showmans_trick", 2), ("respite", 1), ("mutual_escalation", 3), ("transformation", 3), ("overwhelming_aura", 1),
    ("stillness", 1), ("storm_dodge", 4), ("knowing_smile", 3), ("leg_catch", 3), ("storm_energy_guard", 3),
    ("storm_setup", 1), ("storm_scatter_shot", 2), ("storm_glaring_bolt", 2), ("storm_obliteration", 1), ("storm_rage", 3), ("extreme_assailment", 3),
    ("captains_volley", 3), ("crashing_dive", 3), ("prepared_stance", 3), ("surging_blast", 3), ("homing_bolt", 3), ("palm_charge", 2),
    ("breaching_kick", 3), ("relentless_fury", 3), ("storm_massacre", 1), ("storm_uppercut", 1), ("storm_strength", 1),
    ("counsel", 1), ("focus_of_mind", 1), ("anticipation", 1), ("victors_drill", 1)])
print("decks written")
