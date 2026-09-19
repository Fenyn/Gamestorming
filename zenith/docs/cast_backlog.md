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

Rule 1 is clean at 25 characters. Rules 2 and 3 have **42 cards** left, of which **36** need a
character that does not exist yet.

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

## 1. Attributed already, title needs to lead with the name

No new characters needed.

| id | title now | character | printed source |
|---|---|---|---|
| `cut_short` | Cut Short | Caedan Vale | Trunks Energy Sphere (Trunks Saga) |
| `heirloom_blade` | The Vale Heirloom | Caedan Vale | The Sword of Trunks (Bojack Unbound) |
| `relentless_fury` | Relentless Fury | Bram Ashmark | Majin Buu's Fury (Buu Saga promo P4) |

## 2. Named cards whose character we already have

Attribute to the existing mirror and retitle.

| source character | our mirror | cards |
|---|---|---|
| Android 19 | Siphon | `sabotage` |
| Majin Buu | Bram Ashmark | `scattered_ashes` |
| Android 20 | Cull | `absorbing_drill` |

## 3. Named cards with no mirror character yet

Each row needs a character invented and placed before its cards can be retitled. The card types
say what kind of person the cards imply.

| source character | n | cards | card types |
|---|---|---|---|
| **Gohan** | 8 | `all_or_nothing`, `hilt_guard`, `no_quarter`, `sword_flourish`, `sword_sweep`, `sword_thrust`, `locked_gate_drill`, `swordplay_drill` | Drill, Strike |
| **Goku** | 5 | `lodestone_heart`, `committed_cut`, `quick_retreat`, `first_cut`, `keepers_drill` | Art, Drill, Non-Combat, Relic, Strike |
| **Krillin** | 5 | `blinding_flare`, `unerring_bolt`, `keen_eye`, `clear_mind`, `sleight` | Art, Combat, Non-Combat |
| **Cell** | 4 | `old_habit`, `dismissal`, `sever_the_leyline`, `terms_of_the_pact` | Combat, Pacts only, Strike |
| **Tien** | 4 | `practiced_guard`, `smoke_screen`, `suppressing_shot`, `threefold_bolt` | Art, Strike |
| **Nappa** | 2 | `grounding_step`, `unyielding_guard` | Art, Strike |
| **Bulma** | 1 | `wardens_measure` | Vigils only |
| **Captain Ginyu** | 1 | `captains_barrage` | Art |
| **Frieza** | 1 | `dead_air` | Art |
| **Hercule** | 1 | `old_trick` | Combat |
| **Majin Babidi** | 1 | `tollgate_yard` | Grounds |
| **Pikkon** | 1 | `second_wind` | Strike |
| **Supreme Kai** | 1 | `overreach` | Art |
| **Uub** | 1 | `headlong_plunge` | Strike |

### Notes on the ones with the most to say

- **Gohan** is the largest gap and every card of his is a Sword card or a Sword Drill, so his
  mirror is a swordsman, and Caedan Vale's whole deck is built out of them. They belong to the same
  tradition.
- **Goku** spreads across a Relic, a Drill, a Non-Combat and two attacks, which is the profile of a
  central figure rather than a specialist.
- **Dende** needs a healer. Namekian is our Root school and Piccolo is already Osric Thornwald, so
  Dende belongs near the Thornwald Grove. He is a child in the source and we have no young Vigil
  character at all. He is **not** Thessa: Thessa is an Eidolon, a summoned force behind the gate,
  and Dende is a person who carved a set of seals.
- **Bulma, Hercule, Babidi, Pikkon, Supreme Kai, Uub, Frieza, Captain Ginyu** are one card each and
  can be walk-ons: a name, a place in the world, nothing more until a later deck wants them.

## How to work it

One source character at a time. For each: agree the name first, then write their CAST entry in
`tools/gen_roster.py`, add their cards to `SHOWS`, retitle those cards in `tools/gen_starters.py`
so the title leads with the name, regenerate, and re-run `tools/audit_mirrors.py`. Renaming a card
id means adding its printed source to `NEW_SOURCES` in `tools/gen_roster.py`, or the roster loses
the join and the audit goes blind.
