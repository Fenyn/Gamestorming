"""New cards for Mercenary Lord (`data/decks/mercenary_lord.json`), the earlier, unmarked Gideon
Mourne, built from a Score-era Retro tournament list (a Freestyle Vegeta build). See
docs/tournament_import.md, "Freestyle Vegeta", for the list, the card-by-card read and the two
promos read off seller scans.

    python tools/add_card.py tools/decks/mercenary_lord.py

Names approved 2026-09-30. Mechanics follow the printed text; the Might ladder is designed on the
compact scale like every shipped ladder and keeps the printed Surge. The one Tokui-Waza clause
(Humbling Blow) reads the opponent's declared style, which is the school their deck declares.
"""
from cardlib import (add, art, strike, block, combat, noncombat, drill, duelist, aspect, generic_id,
                     E, OPP, IFS, USE, ENTER, WHEN, ACC, OPP_ACC, FLOAT, SEARCH, MOURNE, EPSILON)

# --- The duelist ----------------------------------------------------------
# Five printed levels from four sets. Surge is printed; Might tops 14 / 20 / 26 / 32 / 38, a step
# under the Marked line at every Aspect it shares.
duelist(MOURNE, [
    # "Search your discard pile for a Vegeta named card and shuffle it back into your Life Deck."
    aspect(1, 1, 14, 1, power={"effects": [SEARCH(source="discard", to="deck_shuffle", character=MOURNE)]}),
    # "Your opponent cannot play and use Combat cards. All of your attacks do +2 life cards of damage."
    aspect(2, 3, 20, 1, constant={"forbid_opponent": ["combat_cards"],
                                  "modifiers": [{"scope": "own", "kind": "any", "life": 2}]}),
    # "When entering Combat, look at your opponent's hand, then choose and discard 1 Non-Dragon Ball card."
    aspect(3, 3, 26, 1, power={"effects": [ENTER(OPP("discard_hand", amount=1, random=False, chooser="owner",
                                                     reveal=True, filter="non_seal"))]}),
    # "Defense Shield: When defending in Combat, stop the first unstopped attack performed against
    # you. When entering Combat, draw a card."
    aspect(4, 4, 32, 1, shield="any", power={"effects": [ENTER(E("draw", amount=1))]}),
    # "Physical attack doing +9 power stages of damage."
    aspect(5, 5, 38, 1, power={"attack": {"kind": "strike", "stages": 9}}),
], ["The Betrayer", "Sellsword", "Silver Tongue", "Free Captain", "Mercenary Lord"],
    variant="Mercenary", bloodline="draconic")

# --- Mourne-named cards ---------------------------------------------------
# Vegeta's Energy Thrust: "Energy attack. If successful, shuffle all Vegeta Named cards in your
# discard pile into your Life Deck. Remove from the game after use."
art(generic_id("signature_art", {"title": "Mourne Calls In Debts"}), "Mourne Calls In Debts",
    character=MOURNE, remove_after_use=True,
    effects=[IFS(E("shuffle_discard", all=True, character=MOURNE))])
# Vegeta's Gutter Wallop: "Physical attack doing +4 power stages of damage. Look at your opponent's
# hand. If successful and used by Vegeta or Majin Vegeta, raise your anger 3 levels."
strike(generic_id("signature_strike", {"title": "Mourne's Low Blow"}), "Mourne's Low Blow",
       atk={"stages": 4}, character=MOURNE,
       effects=[OPP("reveal_hand", look=True), IFS(WHEN(ACC(3), character=MOURNE))])
# Vegeta's Energy Detonation: "Energy attack doing 6 life cards of damage. If used by Vegeta, then
# for the remainder of Combat the bottom 15 cards of your discard pile are Vegeta Named cards while
# in your discard pile."
art(generic_id("signature_art", {"title": "Mourne's Ruinous Bolt"}), "Mourne's Ruinous Bolt",
    atk={"printed_life": 6}, character=MOURNE,
    effects=[WHEN(FLOAT("discard_named", character=MOURNE, count=15), character=MOURNE)])
# Vegeta is Lurking: "Vegeta only. Search your Life Deck for 3 Vegeta named cards and place them
# in your hand. Limit 1 per deck."
combat(generic_id("signature_combat", {"title": "Mourne Bides His Time"}), "Mourne Bides His Time",
       [SEARCH(character=MOURNE, amount=3, to="hand")],
       character=MOURNE, only={"character": MOURNE}, limit_per_deck=1)
# Vegeta's Lunge: "Select, unseen, a card from your opponent's hand and discard it."
combat(generic_id("signature_combat", {"title": "Mourne's Grasping Lunge"}), "Mourne's Grasping Lunge",
       [OPP("discard_hand", amount=1)], character=MOURNE)
# Vegeta's Ill Temper: "Vegeta only. Choose 3 Vegeta Named cards that are removed from the game and
# shuffle them into your Life Deck."
noncombat(generic_id("signature_noncombat", {"title": "Mourne's Grudge"}), "Mourne's Grudge",
          [USE(E("return_removed", character=MOURNE, choose=True, max=3))],
          character=MOURNE, only={"character": MOURNE})
# Vegeta's Elbow Slam: "Sensei Deck. Endurance 3. Physical attack. If you declared a Freestyle
# Tokui-Waza and your opponent declared a Red Tokui-Waza, lower your opponent's Main Personality 1
# personality level, and he cannot raise his anger for the remainder of the turn."
strike(generic_id("signature_strike", {"title": "Mourne's Humbling Blow"}), "Mourne's Humbling Blow",
       endurance=3, reserve_only=True, character=MOURNE,
       effects=[WHEN(OPP("lose_aspect"), opponent_style="pyre"),
                WHEN(FLOAT("no_fervor_gain", "opponent", duration="turn"), opponent_style="pyre")])

# --- Other named and Freestyle cards --------------------------------------
# Broly's Evil Drill: "Villains only. When entering Combat as the active player, you may search your
# Life Deck for a 'Villains only' card and place it into your hand. If Broly is your Main
# Personality, you may also use this Drill when entering Combat as the opposing player. You can only
# have 1 'Broly's Evil Drill' in play at a time."
drill(generic_id("signature_drill", {"title": "Quarr's Grim Drill"}), "Quarr's Grim Drill",
      character=EPSILON, alignment_only="pact", unique_in_play=True,
      effects=[ENTER({"may": True, **SEARCH(alignment_only="pact", to="hand")}, role="attacker"),
               WHEN(ENTER({"may": True, **SEARCH(alignment_only="pact", to="hand")}, role="defender"),
                    duelist_character=EPSILON)])
# Master Roshi's Gawking Drill: "All of your attacks do +1 power stages of damage. When you perform
# an attack, remove a card in your opponent's discard pile from the game." Roshi has no mirror.
drill(generic_id("freestyle_drill", {"title": "PLACEHOLDER's Leering Drill"}), "PLACEHOLDER's Leering Drill",
      modifiers=[{"scope": "own", "kind": "any", "stages": 1}],
      effects=[{"trigger": "on_attack", **OPP("remove_discard", amount=1)}])
# Energy Ricochet: "Endurance 3. Stops an energy attack. Raise your anger 1 level. Lower your
# opponent's anger 1 level. You may remove 2 cards in your Sensei Deck from the game to shuffle
# this card back into your Life Deck after use."
block(generic_id("freestyle_art", {"title": "Rebounding Ward"}), "Rebounding Ward", "art", "art",
      endurance=3,
      effects=[ACC(1), OPP_ACC(-1),
               {"may": True, "op": "remove_reserve", "amount": 2, "when": {"reserve_min": 2},
                "then": [E("shuffle_source")]}])
# Narrow Escape: "Stops a physical or energy attack. If your Main Personality is at level 2 or above
# and you have a 'Freestyle Mastery' in play, stops all physical attacks and energy attacks your
# opponent performs for the remainder of Combat. Remove from the game after use. Limit 2 per deck."
block(generic_id("freestyle_combat", {"title": "Near Miss"}), "Near Miss", "any", "combat",
      remove_after_use=True, limit_per_deck=2,
      effects=[WHEN(E("stop_all", kind="any"), aspect_min=2, own_mastery_school="")])
# Releasing the Sword: "Use when entering Combat. Reveal the top 7 cards of your Life Deck. Place in
# play any Non-Combat cards revealed and shuffle the rest back into your Life Deck." A Drill and a
# Seal are Non-Combat cards in the source. The rulings document (IR20) adds "Limit 1 per deck.
# Remove from the game after use."
noncombat(generic_id("freestyle_noncombat", {"title": "Raid the Armory"}), "Raid the Armory",
          [ENTER({"may": True, **E("look_at", amount=7, pick={"card_type": "non_combat_any"}, to="play",
                                   all_matches=True, shuffle_after=True, **{"from": "top"}),
                  "then": [E("exile_source")]})], limit_per_deck=1)
# Krillin's Power Tap: "Use when needed, You may use the power of any drill in play, during Combat.
# If 'Black Shadow Drill' is in play, your opponent places all of his allies in play at the bottom of
# his life deck." The second sentence names a card with no parallel in the set, so it can never
# apply and is not carried.
noncombat(generic_id("signature_noncombat", {"title": "Voss' Borrowed Rite"}), "Voss' Borrowed Rite",
          character="Aldo Voss", borrows_drill_powers=True)
