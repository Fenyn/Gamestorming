"""The Shade expansion: 20 new school cards and 3 Masteries, bringing the school to 50.

    python tools/add_card.py decks/shade_expansion

Titles are the ones locked in `docs/expansion_batch2_review.md`, and each card stands in for the
printed card recorded against its id in `tools/gen_roster.py` (NEW_SOURCES) and in
`tools/source_candidates.tsv`. Every printed clause is built as written. The only readings:

* A printed "if you declared a Tokui-Waza" rider is always on.
* A printed card with "Kick" in its title is a Whisper here and carries the `whisper` tag, which is
  what the Kick-searching cards read.
* A Non-Combat card in the printed game's sense includes Drills (`non_combat_card`).
"""
from cardlib import (add, strike, art, block, drill, noncombat, combat,
                     E, ACC, OPP, OPP_ACC, VIG, FLOAT, SEARCH, IFS, IFSTOP, USE, WHEN, DISCARD_IN_PLAY)


# --- Whisper --------------------------------------------------------------
block("shade_strike_18", "Shade Feeding Whisper", "strike", "strike", "shade", tags=["whisper"], effects=[ACC(2)])
strike("shade_strike_20", "Shade Opening Whisper", "shade", atk={"stages": 10, "only_first_card": True},
       tags=["whisper"],
       effects=[IFS(E("forbid", "opponent", what="strike_attacks", duration="combat")),
                IFSTOP(E("discard_life", amount=5))])
# The rider sits on one of their Non-Combat cards and shuts it off while it is there.
strike("shade_strike_16", "Shade Stilling Whisper", "shade", atk={"stages": 3}, tags=["whisper"],
       attachment={"target": "opponent_non_combat", "disables_host": True},
       effects=[IFS(E("attach", to="opponent_non_combat"))])

# --- Life Deck attack -----------------------------------------------------
# "Search your opponent's Life Deck for 1 copy": the namer searches, so the deck is shown to them.
strike("shade_strike_21", "Shade Named Doom", "shade", atk={"stages": 3},
       effects=[E("name_card", pool="opponent_deck", filter={"non_seal": True}, strip={"to": "discard", "amount": 1})])
combat("shade_combat_03", "Shade Creeping Dark", [E("discard_life", "opponent", amount="owner_surge")], school="shade")
# "All of your opponents must search their Life Decks": the namer names from every card there is.
combat("shade_combat_02", "Shade Erased Name",
       [E("name_card", pool="library", filter={"card_type": "hand_combat"}, strip={"to": "removed"})],
       school="shade", remove_after_use=True)
combat("shade_combat_05", "Shade Mockery Hex",
       [E("discard_life", "opponent", amount="twice_fervor"), {"may": True, "op": "cycle_hand", "who": "opponent"}],
       school="shade", remove_after_use=True)
noncombat("shade_noncombat_01", "Shade Pilfering Shadow",
          [USE(SEARCH(whose="opponent", amount=2, to="removed"))], school="shade", remove_after_use=True)

# --- Hexes ----------------------------------------------------------------
strike("shade_strike_17", "Shade Wasting Mark", "shade", atk={"stages": 3},
       attachment={"target": "opponent_duelist", "discard_at_full": True,
                   "host_modifiers": [{"scope": "own", "kind": "any", "stages": -2}]},
       effects=[E("attach", to="opponent_duelist")])

# --- Hand attack ----------------------------------------------------------
art("shade_art_13", "Shade Dilemma Hex", "shade", atk={"cost_stages": 3},
    effects=[IFS({"may": True, "op": "discard_hand", "amount": 1, "random": False,
                  "then": [{"may": True, "asks": "opponent", "op": "discard_hand", "who": "opponent", "amount": 1,
                            "random": True, "otherwise": [E("energy", "opponent", amount=-4)]}]})])
combat("shade_combat_04", "Shade Stolen Secret",
       [E("reveal_hand", "opponent", look=True), E("skip_next_attack_phase", "opponent"),
        FLOAT("modifier", scope="own", kind="any", life=2, once=True)],
       school="shade", endurance=2)
drill("shade_drill_04", "Shade Clouded Mind Drill", "shade",
      effects=[{"trigger": "on_success", "op": "discard_hand", "who": "opponent", "amount": 1, "random": True, "to": "deck_shuffle"},
               {"trigger": "on_success", "op": "draw", "who": "opponent", "amount": 1}])

# --- Answers --------------------------------------------------------------
block("shade_strike_19", "Shade Gathered Hexes", "art", "strike", "shade", remove_after_use=True,
      effects=[SEARCH(source="discard", school="shade", amount=3, to="deck_shuffle", must=True)])
block("shade_strike_22", "Shade Sapping Shadow", "strike", "strike", "shade",
      effects=[E("energy", "opponent", amount=-1, target="duelist"), OPP_ACC(-1)])
drill("shade_drill_07", "Shade Reclaimed Hex Drill", "shade",
      effects=[{"trigger": "on_stop", "may": True, "op": "recover", "amount": 1, "from": "bottom"}])
drill("shade_drill_05", "Shade Umbra Drill", "shade", shield="art")

# --- Shade attacks --------------------------------------------------------
strike("shade_strike_23", "Shade Reaching Shadow", "shade", atk={"stages": 3}, effects=[IFS(VIG(3))])
art("shade_art_12", "Shade Culling Hex", "shade", atk={}, endurance=2,
    effects=[IFS(DISCARD_IN_PLAY("ally", amount=1, choose=True))])
noncombat("shade_noncombat_02", "Shade Shadow Respite",
          [USE(E("energy", amount="max", target="any")), USE({"may": True, "op": "end_combat"})], school="shade")
drill("shade_drill_06", "Shade Effacing Drill", "shade", limit_per_deck=1,
      effects=[{"trigger": "on_success", "op": "discard_in_play", "who": "opponent", "card_type": "non_combat_card",
                "amount": 1, "choose": True, "remove": True, "when": {"attack_kind": "art"}}])

# --- Masteries ------------------------------------------------------------
# "In place of an attack": a use that takes the action. The card discarded decides the half.
add(id="shade_mastery_02", title="Shade Tithe Mastery", type="mastery", school="shade", limit_per_deck=1,
    once_per_combat=True, only={"when": {"hand_min": 1}},
    effects=[{"trigger": "use", "op": "discard_hand", "amount": 1, "random": False,
              "then": [WHEN(E("discard_hand", "opponent", amount=1, random=True), discard_top_school="shade"),
                       WHEN(E("discard_hand", "opponent", amount=1, random=False), discard_top_school_not="shade")]}])
add(id="shade_mastery_03", title="Shade Blight Mastery", type="mastery", school="shade", limit_per_deck=1,
    grant_attack_lines={"school": "shade",
                        "effects": [IFS({"may": True, "op": "discard_in_play", "who": "any", "card_type": "non_combat_card",
                                         "amount": 1, "choose": True})],
                        "otherwise": [IFS(E("discard_in_play", "any", card_type="drill", amount=1, choose=True))]})
# "During your Attacker Attacks phase", not in place of the attack, so the phase stays open.
add(id="shade_mastery_04", title="Shade Eclipse Mastery", type="mastery", school="shade", limit_per_deck=1,
    stop_focused_school="shade", free_action=True,
    only={"when": {"hand_school_min": {"school": "shade", "count": 1}}},
    effects=[{"trigger": "use", "op": "discard_hand", "amount": 1, "random": False, "filter": {"school": "shade"},
              "then": [ACC(1), VIG(6, "duelist")]}])
