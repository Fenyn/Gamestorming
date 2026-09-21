"""The Root expansion: 29 new school cards, filling the gaps the school had no card for.

    python tools/add_card.py decks/root_expansion

Ids and titles are approved. Every card stands in for one printed card; which one is recorded in
`docs/card_roster.csv` through the table in `tools/gen_roster.py`, and nowhere else. Cards are
listed here in the order they were approved, and referred to only by their own ids.

The same two readings as the Storm batch: a printed "if you declared a Tokui-Waza" rider is always
on and is written with no condition, and a printed tournament-format note is dropped. A printed
"Heroes only" becomes `alignment_only`, and a printed reference to a Majin is the `marked` tag.
"""
from cardlib import (add, strike, art, block, combat, noncombat, drill,
                     E, ACC, OPP_ACC, VIG, FLOAT, SEARCH, IFS, IFSTOP, USE, ENTER,
                     AFTER_EMPOWER, DISCARD_IN_PLAY)

# --- Drills ---------------------------------------------------------------
drill("root_windbreak_drill", "Root Windbreak Drill", "root", shield="strike")
drill("root_canopy_drill", "Root Canopy Drill", "root", shield="art")
# Reads your own top two and sends them all to one end. root_preparation_drill reads theirs, so
# the two stack rather than repeat.
drill("root_sightline_drill", "Root Sightline Drill", "root",
      effects=[ENTER(E("look_at", amount=2, rearrange=True, place="choose", **{"from": "top"}))])

# --- Non-Combats ----------------------------------------------------------
# Full Energy, then a drawn card of the school buys two cards back under the deck.
noncombat("root_deep_draught", "Root Deep Draught",
          [USE(VIG("max", "duelist")),
           USE(E("draw_check", school="root",
                 effects=[SEARCH(source="discard", amount=2, to="deck_bottom")]))],
          school="root", remove_after_use=True)
# Used out of hand in the window that opens on taking damage, never placed first.
noncombat("root_thorn_hedge", "Root Thorn Hedge", [E("discard_life", "opponent", amount=3)],
          school="root", use_at="after_damage")

# --- Strikes --------------------------------------------------------------
strike("root_carvers_reach", "Root Carver's Reach", "root", atk={}, alignment_only="vigil",
       effects=[IFS(E("capture_seal")), OPP_ACC(-2)], remove_after_use=True)
strike("root_timber_blow", "Root Timber Blow", "root", atk={"stages": 3})
strike("root_millstone", "Root Millstone", "root", atk={"printed_life": 6, "cost_stages": 3})
# The two oldest cards in the pile go back under the deck, and stay where they were put.
strike("root_rising_sap", "Root Rising Sap", "root", atk={},
       effects=[E("shuffle_discard", amount=2, no_shuffle=True, **{"from": "bottom"})])
strike("root_pruning_cut", "Root Pruning Cut", "root", atk={"life": 2},
       effects=[IFS(E("draw_discard", amount=1, **{"from": "top"})), OPP_ACC(-2)],
       remove_after_use=True)
# "Choose any cards in your discard pile and remove them from the game": no cap on the printed
# card, so the whole pile goes up as one choice and taking none is allowed.
strike("root_deadfall", "Root Deadfall", "root", atk={"focused": True, "stages": 3},
       effects=[IFS(E("remove_discard", amount="any"))])
# Stays on the table for two further uses, which the school has had no card for.
strike("root_briar_tangle", "Root Briar Tangle", "root", atk={"printed_stages": 3}, remain=2,
       remove_after_use=True)
strike("root_quickening", "Root Quickening", "root",
       atk={"stages": 5, "variants": [{"when": {"defender_tag": "marked"}, "focused": True}]},
       effects=[VIG(4)])
strike("root_snare", "Root Snare", "root", atk={"stages": 3},
       effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=1, remove=True, choose=True))])
# "Discard one of your opponent's Non-Combat, Ally or Grounds in play": one card, one choice over
# all three. The Grounds is shared rather than held in a player's in-play zone, so the card type
# names it and only the opponent's own Grounds is on the list.
strike("root_splitting_wedge", "Root Splitting Wedge", "root", atk={}, endurance=3, empower=4,
       effects=[AFTER_EMPOWER(DISCARD_IN_PLAY("non_combat_ally_or_grounds", amount=1, choose=True)),
                AFTER_EMPOWER(OPP_ACC(-2))])
strike("root_grove_fury", "Root Grove Fury", "root", atk={"printed_stages": 6}, effects=[ACC(1)],
       remove_after_use=True)
strike("root_bindweed", "Root Bindweed", "root", atk={"stages": 3}, endurance=2,
       effects=[E("shuffle_discard", amount=2)], remove_after_use=True)
block("root_sapwood_guard", "Root Sapwood Guard", "strike", "strike", "root", effects=[VIG(3)])
block("root_taproot_brace", "Root Taproot Brace", "strike", "strike", "root",
      effects=[VIG("max", "duelist"), OPP_ACC(-1)])

# --- Combat cards ---------------------------------------------------------
block("root_barred_path", "Root Barred Path", "any", "combat", "root", remove_after_use=True)
combat("root_closing_bark", "Root Closing Bark", [E("shuffle_discard", amount=1)], school="root",
       endurance=10, remove_after_use=True)
# Reaches into their deck: the looker sees four, one goes out of the game, the rest go back in the
# looker's order. A Seal is never a legal pick.
combat("root_trail_cut", "Root Trail Cut",
       [E("look_at", whose="opponent", amount=4, pick={}, to="removed", must=True, rearrange=True,
          **{"from": "top"})],
       school="root", endurance=4)
combat("root_kin_clearing", "Root Kin Clearing", [DISCARD_IN_PLAY("non_combat", all=True)],
       school="root", only={"allies_min": 1}, remove_after_use=True, limit_per_deck=1)

# --- Arts -----------------------------------------------------------------
art("root_first_frost", "Root First Frost", "root", atk={}, effects=[OPP_ACC(-1)])
art("root_auger_splinter", "Root Auger Splinter", "root", atk={"printed_life": 5, "focused": True},
    effects=[OPP_ACC(-2)])
art("root_flung_stone", "Root Flung Stone", "root", atk={"printed_life": 5},
    effects=[IFS(DISCARD_IN_PLAY("non_combat", amount=1, choose=True))], remove_after_use=True)
# Pays whether it lands or not: growth back under the deck on a hit, growth lost on a stop.
art("root_scattered_seed", "Root Scattered Seed", "root", atk={"printed_life": 6},
    effects=[IFS(E("shuffle_discard", amount=3, no_shuffle=True, **{"from": "bottom"})),
             IFSTOP(E("remove_discard", amount=2, **{"from": "bottom"}))])
art("root_old_growth", "Root Old Growth", "root", atk={"printed_life": 10, "cost_stages": 4},
    effects=[IFS(E("discard_life", amount=3, remove=True)),
             IFSTOP(E("discard_hand", all=True, random=False))],
    remove_after_use=True)
art("root_culling_frost", "Root Culling Frost", "root", atk={}, endurance=2,
    effects=[IFS(DISCARD_IN_PLAY("ally", amount=1, choose=True)), OPP_ACC(-1)])
