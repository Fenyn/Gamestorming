"""The Steel expansion: 20 new school cards and 3 Masteries, bringing the school to 50.

    python tools/add_card.py decks/steel_expansion

Titles are the ones locked in `docs/expansion_batch2_review.md`, and each card stands in for the
printed card recorded against its id in `tools/gen_roster.py` (NEW_SOURCES) and in
`tools/source_candidates.tsv`. Every printed clause is built as written (the Pyre review rule of
2026-09-23). The only readings:

* A printed "if you declared a Tokui-Waza" rider is always on. "If your opponent declared a
  Namekian Tokui-Waza" reads the opponent's deck school instead, which is what their declaration was.
* "Sensei Deck." is a note on where the card may be kept and has nothing to build here.
* "Saiyan Heritage only" is Draconic only, the bloodline gate. Steel Masteries need a Draconic duelist.
* Empower drops the lines printed after it and keeps the ones printed before it.
"""
from cardlib import (add, strike, art, drill, noncombat, combat,
                     E, ACC, OPP_ACC, VIG, FLOAT, SEARCH, IFS, IFSTOP, USE, WHEN,
                     AFTER_EMPOWER, DISCARD_IN_PLAY, DRACONIC)


def OTHER_ATTACKS(**params):
    d = FLOAT("modifier", **params)
    d["exclude_source"] = True
    return d


# --- Might comparison -----------------------------------------------------
strike("steel_strike_28", "Steel Towering Charge", "steel",
       atk={"stages": 4, "variants": [{"when": {"higher_might": True},
                                       "effects": [DISCARD_IN_PLAY("ally", amount=2, up_to=True, choose=True)]}]})
# Only the Strike Table result doubles, and the ratings are compared as the damage is worked out.
strike("steel_strike_24", "Steel Towering Frame", "steel",
       atk={"stages": 3, "table_multiply": {"by": 2, "higher_might": True}})
# The Focus reads the two Main Personalities; the Endurance payment is the duelist's.
art("steel_art_07", "Steel Boiling Blood", "steel",
    atk={"printed_life": 6, "variants": [{"when": {"duelist_higher_might": True}, "focused": True}]},
    effects=[FLOAT("endurance_energy", energy=1)])
art("steel_art_09", "Steel Dragonfire Breath", "steel",
    atk={"variants": [{"when": {"higher_might": True},
                       "effects": [ACC(1), OTHER_ATTACKS(scope="own", kind="any", life=2)]}]})
# Used from play in Combat, like any Non-Combat of the band.
noncombat("steel_noncombat_01", "Steel Blood Memory",
          [USE(ACC(2)), USE(E("recover", amount=2, **{"from": "bottom"})),
           USE(WHEN(E("draw", amount=1), duelist_higher_might=True))],
          school="steel", remove_after_use=True)
# "Use when you perform an attack": the gain is banked for the next attack, not the one in the air.
add(id="steel_combat_02", title="Steel Drawn Breath", type="combat", school="steel",
    use_at="performing_attack", remove_after_use=True,
    effects=[E("energy", amount="max", target="duelist", bank_gain={"cap": 5})])

# --- Endurance armour -----------------------------------------------------
# "If stopped, select a Drill in play": either side's, and the pick is not optional.
strike("steel_strike_23", "Steel Thrashing Tail", "steel", atk={}, endurance=2, remove_after_use=True,
       effects=[IFSTOP(E("discard_in_play", "any", card_type="drill", amount=1, choose=True, remove=True))])
art("steel_art_13", "Steel Cornered Blood", "steel", atk={"printed_life": 5}, endurance=4,
    effects=[FLOAT("make_focused", school="steel", empower_only=True), ACC(1)])
drill("steel_drill_04", "Steel Hardscale Drill", "steel", shield="strike")
# The Fervor line is printed before Empower and stays; the Endurance count starts when it is played.
strike("steel_strike_25", "Steel Shedding Scales", "steel", atk={"stages": 3}, endurance=1, empower=2,
       effects=[ACC(1), AFTER_EMPOWER(FLOAT("modifier", scope="own", kind="strike", stages=1, per_endurance_since=True))])

# --- Energy squeeze -------------------------------------------------------
strike("steel_strike_27", "Steel Constricting Grip", "steel", atk={"focused": True, "stages": 3},
       effects=[SEARCH(card_type="drill", school="steel", to="play"),
                IFS(FLOAT("surge_zero", who="opponent", duration="next_turn_end"))])
drill("steel_drill_02", "Steel Baleful Gaze Drill", "steel",
      modifiers=[{"scope": "opponent_cost", "kind": "any", "stages": 1},
                 {"scope": "opponent_cost", "kind": "any", "stages": 1, "when": {"opponent_style": "root"}}])
# Printed outside the Styled Drill count, so it neither sets the one-school lock nor is kept out by it.
drill("steel_drill_03", "Steel Stifling Presence Drill", "steel", drill_lock_exempt=True,
      opponent_power_up_less=1, modifiers=[{"scope": "own", "kind": "any", "stages": 2}])

# --- Empower --------------------------------------------------------------
# The bracketed rider is the card's second use: discarded from hand as a Strike is performed.
strike("steel_strike_26", "Steel Blood Unbound", "steel", atk={"stages": 3}, empower=2,
       discard_boost={"kind": "strike", "stages": 4, "effects": [ACC(1)]},
       effects=[AFTER_EMPOWER(FLOAT("empower_keeps_text"))])
art("steel_art_14", "Steel Awakened Blood", "steel", atk={"printed_life": 5}, empower=2,
    effects=[AFTER_EMPOWER(SEARCH(card_type="drill", school="steel", adds_damage=True, to="play")),
             AFTER_EMPOWER(OPP_ACC(-2))])
art("steel_art_10", "Steel Reclaimed Hoard", "steel", atk={"printed_life": 3}, empower=4, only=DRACONIC,
    remove_after_use=True,
    effects=[AFTER_EMPOWER(SEARCH(source="discard", school="steel", amount=2, to="deck_top", must=True,
                                  exclude_title="Steel Reclaimed Hoard"))])
art("steel_art_12", "Steel Routing Roar", "steel", atk={}, empower=3, only=DRACONIC, remove_after_use=True,
    effects=[AFTER_EMPOWER(DISCARD_IN_PLAY("ally", amount=3, up_to=True, choose=True))])
art("steel_art_08", "Steel Scorching Breath", "steel", atk={}, empower=4,
    effects=[ACC(1), AFTER_EMPOWER(FLOAT("damage_removes")), AFTER_EMPOWER(FLOAT("no_prevent"))])
art("steel_art_11", "Steel Tail Sweep", "steel", atk={"printed_life": 3}, empower=4, only=DRACONIC,
    remove_after_use=True,
    effects=[AFTER_EMPOWER(DISCARD_IN_PLAY("drill", amount=3, up_to=True, choose=True))])

# --- Raw Strikes ----------------------------------------------------------
noncombat("steel_noncombat_02", "Steel Bared Fangs",
          [USE(VIG(-4, "duelist")), USE(FLOAT("modifier", scope="own", kind="any", life=3))],
          school="steel")

# --- Masteries ------------------------------------------------------------
add(id="steel_mastery_02", title="Steel Dragonfear Mastery", type="mastery", school="steel",
    duelist_bloodline="draconic", limit_per_deck=1,
    effects=[{"trigger": "entering_combat", "op": "draw_check", "school": "steel",
              "effects": [{"may": True, "op": "show_checked",
                           "then": [E("energy", "opponent", amount=-4, no_overflow=True)]}]}])
add(id="steel_mastery_03", title="Steel Scale Mastery", type="mastery", school="steel",
    duelist_bloodline="draconic", limit_per_deck=1,
    effects=[{"trigger": "entering_combat", "op": "draw_check", "school": "steel",
              "effects": [{"may": True, "op": "show_checked",
                           "then": [FLOAT("prevent_first_attack", stages=4, life=4)],
                           "otherwise": [FLOAT("prevent_first_attack", stages=4)]}],
              "else_effects": [FLOAT("prevent_first_attack", stages=4)]}])
add(id="steel_mastery_04", title="Steel Bloodrage Mastery", type="mastery", school="steel",
    duelist_bloodline="draconic", limit_per_deck=1, no_ascension_win=True,
    grant_attack_lines={"school": "steel", "effects": [ACC(1), VIG(3)]},
    recover_bonus={"school": "steel", "effects": [ACC(2), VIG(4, "duelist")]})
