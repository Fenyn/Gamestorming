"""Cards the CRD bans, built as adventure bombs: legal only in adventure decks, one copy each.

    python tools/add_card.py decks/banned_bombs

Every printed clause is built as written. "League only" and similar format notes are dropped.
"""
from cardlib import noncombat, combat, E, USE, FLOAT

noncombat("freestyle_noncombat_19", "Undone Before It Lands", counter="any", counter_removes=True,
          banned=True, limit_per_deck=1)
noncombat("freestyle_noncombat_20", "Tempers Leveled",
          [USE(E("set_fervor", amount=3)), USE(E("set_fervor", "opponent", amount=3))],
          banned=True, limit_per_deck=1)
combat("freestyle_combat_21", "Nothing Goes to Waste",
       [FLOAT("on_hand_play", effects=[{"may": True, "op": "recover", "amount": 2, "from": "bottom",
                                         "when": {"discard_min": 2},
                                         "then": [E("energy", amount=2, target="duelist")]}])],
       remove_after_use=True, banned=True, limit_per_deck=1)
