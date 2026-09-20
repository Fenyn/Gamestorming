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
| Blue MBS Goku | 98 / 55 | Sir Edric Rooke, `duelist_iota` | not started |
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

**You're Invited is verified.** It is GK11, a Score World Championships card, ©2003 Score. The
source audit had `open_challenge` down as the one card it could not source, because the card is
missing from the LackeyCCG plugin database.

## Per deck, the order of work

1. Extract, count copies, read set codes, and split the list into Score prints and fan prints.
2. Join the titles to `docs/card_roster.csv` to see which cards we already ship.
3. Confirm each new card's text and set in `tools/source_cards.tsv`, then grep the CRD for errata.
4. Write the new cards in a module under `tools/decks/`, add them with
   `python tools/add_cards.py decks/<name>`, hand-write the deck JSON, and verify it against the
   sheet at distinct-count and copy-count level.
5. Roster, AI profile, `tests/run_tests.gd`, then an arena run.
