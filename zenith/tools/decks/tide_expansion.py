"""The Tide expansion: 22 new school cards and 2 Masteries, bringing the school to 50.

    python tools/add_card.py decks/tide_expansion

Titles are the ones locked in `docs/expansion_batch2_review.md`, and each card stands in for the
printed card recorded against its id in `tools/gen_roster.py` (NEW_SOURCES) and in
`tools/source_candidates.tsv`. Every printed clause is built as written. The only readings:

* A printed "if you declared a Tokui-Waza" rider is always on.
* A Non-Combat card in the printed game's sense includes Drills; "Non-Combat card" in a search or a
  pick is written `non_combat_or_drill`.
* Empower drops the lines printed after it and keeps the ones printed before it.
"""
from cardlib import (add, strike, art, block, drill, noncombat, combat,
                     E, ACC, OPP_ACC, VIG, FLOAT, SEARCH, IFS, USE, WHEN, DISCARD_IN_PLAY)


# --- Drowning -------------------------------------------------------------
strike("tide_strike_15", "Tide Frozen Over", "tide", atk={"stages": 2},
       effects=[E("set_fervor", "opponent", amount=0),
                FLOAT("no_fervor_gain", who="opponent", duration="own_turn_start")])
strike("tide_strike_18", "Tide Dead Calm", "tide", atk={"stages": 2, "cost_stages": 2},
       effects=[IFS(E("discard_life", "opponent", amount="five_minus_fervor"))])
strike("tide_strike_20", "Tide Pounding Surf", "tide", atk={"stages": 3}, endurance=3,
       effects=[ACC(1), IFS(FLOAT("table_base_fervor"))])
# "Physical attack doing 1 life card of damage": printed wounds, no Strike Table.
strike("tide_strike_21", "Tide Sinking Blow", "tide", atk={"printed_life": 1},
       effects=[IFS(WHEN(E("discard_life", "opponent", amount=5), opponent_discard_top_not_attack="strike"))])
art("tide_art_15", "Tide Leeching Brine", "tide", atk={},
    attachment={"target": "opponent_duelist", "discard_at_full": True},
    effects=[IFS(E("attach", to="opponent_duelist")),
             {"trigger": "turn_start", "on_turn": "opponent", "op": "discard_life", "who": "opponent", "amount": 2}])
noncombat("tide_noncombat_03", "Tide Riptide",
          [USE(E("set_fervor", "opponent", amount=0)), USE(E("lose_aspect", "opponent"))],
          school="tide", remove_after_use=True)
# Printed outside the Styled Drill count, so it neither sets the one-school lock nor is kept out by it.
drill("tide_drill_03", "Tide Salt Burn Drill", "tide", drill_lock_exempt=True, mill_on_empty_fervor=True,
      modifiers=[{"scope": "own", "kind": "any", "stages": 2}])

# --- Allies ---------------------------------------------------------------
combat("tide_combat_02", "Tide Washout",
       [E("discard_in_play", "any", card_type="drill", amount=1, choose=True, remove=True),
        VIG(2, "all"), ACC(1)],
       school="tide", endurance=1, remove_after_use=True)
noncombat("tide_noncombat_02", "Tide Answering Current",
          [USE(SEARCH(card_type="ally", to="play", stages=3)),
           USE(SEARCH(card_type="ally", source="discard", to="play", stages=3, must=True))],
          school="tide", remove_after_use=True)
drill("tide_drill_04", "Tide Following Current Drill", "tide",
      modifiers=[{"scope": "own", "kind": "any", "stages": 2, "when": {"performed_by": "ally"}}])
drill("tide_drill_02", "Tide Mooring Drill", "tide", allies_undiscardable=True, limit_per_deck=1)
drill("tide_drill_01", "Tide Shoal Drill", "tide",
      effects=[{"trigger": "on_success", "op": "search", "card_type": "ally", "aspect": 1, "to": "hand",
                "when": {"attack_kind": "strike"}}])

# --- Guard ----------------------------------------------------------------
block("tide_strike_19", "Tide Flotsam", "art", "strike", "tide", endurance=3, remove_after_use=True,
      effects=[ACC(1), SEARCH(source="discard", card_type="non_combat_or_drill", amount=2, to="deck_top", must=True)])
block("tide_strike_17", "Tide Sounding", "strike", "strike", "tide",
      effects=[E("reveal_pick", amount=3, self_picks_when={"aspect_min": 3})])
art("tide_art_13", "Tide Backwash", "tide", atk={"focused": True, "printed_life": 5},
    defense={"stops": "art"}, remove_after_use=True,
    effects=[SEARCH(source="discard", amount_from="fervor", to="deck_shuffle", must=True,
                    if_all={"card_type": "non_combat_or_drill", "effects": [VIG(3)]})])
block("tide_combat_04", "Tide Parting Waters", "any", "combat", "tide", endurance_from="fervor",
      remove_after_use=True, discard_instead_when={"aspect_min": 3})
drill("tide_drill_05", "Tide Seawall Drill", "tide", shield="strike")

# --- Digging and board strip ----------------------------------------------
combat("tide_combat_03", "Tide Returning Tide", [OPP_ACC(-2), E("recover", amount=3)], school="tide")
noncombat("tide_noncombat_04", "Tide Erosion", [USE(DISCARD_IN_PLAY("drill", amount=1, choose=True))], school="tide")
drill("tide_drill_06", "Tide Narrow Channel Drill", "tide", opponent_one_non_combat=True)

# --- Tide attacks ---------------------------------------------------------
strike("tide_strike_16", "Tide Breaking Sea", "tide", atk={"stages": 6}, effects=[OPP_ACC(-4)])
art("tide_art_14", "Tide Spring Tide", "tide", atk={"printed_life": 5}, effects=[ACC(2), OPP_ACC(-1)])

# --- Masteries ------------------------------------------------------------
# The discarded card pays for the stop; the line after it reads what went.
add(id="tide_mastery_03", title="Tide Eddy Mastery", type="mastery", school="tide", limit_per_deck=1,
    once_per_combat=True, defense={"stops": "any", "cost_hand": 1},
    effects=[WHEN(OPP_ACC(-2), discard_top_school="tide")])
add(id="tide_mastery_04", title="Tide Floodtide Mastery", type="mastery", school="tide", limit_per_deck=1,
    modifiers=[{"scope": "own", "kind": "art", "life": 1}],
    grant_attack_lines={"school": "tide", "kind": "art", "effects": [IFS(ACC(1))]})
