"""New cards for Crushing Depths (`data/decks/tide_deepwater.json`), built from the Blue MBS Goku
tournament sheet.

    python tools/add_cards.py decks/tide_deepwater

The duelist is Sir Edric Rooke's printed ladder unchanged. The sheet runs the same five printed personality cards
that his Pyre list already uses, so only the school around him changes. That is the theming rule
working as intended: what a card looks like comes from the card, not from the man.

Tide here is heavy water rather than moving water. Every school card is named for the weight doing
what the mechanic does: pulling under, holding down, pressing until something gives. Edric's own
card is named for him and reads off his patience instead of the element.

Titles are approved. See docs/tournament_import.md for the sheet, the fan prints swapped out for
Score cards, and the approximations noted below.
"""
from cardlib import (add, strike, art, block, combat, noncombat, seal, retire,
                     E, OPP, ACC, OPP_ACC, VIG, FORBID, FLOAT, SEARCH, IFS, USE,
                     DISCARD_IN_PLAY, IOTA)

# Renamed into the Sweep family below.
retire("tide_dragged_down", "tide_drag_under", "tide_deep_sink")

# --- Mastery --------------------------------------------------------------
# The later printing of the school, and nothing like the one the coven runs. It pays for Strikes,
# and it lets the duelist spend what the water has already taken instead of blocking. A second
# Mastery for one school is the source's own doing; the two were printed in different sets.
add(id="tide_fathom_mastery", title="Tide Fathom Mastery", type="mastery", school="tide",
    limit_per_deck=1, defense_burn={"school": "tide", "prevent_per": 2},
    modifiers=[{"scope": "own", "kind": "strike", "school": "tide", "life": 2}])

# --- School cards from the sheet ------------------------------------------
# Stays out for as many uses as the duelist has Aspects, and only while either of two named Seals
# is on the table.
strike("tide_pull_under", "Tide Pull Under", "tide", atk={},
       effects=[IFS(DISCARD_IN_PLAY("non_combat_or_ally", amount=1, choose=True))],
       remain_when={"when": {"card_in_play": ["Moth Seal 3", "Moth Seal 4"]}, "remain": "aspect"},
       remove_after_use=True)
strike("tide_welling_deep", "Tide Welling Deep", "tide", atk={"stages": 5},
       effects=[VIG("max", "duelist")], bottom_after_use=True)
strike("tide_deep_anchor", "Tide Deep Anchor", "tide", atk={"stages": 1}, remain=1,
       effects=[FORBID("lower_aspect", "opponent")])
strike("tide_dredge", "Tide Dredge", "tide", atk={"stages": 5}, endurance=2,
       effects=[E("look_at", amount=5, pick={"card_type": "non_combat"}, to="play",
                  rest="bottom", rearrange=True, **{"from": "top"})], remove_after_use=True)
strike("tide_deadweight", "Tide Deadweight", "tide", atk={},
       effects=[IFS(FORBID("strike_attacks", "opponent")), OPP_ACC(-1)], remove_after_use=True)
strike("tide_undersweep", "Tide Undersweep", "tide", atk={"stages": 2},
       effects=[FLOAT("stop_next"), OPP_ACC(-1)])
block("tide_sweep_aside", "Tide Sweep Aside", "strike", "strike", "tide", effects=[OPP_ACC(-1)])
art("tide_crushing_depth", "Tide Crushing Depth", "tide", atk={"printed_life": 6},
    effects=[IFS(DISCARD_IN_PLAY("attached", who="self", all=True))], remove_after_use=True)

# --- Named cards from the sheet -------------------------------------------
# The hold keeps costing them: an Energy at the start of each of their attack phases for the rest
# of the Combat. Its search finds a card with "Throw" in the title; Sweep is our word for the same
# family of holds and throws.
strike("ashmarks_choke_hold", "Ashmark's Choke Hold", atk={"stages": 4}, empower=2,
       effects=[FLOAT("phase_drain", "opponent", energy=1),
                IFS(SEARCH(title_contains="Sweep", to="hand"))])
# Every Non-Combat the seven turn over goes into play, and the rest are shuffled back.
noncombat("edrics_low_water", "Edric Waits for Low Water", character=IOTA,
          effects=[USE(E("look_at", amount=7, pick={"card_type": "non_combat"}, to="play",
                         all_matches=True, shuffle_after=True, **{"from": "top"}))])

# The moth set is the later, alternate printing of the seven, and the marble set is the earlier
# one. They are separate cards, not errata of each other: different sets, numbers and text. Two of
# ours had drifted, `moth_seal_4` carrying the earlier card's text (which is `marble_seal_4`'s job)
# and `moth_seal_7` a placeholder. These are the printings this sheet runs.
seal("moth_seal_4", "Moth Seal 4", "moth", 4,
     [DISCARD_IN_PLAY("ally", all=True)], protect_from_removal=True)
seal("moth_seal_7", "Moth Seal 7", "moth", 7, [],
     forbid=[{"who": "opponent", "what": "mastery"}])

# --- Standing in for the fan prints ---------------------------------------
strike("tide_bearing_down", "Tide Bearing Down", "tide", atk={"stages": 3}, effects=[OPP_ACC(-2)])
strike("tide_deep_sweep", "Tide Deep Sweep", "tide", atk={"stages": 4}, effects=[OPP_ACC(-1)])
strike("tide_pressure_wave", "Tide Pressure Wave", "tide", atk={"stages": 4}, effects=[OPP_ACC(-2)])
block("tide_deep_guard", "Tide Deep Guard", "art", "strike", "tide", effects=[OPP_ACC(-2)])
art("tide_black_water", "Tide Black Water", "tide", atk={}, effects=[OPP_ACC(-3)])
art("tide_full_weight", "Tide Full Weight", "tide", atk={"printed_life": 5},
    effects=[ACC(1), OPP_ACC(-2)])
combat("tide_held_under", "Tide Held Under", [OPP_ACC(-2), OPP("energy", amount=-2)], school="tide")
noncombat("tide_heavy_water", "Tide Heavy Water", school="tide",
          modifiers=[{"scope": "own", "kind": "strike", "stages": 1}])
