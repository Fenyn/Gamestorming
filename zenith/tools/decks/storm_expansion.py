"""The Storm expansion: 7 new school cards and 2 Masteries, bringing the school to 50.

    python tools/add_card.py decks/storm_expansion

Titles are the ones locked in `docs/expansion_batch2_review.md`; sources are in `tools/gen_roster.py`
(NEW_SOURCES) and `tools/source_candidates.tsv`. Every printed clause is built as written, except
that a "declared a Tokui-Waza" rider is always on.
"""
from cardlib import (add, strike, art, drill, E, IFS, FLOAT, SEARCH, AFTER_EMPOWER)


# --- Drills ---------------------------------------------------------------
drill("storm_drill_05", "Storm Backflash Drill", "storm",
      effects=[{"trigger": "on_damaged", "may": True, "op": "draw_discard", "amount": 1, "from": "bottom",
                "when": {"attack_kind": "strike", "discard_min": 1}}])
drill("storm_drill_06", "Storm Seeking Spark Drill", "storm", once_per_combat=True,
      effects=[{"trigger": "on_success", "op": "mark_used", "when": {"attack_kind": "art"}},
               {"trigger": "on_success", "op": "search", "whose": "opponent", "to": "discard",
                "when": {"attack_kind": "art"}}])
drill("storm_drill_07", "Storm Grounding Drill", "storm", limit_per_deck=2,
      effects=[{"trigger": "on_stop", "may": True, "op": "exile_source",
                "then": [E("stop_all", kind="stopped")]}])
drill("storm_drill_08", "Storm Stormwall Drill", "storm", surge_bonus=1, shields_stop_focused=True)

# --- Attacks --------------------------------------------------------------
strike("storm_strike_13", "Storm Gathering Front", "storm", atk={"stages": 3}, empower=2,
       effects=[AFTER_EMPOWER(E("look_at", amount=4, pick={"card_type": "drill"}, to="play",
                                rearrange=True, **{"from": "top"}))])
strike("storm_strike_14", "Storm Lightning Rod", "storm", atk={},
       effects=[FLOAT("at_combat_end", effects=[SEARCH(card_type="drill", school_in=["", "storm"], to="play")])])
art("storm_art_24", "Storm Steady Current", "storm", atk={"printed_life": 5}, endurance=1,
    effects=[FLOAT("keep_drills")])

# --- Masteries ------------------------------------------------------------
add(id="storm_mastery_03", title="Storm Gale Mastery", type="mastery", school="storm", limit_per_deck=1,
    modifiers=[{"scope": "own", "kind": "strike", "stages": 2}],
    effects=[{"trigger": "on_success", "op": "float", "what": "modifier", "duration": "combat",
              "exclude_source": True, "params": {"scope": "own", "kind": "strike", "life": 1},
              "when": {"source_school": "storm", "attack_kind": "strike"}}])
add(id="storm_mastery_04", title="Storm Conductor Mastery", type="mastery", school="storm", limit_per_deck=1,
    once_per_combat=True, free_action=True, only={"when": {"drill_school_in_play": "storm"}},
    effects=[{"trigger": "use", "op": "discard_in_play", "who": "self", "card_type": "drill", "school": "storm",
              "amount": 1, "choose": True,
              "then": [E("mark_used"), SEARCH(card_type="drill", amount=2, different=True, to="play")]},
             {"trigger": "rejuvenation", "may": True, "op": "recover", "card_type": "drill",
              "when": {"discard_has_type": "drill"}}])
