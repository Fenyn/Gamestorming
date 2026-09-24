"""The second Root expansion: 12 new school cards and 3 Masteries, bringing the school to 50.

    python tools/add_card.py decks/root_expansion2

Titles are the ones locked in `docs/expansion_batch2_review.md`; sources are in `tools/gen_roster.py`
(NEW_SOURCES) and `tools/source_candidates.tsv`. Every printed clause is built as written, except
that a "declared a Tokui-Waza" rider is always on and "Sensei Deck." notes are dropped. "Piccolo" is
Osric Thornwald; "Nail" has no one in the cast yet, so those gates name Osric alone. "Namekian
Heritage only" is the Verdant gate, and Root Masteries need a Verdant duelist.
"""
from cardlib import (add, strike, art, block, drill, noncombat, combat,
                     E, ACC, VIG, FLOAT, SEARCH, IFS, USE, DISCARD_IN_PLAY, AFTER_EMPOWER, VERDANT)


# --- Recursion ------------------------------------------------------------
strike("root_strike_17", "Root Creeping Vine", "root", atk={"stages": 2}, endurance=4,
       effects=[IFS(SEARCH(source="discard", to="deck_shuffle", must=True))])
art("root_art_12", "Root Hurled Thorns", "root", atk={"printed_life": 5, "cost_stages": 1},
    effects=[IFS(E("shuffle_discard", amount=1))])
art("root_art_11", "Root Seed Burst", "root", atk={"focused": True, "printed_life": 5},
    effects=[IFS(E("sift_discard", amount=4, remove=2)), IFS(E("exile_source"))])
combat("root_combat_08", "Root New Shoots",
       [E("choose_one", choices=[
           {"label": "Top 3", "effects": [E("shuffle_discard", amount=3)]},
           {"label": "Bottom 3", "effects": [E("shuffle_discard", amount=3, **{"from": "bottom"})]}])],
       school="root", only=VERDANT)

# --- Seals ----------------------------------------------------------------
combat("root_combat_07", "Root Swallowing Earth",
       [FLOAT("modifier", scope="own", kind="strike", stages=2),
        E("discard_in_play", "any", card_type="seal", amount=1, choose=True, to="deck_bottom")],
       school="root")

# --- Table defense --------------------------------------------------------
strike("root_strike_19", "Root Oakheart Guard", "root", atk={}, defense={"stops": "strike"}, endurance=3, only=VERDANT)
drill("root_drill_06", "Root Frost Watch Drill", "root", surge_bonus=2,
      defense={"stops": "art", "cost_hand": 1, "cost_hand_filter": {"attack_kind": "art"}})

# --- Board strip ----------------------------------------------------------
strike("root_strike_18", "Root Stone Cleaver", "root", atk={"focused": True, "stages": 3}, endurance=4, empower=3,
       effects=[AFTER_EMPOWER(FLOAT("no_shields", who="opponent")),
                AFTER_EMPOWER(DISCARD_IN_PLAY("ally", amount=3, up_to=True, choose=True))])
noncombat("root_noncombat_05", "Root Strangling Vine", [USE(E("silence_drill", "opponent"))],
          school="root", only={"character": "Osric Thornwald"}, limit_per_deck=8, remove_after_use=True)

# --- Costly Arts ----------------------------------------------------------
drill("root_drill_05", "Root Sap Flow Drill", "root", drill_lock_exempt=True, card_cost_less=1,
      modifiers=[{"scope": "own", "kind": "any", "stages": 2},
                 {"scope": "cost", "kind": "any", "stages": -1, "min": 1}])

# --- Root attacks ---------------------------------------------------------
noncombat("root_noncombat_03", "Root Fallen Oak",
          [USE({"op": "discard_in_play", "card_type": "ally", "amount": 1, "choose": True, "remove": True,
                "then": [ACC(2)]})],
          school="root", only={"character": "Osric Thornwald", "allies_min": 1}, remove_after_use=True)
noncombat("root_noncombat_04", "Root Grove Kin",
          [USE(E("energy", amount="max", target="allies")), USE(FLOAT("ally_control_any_stage")),
           USE(E("discard_life", amount="per_ally"))],
          school="root")

# --- Masteries ------------------------------------------------------------
add(id="root_mastery_02", title="Root Compost Mastery", type="mastery", school="root",
    duelist_bloodline="verdant", limit_per_deck=1,
    effects=[{"trigger": "entering_combat", "op": "shuffle_discard", "amount": 1,
              "if": {"check": "school", "school": "root"}, "effects": [E("draw", amount=1)]}])
add(id="root_mastery_03", title="Root Deeproot Mastery", type="mastery", school="root",
    duelist_bloodline="verdant", limit_per_deck=1,
    effects=[{"trigger": "entering_combat", "op": "draw_check", "school": "root", "from": "bottom",
              "effects": [{"may": True, "op": "show_checked", "then": [E("draw", amount=1, **{"from": "bottom"})]}]}])
add(id="root_mastery_04", title="Root Sacred Grove Mastery", type="mastery", school="root",
    duelist_bloodline="verdant", limit_per_deck=1, discard_only_school="root",
    grant_attack_lines={"school": "root",
                        "effects": [IFS(E("recover", amount=2, **{"from": "bottom"})), IFS(VIG(3))]})
