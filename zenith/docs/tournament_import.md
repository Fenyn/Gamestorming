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
| Red TS Majin Buu | 93 / 44 | Bram Ashmark, the Glut line | built, `pyre_attrition` |
| Saiyan CS Broly | 98 / 50 | Halden Quarr, `personality_halden_quarr_*` | not started |
| Namekian CS Piccolo | 99 / 54 | Osric Thornwald, `personality_osric_thornwald_*` | not started |
| Freestyle MBS Trunks Sword | 98 / 57 | Caedan Vale, `personality_caedan_vale_*` | not started |
| Blue MBS Goku | 98 / 55 | Sir Edric Rooke, `personality_edric_rooke_*` | built, `tide_deepwater` |
| Black TS Majin Vegeta | 98 / 49 | Gideon Mourne, the Lord Mourne line | built, `shade_mind_siege` |
| Orange TS Yamcha | 94 / 58 | new, Storm, Idris Sparrow | built, `storm_mentor` |
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
that `cast.md` describes but no card carries yet ("Majin only" gates Energy Spray), and a
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
printed cards Sir Edric Rooke's ladder already uses, and its tier 5 is a fan print, so the real Cell Saga
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
this is Mourne marked, and it is his first ladder. He already shipped as the Ally `personality_gideon_mourne_1_mercenary`,
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

## Orange TS Yamcha, built 2026-09-28 as `storm_mentor`, "Endless Squall"

Named 2026-09-28: Yamcha is Idris Sparrow (Scrapper, Cut Loose, Stillwind, Stormedge), Krillin is
Aldo Voss, Maraikoh is Sandmaw, and Master Roshi Sensei is The Champion's Laurel. Uub's Energy Drill
keeps its placeholder. The fiction is in `cast.md`.

58 distinct faces, 94 copies: a four-level Yamcha (Fusion Saga 092, Kid Buu Saga 092, Cell Saga
088, Androids Saga 123), Orange Style Mastery 146 (the Trunks Saga printing we already ship as
`storm_mastery_01`), Master Roshi Sensei (Buu Saga 153, Deck Size 9), a 9-card Sensei Deck and 79
Life Deck cards. 85 by our count. The user wanted the list built card for card: a card we already
ship is reused only when its behaviour matches the print exactly, otherwise it is a new card.

**Reused, checked against the print and the rulings document:** 37 of the 49 real faces. Tokui-Waza
conditions stay unconditional (standing deviation, every deck has a Mastery). Our "Limit 1 per deck"
on Energy Lob, Vegeta's Physical Stance, both Nappa cards, Super Saiyan Effect, Expectant Trunks and
Orange Uppercut is the rulings document's Restricted list, not an invented limit, and Fatherly
Advice's errata reads "Combat, Physical Combat, or Energy Combat card", which is what ours does. The
sheet runs Vegeta's Physical Stance with Nappa's Physical Resistance, which the rulings document's
11/24/04 one-per-group rule forbids; the user kept it as printed, and `DeckValidator` does not enforce
those groups.

**Twelve real cards are new:** the four Yamcha levels (`personality_63` to `_66`, Vigil, no
bloodline), Master Roshi Sensei (`relic_05`), Kid Trunks Buu Saga 166 as Tavin Vale's second print
(`personality_67`, "Fostered Son"; our `personality_51` is the Kid Buu Saga print and a different
card), Krillin, the Father (`personality_68`), Maraikoh, the Vicious (`personality_69`, a Celestial
Fighter, so either side), Orange 5-Finger Focus (`storm_art_25`), Orange Energy Catch (`storm_art_26`),
Orange Destruction Drill (`storm_drill_09`), Orange Haulting Drill (`storm_drill_10`), Gohan's Braced
Energy Beam (`signature_art_15`, Emrys), Vegeta's Energy Focus (`signature_art_16`, Mourne) and Uub's
Energy Drill (`signature_drill_07`). Might ladders are designed on the compact scale like every other
(tops 20 / 26 / 32 / 38 for the duelist); Surge is printed.

**Nine fan prints, 22 copies of 94**, swapped at the user's call for Score cards of the job the user
described: Orange Rising Energy NZ146 x3 (an Energy top-off to keep casting after a hit) to Orange
Strength `storm_strike_03`; Lonely Canyon NZ193 x3 (Arts for free) to Focusing, new as
`freestyle_noncombat_21` "Centering"; Frieza's Deception NZ41 x2 (Sensei Deck; it advances the
opponent's Main Personality, a tech card against decks that keep Drills and Allies) to Drills are for
the Weak `freestyle_noncombat_01` and a third Orange Obliteration `storm_art_05` (Android 17 Smirks is
Villains only); Orange Kaio-Ken Outburst NZ149 x3 to Orange Ki Assailment `storm_art_18`; Orange Right
Blast NZ67 x2 to Orange Focused Attack `storm_art_17`; Heroic Deeds NZ161 x3 to Heroic Effort, new as
`freestyle_art_12` "Vigilant Effort"; Orange Aura Deflection NZ147 x3 to Orange Sidestep
`storm_strike_04`; Left Leg Check NZ195 x2 to Yamcha's Skillful Defense, new as `signature_art_17`;
Orange Negation NZ66 to a second Trunks' Energy Sphere `signature_combat_03`. Three of the fan prints
carried a "Transform." keyword no rules document defines.

**Sensei Deck, 9 cards:** Majin Buu's Fury x3 (`signature_strike_02`), Cell's Presence x2
(`freestyle_combat_17`), the two Frieza's Deception replacements, HUH??? (`freestyle_noncombat_10`),
You're Invited (`freestyle_noncombat_09`).

**Engine work this sheet needed:** Relic modifiers (a Sensei's standing line), a modifier worth the
performer's Surge, attack variants that apply only on Empower plus `empower_remain`, one-use cost
modifiers spent at payment, `next_art_free` on an Energy raise, paying an Art's cost with the top Life
Deck card (`life_for_art_costs`, with a choice when Energy could pay), a `max_base_life` search filter
on printed Base Damage, and `no_ally_takeover` for "cannot have Allies take control" without the
damage lock `no_ally_control` also carries.

## Freestyle Vegeta (Didier G, Gen Con 2012), planned as the pre-mark Gideon Mourne deck

Not a proxy sheet: a Score-era Retro tournament report, "Freeing Vegeta With Style" on
retrodbzccg.com (2012-08-24), top cut at Gen Con. Chosen 2026-09-30 for the earlier, unmarked
Gideon Mourne (`cast.md`, "The earlier Gideon"). Every card is a Score print. Two are promos the
Lackey file lacks and were read off seller scans: **Vegeta's Gutter Wallop** (Vegeta Season league
promo L6-6, 2003: "Physical attack doing +4 power stages of damage. Look at your opponent's hand.
If successful and used by Vegeta or Majin Vegeta, raise your anger 3 levels.") and **Vegeta's
Energy Detonation** (Broly subset #36, printed "Vegeta's Energy Blast" and retitled by the rulings
document: "Energy attack doing 6 life cards of damage. If used by Vegeta, then for the remainder
of Combat the bottom 15 cards of your discard pile are Vegeta Named cards while in your discard
pile."). "Android 19's Burst" in the Sensei block is read as a second and third Android 19's Energy
Burst. The report does not name its Mastery; `freestyle_mastery_01` (Signature tutor) fits the
named-card engine it describes.

**How it plays, per the report.** Freestyle energy beatdown built on Vegeta-named cards. Rush
Aspect 2 (Settled Down: the rival cannot play or use Combat cards, attacks +2 wounds) with Gutter
Wallop's +3 anger; jump to Aspect 3 (Last Prince: look at their hand, discard one) against
beatdown. Run slim and let attacks land, because Energy Detonation plus Energy Thrust shuffles the
whole bottom of the discard pile back in ("at least 30 cards each"). Krillin's Concentration and
Fatherly Advice fetch Vegeta is Lurking, which fetches three named cards, so double Lurking in one
Combat is common. Aura Clash jumps to Settled Down against control. The Sensei (North Kai, 13) is
drill and Dragon Ball tech plus Vegeta's Elbow Slam against Red anger decks.

**Ladder, five Aspects (all new cards):** Super Saiyan Vegeta L1 (Redemption: search your discard
pile for a Vegeta named card and shuffle it into your Life Deck), Vegeta, Settled Down L2 (Kid Buu
Saga), Vegeta, the Last Prince L3 (Cell Saga), Vegeta, Ascendant L4 (Cell Saga: Defense Shield,
draw entering Combat), Vegeta, the Revitalized L5 (Cell Saga: Strike +9). `personality_48`
(Mercenary) stays an Ally print.

**Main deck, 65, mapped to our pool:**

| Copies | Print | Ours |
|---|---|---|
| 4 | Vegeta's Energy Thrust | new, Mourne-named |
| 4 | Vegeta's Gutter Wallop | new, Mourne-named |
| 4 | Vegeta's Energy Detonation | new, Mourne-named; needs a "bottom N of discard count as named" float |
| 4 | Vegeta's Jolting Slash | `signature_art_07` Mourne's Jolting Arc |
| 4 | Vegeta's Energy Focus | `signature_art_16` Mourne's Unpaid Bolt |
| 1 | Vegeta is Lurking | new, Mourne-named, limit 1 |
| 2 | Vegeta's Lunge | new, Mourne-named |
| 1 | Vegeta's (Ill) Temper | new, Mourne-named |
| 1 | Vegeta's Physical Stance | `signature_strike_03` Mourne's Stance |
| 1 | Vegeta's Quickness Drill | `signature_drill_03` Mourne's Quickness Drill |
| 2 | Goku's Power Strike | `signature_art_04` Edric's Committed Cut |
| 2 | Gohan's Kick | `signature_strike_01` Emrys Gives No Quarter |
| 1 | Energy Lob | `freestyle_art_03` Lobbed Bolt |
| 1 | Android 19's Energy Burst | `signature_art_03` Siphon's Drain |
| 3 | Android 18's Stare Down | `signature_combat_04` Marrow's Appraisal |
| 1 | Aura Clash | `freestyle_combat_14` Raised Stakes |
| 1 | Battle Pausing | `freestyle_combat_05` Respite |
| 3 | Goku's Flight | `signature_strike_23` Edric Gives Ground |
| 1 | Narrow Escape | new, Freestyle |
| 1 | Time is a Warrior's Tool | `freestyle_combat_01` Stillness |
| 1 | Cell's Defense | `freestyle_combat_03` Terms of the Pact |
| 2 | Pikkon's Leg Catch | `freestyle_strike_06` Second Wind |
| 1 | Tien's Block | `signature_strike_26` Corin's Practiced Guard |
| 2 | Energy Ricochet | new, Freestyle |
| 3 | Krillin's Concentration | `freestyle_noncombat_03` Voss' Clear Mind. The rulings document restricts it (2/11/04); the user lifted that 2026-09-30 so the list runs 3, as the Retro report did |
| 2 | Krillin's Power Tap | new, Voss-named |
| 1 | Fatherly Advice | `freestyle_noncombat_02` Recalled Lesson |
| 1 | Releasing the Sword | new, Freestyle |
| 1 | Hero's Lucky Break | `freestyle_noncombat_06` Lucky Find |
| 1 | Expectant Trunks | `freestyle_noncombat_04` Foresight |
| 1 | Don't You Just Hate That | `freestyle_noncombat_12` Spoiled Rite |
| 1 | Victorious Drill | `freestyle_drill_01` Bravado Drill |
| 1 | Android 20 Absorbing Drill | `signature_drill_02` Cull's Absorbing Drill |
| 1 | Broly's Evil Drill | new, Quarr-named, Pact only |
| 1 | Master Roshi's Gawking Drill | new; Roshi has no mirror (the Laurel is a Relic), so PLACEHOLDER-named |
| 1 | Uub's Energy Drill | `signature_drill_07` PLACEHOLDER's Surging Drill |
| 2 | Tree of Might | `grounds_02` Ancient Grove |

**Sensei, North Kai (13) = `relic_01` The Blank Mask, Reserve 13:** Black Scout Maneuver
(`shade_combat_02`), You're Invited (`freestyle_noncombat_09`), Android 19's Energy Burst x2
(`signature_art_03`), Android 17 Smirks (`signature_combat_07`), Vegeta's Elbow Slam x2 (new,
Mourne-named, Sensei only), HUH??? (`freestyle_noncombat_10`), Black Water Confusion Drill
(`freestyle_drill_06`), Kami Fades x2 (`freestyle_noncombat_18` The Watch Goes Dark, whose roster
row has no source recorded but whose text is Kami Fades'), Breakthrough Drill (`freestyle_drill_05`).
That is 12; the 13th slot is open.

**Proposed split (2026-09-30, awaiting names):**

- **PvP precon:** the list above as printed, five Aspects, `freestyle_mastery_01`, The Blank Mask
  with the Sensei block as Reserve. 65 + 5 + Mastery + Relic by our count.
- **Adventure starter, 50 cards, Aspects 1 to 3.** Keeps the engine the report describes: Energy
  Thrust x4 and Gutter Wallop x4 (the two `bombs`), Energy Focus x3, the Freestyle Strikes and Arts
  (Power Strike, Kick, Energy Lob, Energy Burst), Stare Down x3 and Lunge x2 for the hand, the
  non-lockout stops (Goku's Flight x3, Leg Catch x3, Energy Ricochet x2, Tien's Block, Android 20
  Absorbing Drill, Trunks' Energy Sphere per the starter rule), the tutors (Concentration, Fatherly
  Advice, Expectant Trunks, Hero's Lucky Break), the Drills (Quickness, Victorious, Uub's, Gawking)
  and Vegeta's Temper. Out, per the starter brief: Tree of Might (Grounds) and every lockout
  (Jolting Slash, Physical Stance, Time is a Warrior's Tool, Cell's Defense, Narrow Escape).
  Aspect 2's "rival cannot play Combat cards" is itself a lockout; it stays because the user set
  ranks 1 to 3 for the starter.
- **Unlocks, on the Gideon Mourne personality track:** Vegeta is Lurking and Energy Detonation
  (the combo bombs), then the Relic and Reserve ability, then Aspect 4, then Aura Clash and Jolting
  Slash, then Aspect 5. The Marked line's items on that track move to the Marked Lord unlock, which
  becomes a story quest (lore held for later).
- **Open starter:** replaces `shade_mind_siege_start` in `storylines.json` and inherits its
  storyline (Shade Salvage act 1 boss with Orvath Kell joining, Henchmen act 2).

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
