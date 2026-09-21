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
| Red TS Majin Buu | 93 / 44 | Bram Ashmark, `duelist_lambda` | built, `pyre_attrition` |
| Saiyan CS Broly | 98 / 50 | Halden Quarr, `duelist_epsilon` | not started |
| Namekian CS Piccolo | 99 / 54 | Osric Thornwald, `duelist_eta` | not started |
| Freestyle MBS Trunks Sword | 98 / 57 | Caedan Vale, `duelist_zeta` | not started |
| Blue MBS Goku | 98 / 55 | Sir Edric Rooke, `duelist_iota` | built, `tide_deepwater` |
| Black TS Majin Vegeta | 98 / 49 | Gideon Mourne, `duelist_mu` | built, `shade_mind_siege` |
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
A sheet runs personalities, then the Sensei Deck, then the Sensei and the Mastery in either order,
then the Life Deck. Those cards belong in the deck's `reserve`, and several of them print "Sensei
Deck Only" on the card itself. The number in the Sensei's corner box is the Sensei Deck size, which
the card database prints as "(Deck Size: n)": West Kai 7, North Kai 13. The block hits that number
exactly on every sheet read so far, and You're Invited counts against it like anything else.

**A card can sit in both the Sensei Deck and the Life Deck, and the extractor hides that.** Both
sections print the same image, so `pypdf` gives one entry with the copies added together, filed at
its first position. Print each distinct card's slot numbers, not just its count: a card whose slots
straddle the Sensei boundary is split between the two. Red's Gohan's Kick is slots 10, 11 and 57,
so two copies are Sensei Deck and one is Life Deck; Blue's Blue Energy Throw is 14 and 76, one
each; Black's Majin Lightning Hit is 15, 16 and 39, two and one. Missing this puts the Sensei Deck
one card over the Sensei's limit, which is how it was caught.

**Every sheet so far totals exactly 85** the way `DeckValidator` counts, Life Deck plus Aspects
plus Mastery plus Relic, with the Sensei Deck outside that count. That is a useful check on a
finished import.

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

**Sensei Deck, 7 cards:** You're Invited (`open_challenge`), Kami Fades x3
(`the_watch_goes_dark`), HUH??? (`defacement`), Gohan's Kick x2 (`no_quarter`). The third Gohan's
Kick is a Life Deck card. These were read as Life Deck cards on the first pass and have been moved
to `reserve`, which took the deck from 90 cards to 85.

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
(fan, swapped to Blue Energy Outburst = `tide_full_weight`, one copy), Frieza's Deception (fan, swapped to
Blue Softening Stance = `tide_held_under`), HUH??? (`defacement`), You're Invited
(`open_challenge`). Blue Energy Throw is one copy here and one in the Life Deck. Four of the eleven
fan prints were Sensei Deck cards, so their replacements sit in `reserve` too. Moving them out took
the deck from 96 cards to 85, and `old_trick`, which fetches an attack out of the Reserve, now has
something to fetch.

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

## Black TS Majin Vegeta, built 2026-09-20 as `shade_mind_siege`, "Mind Siege"

49 distinct faces, 98 copies: four Aspects, a 13-card Sensei Deck, Black Style Mastery 145
(`shade_mastery`), North Kai Sensei 140 (`blank_mask`), and 79 Life Deck cards. 85 by our count.

**The duelist is not new.** `cast_backlog.md` records that Gideon Mourne clears the Vegeta row, so
this is Mourne marked, and it is his first ladder. He already shipped as the Ally `salvage_gamma`,
which is now the pre-mark printing: Gideon Mourne, Mercenary against Gideon Mourne, Lord Mourne.
The ladder is Buu Saga 192 / 193 / 191 and Babidi Saga 114, titled the Marked Lord, Unflinching,
Unfettered, Unrepentant. Card 114's printed Might ladder has one irregular rung, 4,445,000 to
4,610,000, so it is written out rather than stepped.

**Sensei Deck, 13 cards:** Black Pivot Kick x3 (`shade_unraveling`), Black Front Punch x3
(`shade_ransoming_hand`, Sensei Deck only), Cell's Presence x2 (`dismissal`), HUH???
(`defacement`), Cell's Threatening Position (`sever_the_leyline`), Kami Fades
(`the_watch_goes_dark`), Majin Lightning Hit x2 (`marked_lightning`). The third Majin Lightning Hit
is a Life Deck card, which the slot numbers 15/16/39 give away.

**Five fan prints, 13 copies of 98.** Black Kick Blast NZ133 to Black Back Kick, Black Pointed Kick
NZ134 to Black Drop Kick, Black Roundhouse NZ135 to Black Bicycle Kick, Black Negation NZ51 to
Trunks' Energy Sphere (`cut_short`, the same swap the Blue sheet took), Dismal Future NZ167 to
Majin Throwdown MM1 (`the_marked_ring`). Four of the five stay inside the Kick family. **Majin
Mayhem is a two-card set in `source_cards.tsv` and has not been independently confirmed as a Score
print**; its sibling card references Tuff Enuff, which is Score.

**Two keywords carry the families**, because a tag is exact where a title substring is not.
`marked` is the set the source writes as "Majin" in the title, and it now sits on Ashmark's
`relentless_fury`, `scatters_the_ashes` and `wall_of_flame` as well as on the three new Marked
cards. `whisper` is the Shade working the nine Black kicks translate to; `shade_unraveling`,
`shade_nightmare_hold` and `shade_umbral_lash` were retitled into the family, ids unchanged.

**A gate and a keyword are not the same set.** Mourne's Aspect 4 boosts cards that carry `marked`;
The Marked Ring boosts cards *gated* on `marked`. Modifiers filter on `tag` and `only_tag`
respectively. Black Head Crush (`shade_bitter_trade`) is gated without carrying it, which is what
the print says.

**`wall_of_flame` was mis-gated and is fixed.** Majin's Perfect Defense prints "Majin only", not
"Majin Buu only", but we had it on `only: {"duelist_character": "Bram Ashmark"}`, so no second
marked duelist could ever play it. It now reads the tag, the way `ashmarks_ember_spray` already did.

**Engine work this sheet needed:** `tag` and `only_tag` on modifiers, `strike_table_self` /
`strike_table_against` and `focus_tag` on a Constant Power, `extra_use` on a Power, attachments on
the opponent's duelist with `no_prevent`, `damage_trade`, `reserve_ransom`, a `discard_step`
trigger, `down_to` / `all` / `reveal` on `discard_hand`, a `tag:` hand filter, an attacker-side
`own_successful_attack` window, a kind on `stop_next`, `no_shuffle` on `shuffle_discard`, and
`reserve_only` in the deck validator.

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
