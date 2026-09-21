# Cast backlog

What is left to do to make every character anchor hold. `tools/audit_mirrors.py` regenerates the
numbers; run it after `tools/gen_roster.py` and it exits non-zero while anything here is
outstanding. Last refreshed 2026-09-19.

## The rules this serves

1. **One source character per character of ours.** A character of ours mirrors exactly one
   character from the reference game. Two of ours may descend from one of theirs (Osric Thornwald
   and Orvath Kell both come from the same source character), but never the reverse.
2. **Named cards lead with the name.** The reference game prints named cards as "<Personality>'s
   <Move>" or "<Personality> <Verb>", and we do the same. A card everybody plays still carries its
   character's name; the character is simply famous enough that other duelists know the technique,
   and the name is what buys that duelist a fourth copy, exactly as in the source.
3. **A card standing in for a named printed card is attributed.** If the printed card carried
   somebody's name, ours carries our mirror of that somebody.

Rule 3 does not reach Relics. The three Relics stand in for printed cards that carried a name and
were de-personalised on purpose, because a Relic is worn rather than owned. `audit_mirrors.py`
reports them as a note (exemption added 2026-09-19).

Rules 1 and 2 are clean as of 2026-09-19: 28 characters, every attributed card leading with its
name. Rule 3 has **20 cards** left, every one blocked on a character who does not exist yet. The
audit counts 19 of them; the twentieth is Kami, whom it cannot see. Where most of those characters
sit is already settled in `world.md`; only the names are missing.

## Naming conventions in force

- **Constructs get one word that names what they are for**: Marrow, Siphon, Tithe, Sledge, Mercy,
  Scorn, Cull. This replaced the Collegium's numbering, which leaked the source's numbers through.
- **People get two-part names**, short and hard in the surname because the card titles are built
  from it: Ashmark, Quarr, Draik, Rooke, Vale, Kell, Mourne. So "was this made or born" is legible
  from the name alone.
- A character's school is what they currently field, never what they are. Followings may span more
  than one school later, and the keyword `construct` already spans two.
- **Do not put a name in the data before it is approved.** Two have been rejected after they were
  applied, and each cost a revert across several files.

## Done

- **Marrow** (the eighth duelist) and her crew: Cull, Orvath Kell, **Gideon Mourne**. Marrow's own
  card is `cold_appraisal`, now "Marrow's Appraisal".
- **Gideon Mourne**, a stripped lord who still signs the title, clears the whole Vegeta row: seven
  cards across five decks, ids and titles both.
- **Siphon, Tithe, Sledge, Mercy, Scorn** retired the Collegium's numbering.
- **2026-09-19, ten titles.** Every card whose character already existed now leads with the name,
  which cleared Rules 1 and 2 outright. `relentless_fury` Ashmark's Relentless Fury,
  `scattered_ashes` Ashmark Leaves Nothing, `cut_short` Vale Cuts It Short, `heirloom_blade` Vale's
  Heirloom Blade, `committed_cut` Edric's Committed Cut, `quick_retreat` Edric Gives Ground,
  `first_cut` Edric Carves First, `keepers_drill` Edric's Retaining Drill, `sabotage` Siphon's
  Drain, `absorbing_drill` Cull's Absorbing Drill. Ids were left alone and attribution went in
  `SHOWS` rather than the data's `character` field, so nothing changed mechanically.
- **The Goku row is closed.** Sir Edric Rooke was already that mirror, through
  `companion_beta`. Four of the five cards are his now and the fifth, `lodestone_heart`, is the
  Relic exemption.
- **2026-09-19, the Red sheet.** Sir Edric Rooke became the ninth duelist (`pyre_ascent`), which
  is the first case of one character fielding two schools: Pyre in his own list, Tide as his
  wife's Ally. That settled the theming rule in `designs/zenith.md`, Keywords: what a card looks
  like comes from that card, not from a fixed element on the person.
- **2026-09-20, the Black sheet.** **Gideon Mourne** becomes the tenth duelist, `duelist_mu`,
  four Aspects, Shade, Pact, Draconic and `marked`. Two printings now: `salvage_gamma` is
  "Gideon Mourne, Mercenary", pre-mark and an Ally in somebody else's crew, and `duelist_mu` is
  "Gideon Mourne, Lord Mourne". Aspects the Marked Lord / Unflinching / Unfettered / Unrepentant.
  **The Fortress** (approved 2026-09-20) is the broken company's third survivor, the slot
  `world.md` already had agreed. His real name is never given, which is the one exception to the
  two-part-name rule; the article keeps it from reading as a construct's one-word label. His two
  cards are `unyielding_guard` "The Fortress' Iron Bulwark" and `grounding_step` "The Fortress'
  Arcane Aegis", the widest retitle so far at ten and eight decks, ids unchanged. Foundation /
  Fortified / Unbreachable is held for whenever he gets a personality card.
  **Two card keywords** were added rather than title families: `marked` for the bargain's cards and
  `whisper` for the Shade working. Three shipped Shade cards were retitled into the Whisper family,
  ids unchanged: `shade_unraveling`, `shade_nightmare_hold`, `shade_umbral_lash`.

- **Torvan Hask** (approved 2026-09-19), Edric's elder brother from the line he left, closes the
  Raditz row: one card, `hasks_flying_kick`.
- **Emrys Rooke** (approved 2026-09-19), the eldest son, a swordsman where his parents are
  casters, closes the Gohan row: eight cards. `no_quarter` Emrys Gives No Quarter,
  `all_or_nothing` Emrys Risks It All, `hilt_guard` Emrys' Hilt Guard, `sword_flourish`,
  `sword_sweep` and `sword_thrust` Emrys' Sword Flourish / Sweep / Thrust, `swordplay_drill`
  Emrys' Swordplay Drill, `locked_gate_drill` Emrys Spots the Fraud Drill. His name is now on
  a card in six decks, which is the rule working as intended. **The sword titles are
  load-bearing**: Vale's Aspect 1, `vales_sword_draw`, `swordplay_drill` and the Vale Heirloom
  all match on the substrings "Sword" and "Swordplay", so any future retitle has to keep them.
- **Corin Thrace** (approved 2026-09-19), an ascetic of no house who teaches a discipline rather
  than a school, closes the Tien row: five cards. `practiced_guard` Corin's Practiced Guard,
  `smoke_screen` Corin Throws Smoke, `suppressing_shot` Corin's Suppressing Shot, `threefold_bolt`
  Corin's Threefold Bolt, and the new `corins_conditioning` Corin's Conditioning. He pilots no deck,
  which is why his forms turn up in other people's hands across the field. Checked before
  retitling: nothing in the generator matches any of those titles as a substring, unlike the sword
  cards.

## 3. Named cards with no mirror character yet

Each row needs a character invented and placed before its cards can be retitled. The card types
say what kind of person the cards imply.

| source character | n | cards | card types |
|---|---|---|---|
| **Krillin** | 5 | `blinding_flare`, `unerring_bolt`, `keen_eye`, `clear_mind`, `sleight` | Art, Combat, Non-Combat |
| **Cell** | 4 | `old_habit`, `dismissal`, `sever_the_leyline`, `terms_of_the_pact` | Combat, Pacts only, Strike |
| **Nappa** | 2 | `grounding_step`, `unyielding_guard` | Art, Strike |
| **Bulma** | 1 | `wardens_measure` | Vigils only |
| **Captain Ginyu** | 1 | `captains_barrage` | Art |
| **Frieza** | 1 | `dead_air` | Art |
| **Hercule** | 1 | `old_trick` | Combat |
| **Majin Babidi** | 1 | `tollgate_yard` | Grounds |
| **Pikkon** | 1 | `second_wind` | Strike |
| **Supreme Kai** | 1 | `overreach` | Art |
| **Uub** | 1 | `headlong_plunge` | Strike |
| **Kami** | 1 | `the_high_watch` | Grounds |

### Notes on the ones with the most to say

- **Kami is invisible to `audit_mirrors.py`** and has to be tracked by hand. The tool builds its
  list of source people from the card database's personality cards, and Kami is never printed as
  one; his name only appears inside other cards' titles. Added 2026-09-19 with `the_high_watch`
  (Kami's Floating Island), a watchpost above the cloud line where you see what is coming. Whoever
  holds that office in our world is unplaced; the Vigil's highest office, already reserved for the
  Supreme Kai row, is the obvious neighbour but not the same person.

- **Dende** needs a healer. Namekian is our Root school and Piccolo is already Osric Thornwald, so
  Dende belongs near the Thornwald Grove. He is a child in the source and we have no young Vigil
  character at all. He is **not** Thessa: Thessa is an Eidolon, a summoned force behind the gate,
  and Dende is a person who carved a set of seals.
- **Bulma, Hercule, Babidi, Pikkon, Supreme Kai, Uub, Frieza, Captain Ginyu** are one card each and
  can be walk-ons: a name, a place in the world, nothing more until a later deck wants them.

### Where each of them already sits

Placed in `world.md` on 2026-09-19, so only the name is outstanding. (Gohan is placed there as a
Rooke by blood, Vale-trained in the sword and Thornwald-taught in the rest; that is Emrys Rooke
and it is done.) Krillin is the Kingsguard's form at
contact; Corin Thrace, who is done, was its form at distance. Bulma is a Vale and Caedan's mother. Nappa is the
broken company's third survivor. Ginyu captains the retained guard. Babidi lays the demons' mark
and works the toll gate. Supreme Kai holds the Vigil's highest office, which is what `overreach`
reaches past. Uub ties back to Bram Ashmark. Hercule claims a Kingsguard form he was never taught.
Cell, Pikkon and Frieza have no placement yet.

## How to work it

One source character at a time. For each: agree the name first, then write their CAST entry in
`tools/gen_roster.py`, add their cards to `SHOWS`, retitle those cards in `data/cards/starter/starter_set.json`
so the title leads with the name, regenerate, and re-run `tools/audit_mirrors.py`. Renaming a card
id means adding its printed source to `NEW_SOURCES` in `tools/gen_roster.py`, or the roster loses
the join and the audit goes blind.
