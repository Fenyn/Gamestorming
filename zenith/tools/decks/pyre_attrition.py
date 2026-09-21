"""New cards for Last Standing (`data/decks/pyre_attrition.json`), built from the Red TS Majin Buu
tournament sheet. See docs/tournament_import.md for the sheet, the card-by-card read and the three
fan prints that were swapped out for Score cards.

    python tools/add_cards.py decks/pyre_attrition

Titles here are drafts and not yet approved.
"""
from cardlib import (add, strike, art, block, combat, noncombat, duelist, aspect,
                     E, ACC, OPP_ACC, VIG, FLOAT, SEARCH, WHEN, IFS, IFSTOP, USE, DISCARD_IN_PLAY,
                     ALPHA, EMRYS)

# --- The duelist ----------------------------------------------------------
# Bram Ashmark's second printed line, "the Glut": five rungs instead of the Hollow line's three,
# and the hollow with something in it rather than empty. He traded his humanity for power and cannot be
# filled by it (docs/world.md), so the ladder is an appetite escalating: he gnaws, he feasts, he
# gorges, what he took is turned back into him, and at the top he is still not full. The titles
# read off the powers and never off the school, because he may field another one later.
duelist(ALPHA, [
    # The same printed card as the Hollow line's first rung, so it carries the same numbers, and
    # both lines therefore share the one card `personality_bram_ashmark_1_starved`.
    aspect(1, 2, 24, 1, power={"attack": {"kind": "strike", "stages": 3},
                               "effects": [VIG(5), IFSTOP(E("draw", amount=1))]}),
    aspect(2, 2, 20, 1, power={"attack": {"kind": "strike", "stages": 3}, "effects": [ACC(1)]},
           constant={"modifiers": [{"scope": "own", "kind": "any", "life": 1}]}),
    aspect(3, 4, 32, 1, constant={"modifiers": [{"scope": "own", "kind": "any", "life": 3}],
                                  "energy_gain_multiplier": 2, "fervor_gain_bonus": 1}),
    aspect(4, 4, 38, 2, power={"effects": [E("shuffle_discard", amount=8)]}),
    aspect(5, 5, 42, 1, power={"attack": {"kind": "strike", "focused": True, "printed_stages": 10}},
           power_alt={"effects": [E("shuffle_discard", amount=10)]}),
], ["Starved", "Gnawing", "Gorging", "Consuming", "Insatiable"], variant="the Glut", tags=["marked"])

# --- The Relic ------------------------------------------------------------
# Worn like the other three and named for what it takes: two standing workings, off the table and
# out of the duel, once. Used in Combat rather than at the Non-Combat step.
add(id="severing_clasp", title="The Severing Clasp", type="relic", school="", reserve_size=7,
    uses_per_game=1, limit_per_deck=1, relic_step="combat",
    effects=[{"trigger": "relic_use", **DISCARD_IN_PLAY("non_combat", who="any", amount=2, choose=True, up_to=True, remove=True)}])

# --- Life cards -----------------------------------------------------------
strike("pyre_knee_bash", "Pyre Knee Bash", "pyre", atk={"stages": 4}, effects=[ACC(1)])
# A Strike card that answers an Art, which is how the printed one is banded.
block("pyre_warding_stance", "Pyre Warding Stance", "art", "strike", "pyre", endurance=2, effects=[ACC(1)])
# The cleave lends the rest of your school's attacks the word "Sword" for the Combat, so a list
# that reads sword titles can be fed by a school that has none.
strike("pyre_sword_cleave", "Pyre Sword Cleave", "pyre", atk={"stages": 4}, endurance=2,
       effects=[FLOAT("counts_as_title", school="pyre", title="Sword"), ACC(1), OPP_ACC(-1)])
# "If performed against a villain, this attack stays on the table to be used 1 more time."
strike("emrys_rising_blow", "Emrys' Rising Blow", atk={"stages": 3}, character=EMRYS,
       remain_when={"when": {"defender_alignment": "pact"}, "remain": 1}, effects=[ACC(1)],
       remove_after_use=True)
# "Majin only": the mark, not the school, and read off whoever holds Combat the way a bloodline
# gate is. It finds another marked Art in the discard on a hit.
art("ashmarks_ember_spray", "Ashmark's Ember Spray", atk={"printed_life": 5}, character=ALPHA,
    only={"tag": "marked"}, tags=["marked"], remove_after_use=True,
    effects=[ACC(2), IFS(SEARCH(card_type="art", tag="marked", source="discard", to="hand"))])
# Every Seal, on the table and in both Life Decks. The Unsealing win stops existing for the duel.
noncombat("the_watch_goes_dark", "The Watch Goes Dark",
          [USE(DISCARD_IN_PLAY("seal", who="any", all=True, remove=True, life_decks=True))])
# The price is the gate: it needs 5 Energy to use and leaves the duelist on none.
combat("spent_to_the_last", "Spent to the Last",
       [DISCARD_IN_PLAY("non_combat_or_ally", who="any", all=True), E("set_energy", amount=0), ACC(1)],
       only={"energy_min": 5}, limit_per_deck=1)
# An Art that takes the Grounds away instead of wounding, and stirs the marked duelist who uses it.
add(id="riftcry", title="Riftcry", type="art", school="",
    effects=[E("discard_grounds"), WHEN(ACC(1), duelist_character=ALPHA)])
