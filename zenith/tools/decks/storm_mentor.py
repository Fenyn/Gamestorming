"""New cards for the Storm Sensei list (`data/decks/storm_mentor.json`), built from the Orange TS
tournament sheet. See docs/tournament_import.md for the sheet, the card-by-card read and the nine
fan prints swapped out for Score cards.

    python tools/add_card.py tools/decks/storm_mentor.py

Titles and the new characters are drafts: the duelist, both new Allies and the Relic carry
PLACEHOLDER until the lore pass names them. Mechanics follow the printed text exactly; the
approximations are the Might ladders, which are designed on the compact scale the way every shipped
ladder is (designs/zenith.md, Strike Table) and keep the printed Surge.
"""
from cardlib import (add, art, block, noncombat, drill, duelist, aspect, personality, generic_id,
                     E, OPP, OPP_ACC, VIG, FLOAT, SEARCH, IFS, IFSTOP, USE, DISCARD_IN_PLAY,
                     KAPPA, MOURNE)

DUELIST = "PLACEHOLDER Duelist"
COMPANION = "Aldo Voss"
BRUTE = "Sandmaw"
TAVIN = "Tavin Vale"

# --- The duelist ----------------------------------------------------------
# Four printed levels from four sets. Surge is printed; Might follows the four-Aspect shape the
# Lord Mourne line uses, tops 20 / 26 / 32 / 38.
duelist(DUELIST, [
    # "When entering Combat, you may remove 3 cards in your discard pile from the game to search
    # your discard pile for a card that can perform an energy attack with a Base Damage of less
    # than 6 life cards and place it into your hand."
    aspect(1, 2, 20, 1, power={"effects": [{
        "trigger": "entering_combat", "may": True, "when": {"discard_min": 3},
        "op": "remove_discard", "amount": 3, "choose": True,
        "then": [SEARCH(source="discard", to="hand", attack_kind="art", max_base_life=5)]}]}),
    # "Focused energy attack doing 5 life cards of damage. If successful, discard one of your
    # opponent's Allies or Drills in play."
    aspect(2, 3, 26, 1, power={"attack": {"kind": "art", "focused": True, "printed_life": 5},
                               "effects": [IFS(DISCARD_IN_PLAY("drill_or_ally", amount=1, choose=True))]}),
    # "Physical attack. If successful, lower your opponent's anger to 0."
    aspect(3, 3, 32, 1, power={"attack": {"kind": "strike"},
                               "effects": [IFS(OPP("set_fervor", amount=0))]}),
    # "Physical attack. If successful, also capture an opponent's Dragon Ball."
    aspect(4, 3, 38, 1, power={"attack": {"kind": "strike"}, "effects": [IFS(E("capture_seal"))]}),
], ["Scavenger", "Pinning", "Deflating", "Seal-Taker"])

# --- The Relic ------------------------------------------------------------
# The Sensei: a 9-card Reserve and a standing line both ways. "All of your attacks do +1 life cards
# of damage. All of your opponent's attacks do -1 life cards of damage."
add(id=generic_id("relic", {"type": "relic", "reserve_size": 9}), title="The Champion's Laurel",
    type="relic", school="", reserve_size=9, limit_per_deck=1,
    modifiers=[{"scope": "own", "kind": "any", "life": 1}, {"scope": "against", "kind": "any", "life": 1}])

# --- Allies ---------------------------------------------------------------
# Tavin Vale's earlier printing (the source's Buu Saga level 1). "Energy attack doing 5 life cards
# of damage. If successful, for the remainder of Combat you may discard the top card of your Life
# Deck instead of paying costs for any energy attacks Kid Trunks performs."
personality(TAVIN, 1, 2, 16, 1, variant="the Fledgling", alignment_only="vigil", limit_per_deck=1,
            bloodline="draconic",
            power={"attack": {"kind": "art", "printed_life": 5},
                   "effects": [{"trigger": "if_successful", "op": "float", "what": "life_for_art_costs",
                                "duration": "combat", "this_personality": True}]})
# "Energy attack. If successful you may search your Life Deck for any card and discard it."
personality(COMPANION, 1, 2, 14, 1, alignment_only="vigil", limit_per_deck=1,
            power={"attack": {"kind": "art"},
                   "effects": [IFS({"may": True, **SEARCH(to="discard")})]})
# A fighter of neither side. "Energy attack doing 7 life cards of damage. If stopped, discard the top
# 3 cards of your Life Deck."
personality(BRUTE, 1, 1, 20, 1, limit_per_deck=1,
            power={"attack": {"kind": "art", "printed_life": 7},
                   "effects": [IFSTOP(E("discard_life", amount=3))]})

# --- Storm cards ----------------------------------------------------------
# "Focused energy attack doing 2 life cards of damage. Costs 1 power stage to perform. Remove from
# the game after use. Empower 4. This attack is no longer focused. This attack stays on the table to
# be used 2 more times this Combat without using its Empower."
art(generic_id("storm_art", {"title": "Storm Fivefold Spark"}), "Storm Fivefold Spark", "storm",
    atk={"focused": True, "printed_life": 2, "cost_stages": 1,
         "variants": [{"on_empower": True, "focused": False}]},
    empower=4, empower_remain=2, remove_after_use=True)
# "Endurance 2. Stops an energy attack. Lower your opponent's anger 2 levels."
block(generic_id("storm_art", {"title": "Storm Caught Current"}), "Storm Caught Current", "art", "art", "storm",
      endurance=2, effects=[OPP_ACC(-2)])
# "At the beginning of every turn, discard 1 opponent's non-combat-non-dragon ball card in play.
# Limit 1 per deck."
drill(generic_id("storm_drill", {"title": "Storm Razing Drill"}), "Storm Razing Drill", "storm", limit_per_deck=1,
      effects=[{"trigger": "turn_start", "each_turn": True,
                **DISCARD_IN_PLAY("non_combat_or_drill", amount=1, choose=True)}])
# "All successful physical attacks performed against you do a maximum of 3 power stages of damage.
# Limit 1 per deck." Wounds are untouched (rulings document, #147).
drill(generic_id("storm_drill", {"title": "Storm Braking Drill"}), "Storm Braking Drill", "storm", limit_per_deck=1,
      modifiers=[{"scope": "against", "kind": "strike", "cap_stages": 3}])

# --- Named and Freestyle cards --------------------------------------------
# "Focused energy attack. Costs 3 power stages to perform. If successful, search your Life Deck for
# any Location and place it into play."
art(generic_id("signature_art", {"title": "Emrys' Braced Beam"}), "Emrys' Braced Beam",
    atk={"focused": True, "cost_stages": 3}, character=KAPPA,
    effects=[IFS(SEARCH(card_type="grounds", to="play"))])
# "Focused Energy Attack doing 5 life cards of damage. If successful, this personality does not
# have to pay any costs for energy attacks for the remainder of combat."
art(generic_id("signature_art", {"title": "Mourne's Unpaid Bolt"}), "Mourne's Unpaid Bolt",
    atk={"focused": True, "printed_life": 5}, character=MOURNE,
    effects=[{"trigger": "if_successful", "op": "float", "what": "modifier", "duration": "combat",
              "this_personality": True, "params": {"scope": "cost", "kind": "art", "set": 0}}])
# "Your energy attacks do an additional +X life cards of damage, where X is the PUR of the
# personality performing the attack. Limit 1 per deck."
drill(generic_id("signature_drill", {"title": "PLACEHOLDER's Surging Drill"}), "PLACEHOLDER's Surging Drill",
      limit_per_deck=1, modifiers=[{"scope": "own", "kind": "art", "life_per_performer_surge": True}])
# "Stops a physical or energy attack. Remove from the game after use."
block(generic_id("signature_art", {"title": "PLACEHOLDER's Skillful Guard"}), "PLACEHOLDER's Skillful Guard",
      "any", "art", character=DUELIST, remove_after_use=True)
# "Raise any personality in play to its highest power stage. The next energy attack that
# personality performs this Combat costs 0 power stages to perform."
noncombat(generic_id("freestyle_noncombat", {"title": "Centering"}), "Centering",
          [USE(E("energy", target="any", amount="max", next_art_free=True))])
# "Heroes only. Energy attack doing 6 life cards of damage. If performed against a villain, this
# attack is focused, gain 2 power stages, and for the remainder of Combat your opponent cannot have
# Allies take control of Combat."
art(generic_id("freestyle_art", {"title": "Vigilant Effort"}), "Vigilant Effort",
    atk={"printed_life": 6, "variants": [{"when": {"defender_alignment": "pact"}, "focused": True,
                                          "effects": [VIG(2), FLOAT("no_ally_takeover", who="opponent")]}]},
    alignment_only="vigil")
