"""The Pyre expansion: 25 new school cards and 2 Masteries, bringing the school to 50.

    python tools/add_card.py decks/pyre_expansion

Titles are the ones locked in `docs/expansion_batch2_review.md`, and each card stands in for the
printed card recorded against its id in `tools/gen_roster.py` (NEW_SOURCES) and in
`tools/source_candidates.tsv`.

Readings that run through the whole batch, as for the Storm and Root expansions:

* A printed "if you declared a Tokui-Waza" rider is always on.
* A card printed in the Physical Combat band that stops an energy attack is a Strike card that
  stops an Art, typed by its band.
* The one-school-of-Drills exemption a printed Drill carries is dropped.
"""
from cardlib import (add, strike, art, block, combat, drill,
                     E, ACC, OPP_ACC, FLOAT, SEARCH, IFS, WHEN, AFTER_EMPOWER, DISCARD_IN_PLAY)


# --- Fervor as a number ---------------------------------------------------
# Every attack reads the Fervor as it is worked out, so the Drill grows with the climb.
drill("pyre_drill_01", "Pyre Rising Heat Drill", "pyre", limit_per_deck=1,
      modifiers=[{"scope": "own", "kind": "any", "stages": 1, "per_fervor": True}])
# Endurance X on a life card is the owner's Fervor when the card is turned over. For the rest of
# Combat, "if successful" lines that raise the user's Fervor or lower the opponent's are secondary.
strike("pyre_strike_22", "Pyre Blazing Hide", "pyre", atk={"stages": 3}, endurance_from="fervor",
       effects=[FLOAT("fervor_hits_secondary")])
block("pyre_strike_23", "Pyre Choking Smoke", "art", "strike", "pyre", endurance_from="fervor",
      effects=[OPP_ACC(-1),
               WHEN(E("remove_discard", "opponent", amount=10, **{"from": "bottom"}), opponent_fervor_max=1)])
art("pyre_art_04", "Pyre Drawing Flue", "pyre", atk={"printed_life": 1, "life_per_fervor": 1},
    endurance=4, effects=[IFS(E("shuffle_source"))])

# --- Drills ---------------------------------------------------------------
drill("pyre_drill_02", "Pyre Banked Coals Drill", "pyre", fervor_lock=True)
drill("pyre_drill_03", "Pyre Burnt Offering Drill", "pyre", defense={"stops": "any"},
      only={"when": {"hand_min": 1}}, effects=[E("discard_hand", all=True)])
drill("pyre_drill_04", "Pyre Cinder Sift Drill", "pyre", once_per_combat=True,
      effects=[{"trigger": "on_success", "may": True, "op": "search", "source": "discard",
                "to": "deck_shuffle", "when": {"attack_kind": "strike", "discard_min": 1},
                "then": [E("mark_used")]}])
drill("pyre_drill_05", "Pyre Flame Screen Drill", "pyre", shield="art")
drill("pyre_drill_06", "Pyre Hearthstone Drill", "pyre",
      keeps_drills_on_advance={"self_when": {"opponent_fervor": 0}})
drill("pyre_drill_07", "Pyre Kiln Drill", "pyre", modifiers=[{"scope": "own", "kind": "art", "life": 2}])
# Printed outside the Styled Drill count, so it neither sets the one-school lock nor is kept out by it.
drill("pyre_drill_08", "Pyre Smoldering Drill", "pyre", drill_lock_exempt=True,
      modifiers=[{"scope": "own", "kind": "any", "stages": 2}],
      effects=[{"trigger": "turn_start", "op": "remove_discard", "who": "opponent", "amount": 3, "from": "bottom"}])
strike("pyre_strike_25", "Pyre Laying Fire", "pyre", atk={"stages": 3}, endurance=2,
       effects=[IFS(SEARCH(card_type="drill", school="pyre", to="play"))])
# Empower drops every line printed after it, the way Pyre Ashfall reads.
strike("pyre_strike_24", "Pyre Bonfire", "pyre", atk={}, empower=4, remove_after_use=True,
       effects=[AFTER_EMPOWER(SEARCH(card_type="drill", school="pyre", amount=5, to="play")),
                AFTER_EMPOWER(ACC(1))])

# --- Ash and the board ----------------------------------------------------
strike("pyre_strike_26", "Pyre Cremation", "pyre", atk={},
       effects=[IFS(E("remove_discard", "opponent", all=True))])
# The duelist pays 5 as the card is used, whoever holds Combat. Both sides lose their Allies and
# Non-Combat cards (Drills among them); Seals and Grounds are not Non-Combat cards.
combat("pyre_combat_02", "Pyre Conflagration",
       [DISCARD_IN_PLAY("non_combat_or_ally", all=True),
        DISCARD_IN_PLAY("non_combat_or_ally", who="self", all=True),
        E("set_energy", amount=0, target="duelist"), ACC(1)],
       school="pyre", only={"duelist_pays": 5}, limit_per_deck=1)

# --- Arts and Art answers -------------------------------------------------
art("pyre_art_05", "Pyre Burned Through", "pyre", atk={"printed_life": 5},
    effects=[FLOAT("no_endurance", who="opponent", school="pyre"), IFS(ACC(2))])
art("pyre_art_06", "Pyre Flare Volley", "pyre", atk={"printed_life": 2, "pay_hand": {"life": 3}},
    endurance=2, remain=2, remove_after_use=True)
# The five are the user's choice from the pile, and not optional when there are five.
art("pyre_art_07", "Pyre Phoenix Flame", "pyre", atk={"printed_life": 5}, remove_after_use=True,
    effects=[IFS(SEARCH(source="discard", school="pyre", amount=5, to="deck_shuffle", must=True))])
art("pyre_art_08", "Pyre Struck Spark", "pyre", atk={"printed_life": 3, "cost_stages": 1}, effects=[ACC(1)])
art("pyre_art_09", "Pyre Sudden Flare", "pyre", atk={"focused": True, "printed_life": 3}, effects=[IFS(ACC(2))])
# "6 wounds or lower their duelist an Aspect": the Aspect is taken in place of the damage, the way
# Pyre Firestorm trades its damage for the board.
art("pyre_art_10", "Pyre Unmaking Blaze", "pyre", atk={"printed_life": 6}, remove_after_use=True,
    effects=[{"trigger": "before_damage", "may": True, "skip_damage": True, "op": "lose_aspect", "who": "opponent"}])
art("pyre_art_11", "Pyre White Flame", "pyre", atk={"printed_life": 6, "damage_removes": True},
    endurance=2, remove_after_use=True, effects=[E("draw", amount=1, **{"from": "bottom"})])
combat("pyre_combat_03", "Pyre Stoked Blaze",
       [FLOAT("modifier", scope="cost", kind="art", stages=-1, min=1),
        FLOAT("modifier", scope="own", kind="art", life=2), OPP_ACC(-1)],
       school="pyre")
# The rider only needs the user's own Fervor at 1 or more once the declared condition is read as on.
block("pyre_strike_27", "Pyre Heat Haze", "art", "strike", "pyre", remove_after_use=True, limit_per_deck=1,
      effects=[WHEN(E("stop_all", kind="art"), fervor_min=1)])

# --- Climbing blocks ------------------------------------------------------
block("pyre_strike_28", "Pyre Backfire", "strike", "strike", "pyre", remove_after_use=True,
      effects=[E("discard_life", "opponent", amount=3)])

# --- Masteries ------------------------------------------------------------
add(id="pyre_mastery_03", title="Pyre Tinder Mastery", type="mastery", school="pyre", limit_per_deck=1,
    effects=[{"trigger": "entering_combat", "may": True, "op": "remove_discard", "amount": 1,
              "check": "school", "school": "pyre", "when": {"discard_min": 1},
              "effects": [FLOAT("modifier", scope="own", kind="strike", stages=3)],
              "else_effects": [FLOAT("modifier", scope="own", kind="strike", stages=1)]}])
add(id="pyre_mastery_04", title="Pyre Cinder Mastery", type="mastery", school="pyre", limit_per_deck=1,
    effects=[{"trigger": "on_attack", "op": "fervor", "who": "opponent", "amount": -1,
              "when": {"attack_kind": "art"}},
             {"trigger": "on_stopped", "op": "discard_life", "who": "opponent", "amount": 2,
              "when": {"attack_kind": "art", "source_school": "pyre"}}])
