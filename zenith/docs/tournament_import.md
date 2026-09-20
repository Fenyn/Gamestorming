# Tournament sheet import

Progress on the eight proxy sheets in `docs/NewZ Tournament Ready/`. Started 2026-09-19. Like
`cast_backlog.md`, this file names source cards and characters so the sheets can be found; the
rule against source names still holds for everything in `data/`, `engine/` and the client.

## What these sheets are

Screenshots of a proxy generator, one card per embedded image, same as `docs/NewZ Starters/`.
The filename prefix names the Mastery printing the list runs: **TS** Trunks Saga, **CS** Cell
Saga, **MBS** Majin Buu Saga. Two printings of one school's Mastery need two card ids, the way
`pyre_mastery` and `pyre_ember_mastery` already split.

**These lists carry fan-made cards**, which the starter sheets did not. Cards with an `NZ` set
code and a "Not for Profit" footer are fan prints and fail our printed-Score-cards-only rule.
Codes seen that still need checking against `tools/source_cards.tsv`: `SZ`, `GK`, `GB`, `M`,
`Preview`. `IR` is Irwin, a real Score promo set. Verify every card's set before building it.

## Status

| Sheet | Slots / distinct | Duelist | Status |
|---|---|---|---|
| Red TS Majin Buu | 93 / 44 | Bram Ashmark, `duelist_alpha` | read, see below |
| Saiyan CS Broly | 98 / 50 | Halden Quarr, `duelist_epsilon` | not started |
| Namekian CS Piccolo | 99 / 54 | Osric Thornwald, `duelist_eta` | not started |
| Freestyle MBS Trunks Sword | 98 / 57 | Caedan Vale, `duelist_zeta` | not started |
| Blue MBS Goku | 98 / 55 | Sir Edric Rooke, `duelist_iota` | built, `tide_deepwater` |
| Black TS Majin Vegeta | 98 / 49 | new, Shade | not started |
| Orange TS Yamcha | 94 / 58 | new, Storm | not started |
| Blue CS Roshi Speedball | 54 / 46 | new, Tide | not started |

Slots counts every printed copy, distinct counts unique card faces. The first five sheets reuse a
duelist we already ship, so they are new lists for an existing character rather than new cast.

## Reading a sheet

`pypdf` gives one image per card slot. Every page starts with a constant block of images, the
generator's preview of whichever page it was displaying, and that block is **not always 9 images**
here. Find it as the longest run of leading positions that are byte-identical across every page,
then take the rest of each page as real slots. A repeated hash inside the real slots is the copy
count and must not be deduplicated away.

Measured prefixes: Vegeta 8, Goku 8, Trunks 9, Piccolo 9, Yamcha 4, Buu 9, Broly 8.

**Blue CS Roshi Speedball is a different file**: 3 MB rather than 230-510 MB, 7 pages, no constant
prefix, 7-8 images a page. Re-derive its structure before extracting.

**The cards between the personality ladder and the Sensei are the Sensei Deck, not the Life Deck.**
A sheet runs personalities, then the Sensei Deck, then the Sensei, then the Mastery, then the Life
Deck. Those cards belong in the deck's `reserve`, and several of them print "Sensei Deck Only" on
the card itself. The number in the Sensei's corner box is the Sensei Deck size: West Kai 7, North
Kai 13. Both sheets read so far come out at exactly that number once You're Invited is set aside,
which is right, because You're Invited leaves the Sensei Deck into play before the first turn and
so takes no slot. `DeckValidator` now counts the Reserve the same way and skips any `start_in_play`
card.

Triage trick: crop the top-right corner of every distinct card and tile the crops. The set code and
number are legible, so one image says which cards are fan prints without reading eleven contact
sheets. Read the cards themselves three to a row at 760x1045, resized to 1800 px wide.

## Red TS Majin Buu, read 2026-09-19

44 distinct faces, 93 copies: a five-level Majin Buu (Buu Saga 199 and 200, the HT2 prints, then
Fusion Saga 57 "Piccolo Absorbed", Buu Saga 114 and 151), Red Style Mastery 144 (the Trunks Saga
printing we already ship as `pyre_ember_mastery`), West Kai Sensei 156, You're Invited GK11, and
the rest life cards. Card 200 is split across two images in the PDF, so 44 faces are 43 cards.

31 of the 44 are cards we already ship. Twelve are new, and **three of those twelve are fan
prints**: Red Critical Blow NZ14 x3, Red Energy Hold NZ35 x3, Red Negation NZ70 x1. Seven copies
of 93.

The nine real new cards: Kami Fades (Cell Saga 113), West Kai Sensei (156), Red Sword Cleave (Buu
Saga 77), Gohan's Heroic Uppercut (Redemption CGR4), Majin Buu's Energy Spray (Fusion Saga 107),
Red Energy Defensive Stance (27), Red King Cold Observation (143), Dimension Scream (6), and the
third personality level.

Three things it needs that we do not have: a fourth Relic for West Kai Sensei, the `marked` tag
that `world.md` describes but no card carries yet ("Majin only" gates Energy Spray), and a
character for Kami Fades under the attribution rule in `cast_backlog.md`.

**Sensei Deck, 7 cards:** Kami Fades x3 (`the_watch_goes_dark`), HUH??? (`defacement`), Gohan's
Kick x3 (`no_quarter`), plus You're Invited (`open_challenge`) free. These were read as Life Deck
cards on the first pass and have been moved to `reserve`, which took the deck from 90 cards to 84.

**You're Invited is verified.** It is GK11, a Score World Championships card, ©2003 Score. The
source audit had `open_challenge` down as the one card it could not source, because the card is
missing from the LackeyCCG plugin database.

## Blue MBS Goku, built 2026-09-20 as `tide_deepwater`, "Crushing Depths"

55 distinct faces, 98 copies, and **no new personality**: the sheet's tiers 1 to 4 are the same
printed cards `duelist_iota` already uses, and its tier 5 is a fan print, so the real Cell Saga
tier 5 we ship slots in. Sir Edric Rooke fields Tide here and Pyre in `pyre_ascent`, which is the
theming rule working as intended.

**Eleven fan prints, 25 copies of 98**, far more than the Red sheet's three. Swapped for Score
cards of the same job: Blue Mist Kick to Blue Fist Strike, Dismal Future to Blue Off-Balancing
Opponent, Blue Energy Throw to Blue Energy Outburst, Frieza's Deception to Blue Softening Stance,
Blue Colossal Throw to Blue Flight, Blue One-Inch Punch to Blue Smirk, Heroic Deeds to Blue Glare
Attack, Blue Overpowering Aura to Blue Sidestep, Blue Negation to Trunks' Energy Sphere. The fan
tier 5 and God Ki Ritual went together, the ritual existing only to reach that level; Transformation
(`reckless_ascent`) took the ritual's slot, since it also advances the duelist and closes the
Ascension win.

**Sensei Deck, 13 cards:** Blue Mist Kick x3 (fan, swapped to Blue Fist Strike =
`tide_bearing_down`), Energy Lob (`lobbed_bolt`), Cell's Presence x2 (`dismissal`), Dismal Future
x3 (fan, swapped to Blue Off-Balancing Opponent Drill = `tide_heavy_water`), Blue Energy Throw x2
(fan, swapped to Blue Energy Outburst = `tide_full_weight`), Frieza's Deception (fan, swapped to
Blue Softening Stance = `tide_held_under`), HUH??? (`defacement`), plus You're Invited free. Four
of the eleven fan prints were Sensei Deck cards, so their replacements sit in `reserve` too. Moving
them out took the deck from 96 cards to 84, and `old_trick`, which fetches an attack out of the
Reserve, now has something to fetch.

**Tide has a second Mastery**, `tide_fathom_mastery`, from the Buu Saga printing: +2 wounds on
Tide Strikes, and instead of blocking you may remove Tide cards from your discard pile to prevent
2 wounds each. The existing `tide_mastery` is the other printing and is unchanged.

**Sweep is the school's word for a throw**, standing in for the source's "Throw" family, which
Ashmark's Choke Hold searches for. `tide_undertow` was retitled Tide Wide Sweep to join it; its id
and its place in the Rooke deck are unchanged.

**No approximations.** Three cards needed the engine to grow rather than be rounded off: a Remain
counted from the duelist's Aspect and gated on either of two named cards (Tide Pull Under), a
floating drain that takes an Energy at the start of each of the opponent's attack phases
(Ashmark's Choke Hold), and a reveal that puts every match into play without asking, since the
card leaves nothing to choose (Edric Waits for Low Water).

**Seals 4 and 7 were corrected.** The two Namek Dragon Ball sets are separate cards, not errata of
each other: different sets, numbers and text. The marble set is the earlier printing and the moth
set is the later one, and two of ours had drifted. `moth_seal_4` was carrying the earlier card's
text, which is `marble_seal_4`'s job, and `moth_seal_7` was a placeholder that drew three cards.
Both now carry the later printings. **This changes `steel_beatdown`**, which runs `moth_seal_4`:
it used to wipe their standing cards and now wipes their Allies and guards his own board against
removal.

## Per deck, the order of work

1. Extract, count copies, read set codes, and split the list into Score prints and fan prints.
   Mark the Sensei Deck block while you are here: it runs from the end of the personality ladder
   to the Sensei card, and it goes in `reserve`, not in `cards`.
2. Join the titles to `docs/card_roster.csv` to see which cards we already ship.
3. Confirm each new card's text and set in `tools/source_cards.tsv`, then grep the CRD for errata.
4. Write the new cards as a spec with the helpers in `tools/cardlib.py`, add them with
   `python tools/add_card.py <spec>`, hand-write the deck JSON, and verify it against the sheet at
   distinct-count and copy-count level. The spec is a one-off; the card data is the record.
5. Roster, AI profile, `tests/run_tests.gd`, then an arena run.
