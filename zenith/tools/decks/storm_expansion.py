"""The Storm expansion: 26 new school cards, filling the gaps the school had no card for.

    python tools/add_card.py decks/storm_expansion

Ids and titles are approved. Every card stands in for one printed card; which one is recorded in
`docs/card_roster.csv` through the table in `tools/gen_roster.py`, and nowhere else. Cards are
listed here in the order they were approved, and referred to only by their own ids.

Two readings run through the whole batch:

* A printed "if you declared a Tokui-Waza" rider is always on, so a card carrying one is written
  with the rider applied and no condition. The source's own errata treat the declaration as the
  normal state of play.
* A printed tournament-format note has no parallel here and is dropped.
"""
from cardlib import (add, strike, art, block, combat, noncombat, drill,
                     E, ACC, OPP_ACC, VIG, FLOAT, SEARCH, IFS, IFSTOP, USE,
                     AFTER_EMPOWER, WHEN, DISCARD_IN_PLAY)


# "All of your OTHER attacks do +N for the remainder of Combat." The line runs while the attack
# carrying it is still in the air, so the flag keeps that one attack out of its own bonus.
def OTHER_ATTACKS(**params):
    d = FLOAT("modifier", **params)
    d["exclude_source"] = True
    return d


# --- Strike answers -------------------------------------------------------
# The school's plain Strike answer. Until now only storm_static_field stopped a Strike, and that
# card is an attack as well.
block("storm_rising_gust", "Storm Rising Gust", "strike", "strike", "storm", effects=[ACC(1)])
# The second stop is a floating one, and it waits for their next attack phase as printed. A
# `next_attack_phase` float is aimed at the attacks it answers, so it lives through its owner's
# own phase in between and does not spend itself on the attack this card already stopped.
block("storm_twin_earthing", "Storm Twin Earthing", "strike", "strike", "storm",
      effects=[FLOAT("stop_next", duration="next_attack_phase", kind="strike")])
# Printed in the Energy Combat band although it answers a Strike, so it is typed by the band and
# stops by what the text says, the way pyre_warding_stance already is.
block("storm_damping_guard", "Storm Damping Guard", "strike", "art", "storm", effects=[OPP_ACC(-1)])
# A Non-Combat that stops from the table and then goes under the Life Deck instead of to the pile.
add(id="storm_returning_front", title="Storm Returning Front", type="non_combat", school="storm",
    defense={"stops": "strike"}, bottom_after_use=True)

# --- Drills ---------------------------------------------------------------
# The school's first Drills of any kind: a shield for each attack kind, then two standing effects.
drill("storm_mantle_drill", "Storm Mantle Drill", "storm", shield="strike")
drill("storm_dispersal_drill", "Storm Dispersal Drill", "storm", shield="art")
drill("storm_tight_coil_drill", "Storm Tight Coil Drill", "storm",
      modifiers=[{"scope": "own", "kind": "art", "life": 2}])
drill("storm_conduit_drill", "Storm Conduit Drill", "storm",
      modifiers=[{"scope": "cost", "kind": "art", "stages": -1, "min": 1}])

# --- Non-Combats and Combat cards -----------------------------------------
# Waits for a single hit of five wounds or more, then brings the company back at full Energy.
noncombat("storm_mustering_peal", "Storm Mustering Peal",
          [USE(SEARCH(card_type="ally", source="discard", amount=3, to="play", stages="max"))],
          school="storm", endurance=2, only={"when": {"took_wounds_min": 5}})
# Their Seals go under their own Life Deck, in the order the user picks them.
combat("storm_scattering_gale", "Storm Scattering Gale",
       [DISCARD_IN_PLAY("seal", amount=2, up_to=True, choose=True, to="deck_bottom")],
       school="storm", endurance=3)
# Prepared as Combat is entered: the hand is shown, and three of the school in it buys a rider
# that waives what the duelist pays for card effects.
add(id="storm_free_current", title="Storm Free Current", type="combat", school="storm",
    use_at="entering_combat",
    attachment={"target": "duelist", "duration": "combat",
                "modifiers": [{"scope": "cost", "kind": "any", "set": 0}]},
    effects=[E("reveal_hand"),
             WHEN(E("attach", to="duelist"), hand_school_min={"school": "storm", "count": 3})])

# --- Energy gain ----------------------------------------------------------
block("storm_catching_stance", "Storm Catching Stance", "art", "art", "storm",
      effects=[VIG(4), OPP_ACC(-1)])
strike("storm_feeding_arc", "Storm Feeding Arc", "storm", atk={},
       effects=[VIG(3, "duelist"), E("remove_discard", "opponent", amount=1)])
strike("storm_return_stroke", "Storm Return Stroke", "storm", atk={"stages": 3},
       effects=[IFS(VIG("max", "duelist")), ACC(1)])

# --- Hand attack and Fervor denial ----------------------------------------
# "Look at their hand and choose a Physical Combat card; they discard it." The band is a filter on
# the card's own type, and a hand with none of that band is still seen.
strike("storm_wringing_squall", "Storm Wringing Squall", "storm", atk={}, endurance=3,
       effects=[IFS(E("discard_hand", "opponent", amount=1, random=False, chooser="owner",
                      reveal=True, filter={"card_type": "strike"}))])
art("storm_rolling_peal", "Storm Rolling Peal", "storm", atk={}, empower=3,
    effects=[AFTER_EMPOWER(OTHER_ATTACKS(scope="own", kind="art", life=1)),
             AFTER_EMPOWER(OPP_ACC(-2))])

# --- The cost band --------------------------------------------------------
art("storm_idle_spark", "Storm Idle Spark", "storm", atk={"printed_life": 3, "cost_stages": 0})
art("storm_pent_discharge", "Storm Pent Discharge", "storm", atk={"cost_stages": 3}, endurance=2,
    effects=[IFS(E("discard_hand", "opponent", amount=1, random=False))])

# --- Workhorses -----------------------------------------------------------
strike("storm_opened_channel", "Storm Opened Channel", "storm", atk={"focused": True, "stages": 2},
       effects=[IFS(FLOAT("modifier", scope="own", kind="art", life=2))])
art("storm_ungrounded_flash", "Storm Ungrounded Flash", "storm",
    atk={"printed_life": 6, "no_stop_by": "art"})
strike("storm_felling_gust", "Storm Felling Gust", "storm", atk={"stages": 4},
       effects=[IFS(DISCARD_IN_PLAY("ally", amount=1, choose=True))])
art("storm_residual_shock", "Storm Residual Shock", "storm", atk={"printed_life": 6},
    effects=[IFSTOP(E("discard_life", "opponent", amount=2))])
strike("storm_levelling_wind", "Storm Levelling Wind", "storm",
       atk={"focused": True, "stages": 3}, endurance=2,
       effects=[IFS(DISCARD_IN_PLAY("ally", amount=4, up_to=True, choose=True)), OPP_ACC(-2)])
strike("storm_tailwind", "Storm Tailwind", "storm", atk={"stages": 4}, endurance=3,
       effects=[OTHER_ATTACKS(scope="own", kind="any", stages=1), OPP_ACC(-2)])
art("storm_cold_front", "Storm Cold Front", "storm", atk={}, effects=[OPP_ACC(-2)])
# Names a card that can perform a Strike and takes every copy out of their Life Deck. The naming
# is unconditional on the printed card, so it does not wait on the attack landing.
art("storm_silencing_static", "Storm Silencing Static", "storm", atk={"printed_life": 5},
    effects=[E("name_card", pool="opponent_deck", filter={"attack_kind": "strike"},
               strip={"to": "discard"})])
