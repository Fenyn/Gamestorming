# Adventure starters

Hand-authored 2026-09-20, deck by deck. Files are `data/adventure/starters/<deck>_start.json`.
They replace the generated starters, which culled by a power score and left several decks without
their own plan. `tools/scale_deck.py` no longer writes starters; it writes the opponent tiers only.

## The brief

- 50 cards for every starter, 55 for Root, since the 2026-09-21 rebuild. Adventure duels are first
  to two points, so a deck is fought through twice and removed cards do not come back.
- A stop floor by archetype, as a minimum: most aggressive 8, beatdown 10, midrange 12, control or
  setup 14. About a third of a deck's stops stop either kind, so a Focused attack means something.
- The precon is a guideline, not a fence. A starter may hold any legal card that fills a need,
  preferring its school's own flavour and its duelist's Signature cards. Filler that is meant to be
  replaced is listed in the file's `chaff` field.
- Tide Companions alone carries a Relic and a Reserve, because its Bond card and its toolbox live
  there on the source sheet and the deck cannot fuse without them.
- One or two bombs, listed in each file's `bombs` field.
- Enough interaction: stops for both Strikes and Arts, ways to touch the board or the hand, and
  enough offense or goal cards to win.
- Cuts leave the deck's key strong elements intact and make room to build around them.

## Rules held across every deck

- No lockouts, with one exception: Shade Salvage holds three on-hit lockout attacks, granted
  2026-09-21 because it is the weakest deck. For everyone else: nothing that stops all attacks, or all of a kind, for the rest of Combat, and nothing
  that forbids a card type. Those stay in the precons as ladder threats and unlocks. `signature_combat_02`
  and `tide_art_01` are left out on the same grounds: they prevent all damage, or all Art
  wounds, for the rest of Combat, which plays as a stop-all even though the filter does not flag it.
- No Grounds. They are unlocks.
- No copy cap beyond the game's own limits (3, or 4 for the duelist's own named cards). The old
  two-copy cap was dropped 2026-09-21: balance matters more than a house limit.
- The per-deck notes further down were written for the 40-card builds and predate the 2026-09-21
  rebuild. The card lists in the files are current; the notes are not.
- `signature_combat_03` (stops a Combat card's effects) is in every starter, as the universal answer to a
  trick.

## Open and advanced starters

Decided 2026-09-20 after the first playtest. Nine starters are open from the first run. Five are
**advanced**: locked until the deck-cap track reaches 50, and they start bigger and further along.

| advanced | starts at | Aspects | upgrades built in |
|---|---|---|---|
| steel_heir | 50 | 3 | third copies of the Draconic Strikes and both Energy-drain stops, `freestyle_noncombat_01` |
| shade_salvage | 50 | 3 | all four Allies (Gideon Mourne, Pim), third copies of the Arts and construct cards, `freestyle_noncombat_06`, `freestyle_combat_04` |
| tide_companions | 50 | 3 | all four Allies (Wren, Sir Edric), `signature_combat_06`, third copies of the Ally tutors and Arts |
| storm_unbound | 50 | 3 | Pim, third copies of the Storm Arts, the guards and `signature_noncombat_02` |
| root_seals | 55 | 3 | third copies of the Arts, stops and `signature_drill_05`, `freestyle_noncombat_06`, `freestyle_noncombat_13` |

Each file carries `"unlock": {"track": "deck_cap", "step": 50}`. Nothing reads that field yet: the
runtime has no unlock system, and every starter is playable. All fourteen feed one shared pipeline
(`data/adventure/ladders/pipeline.json`): eight stages, each a tier (t1 to boss) and a band, and
the run seed rolls which family from that band is fought. The bands (`weaker`, `medium`,
`stronger`) live in `data/adventure/opponent_bands.json` and follow the measured starter standings.
Advanced starters may run a third copy of a card; the open ones still cap at two.

Why these five: in the first playtest (336 games, each starter against six tier-1 opponents) they
came in lowest. Tide Companions 37.5%, Shade Salvage 41.7%, Steel Heir 41.7%, Storm Unbound 54.2%,
Root Seals 58.3%. Their plans need setup, and the duels at starter size run only 3 to 5 turns.

## Deck by deck

The per-deck notes below describe the open 40-card builds. The five advanced starters keep the same
plan and bombs, with the additions in the table above.

Stop counts include every card that can stop an attack.

### Steel Beatdown, Halden Quarr
Plan: heavy Strikes backed by Might and card draw from the Mastery.
Bombs: `steel_strike_02` (stops a Strike, Remain 9 while Quarr out-Mights them) and
`signature_strike_25` (Quarr only, stops either kind, Remain 1, shuffles back).
Kept: the Endurance Strikes (`hammer_blow`, `iron_fist`, `scar_tissue`), `battering_ram`,
`piston_slam`, Quarr's `crushing_blow`. Board: `crushing_weight`, `headbutt`, `signature_combat_04`.
Stops: 8, with `ironhide` and `bracing` covering Arts. `iron_knee` fetches the two Moth Seals kept.
Cut: `signature_strike_27`, `steel_art_02`, `signature_strike_01`, `signature_strike_02` (lockouts), `bull_charge`.

### Pyre Beatdown, Bram Ashmark
Plan: attack every Combat, Focus through blocks with the Mastery, climb on Fervor.
Bombs: `freestyle_drill_01` (starts in play, drains their Fervor and feeds Energy every Combat) and
`freestyle_combat_04` (sets their duelist to Aspect 1).
Kept: `pyre_strike_12` (makes the rest of the Combat Focused), `flame_lash`, `rekindling`,
`signature_strike_09` and `blazing_charge` (unstoppable by Strike cards), `signature_noncombat_04`.
Board: `firestorm`, `scouring_flame`, `immolation`, `signature_combat_04`.
Stops: 5, the thinnest of any starter. That is the deck: Pyre trades defense for tempo, and every
other defensive card in the precon is a lockout. `signature_strike_08` covers Arts and Focused attacks.

### Pyre Ascent, Sir Edric Rooke
Plan: weather the early game on guards that also raise Fervor, then climb.
Bombs: `signature_art_09` (+2 own Fervor, -2 theirs) and `signature_strike_05` (Remain 1 for Edric).
Kept: six kinds of guard, most of which raise Fervor as they stop, so defending is progress.
`signature_strike_07`, `signature_strike_06`, the Pyre climbing Strikes. Dame Alder stays as the Ally.
Stops: 12. Board: `immolation`, `firestorm`, `freestyle_combat_06`.
Cut: `freestyle_combat_17` (would remove Dame Alder too), `freestyle_noncombat_01`, `freestyle_combat_05`, `freestyle_noncombat_12`.

### Pyre Attrition, Bram Ashmark (Marked)
Plan: strip their table, out-last them, refill the Life Deck.
Bombs: `freestyle_combat_20` (wipes every Non-Combat and Ally in play) and `signature_art_09`.
Kept: `freestyle_strike_03`, `signature_art_14` (Marked Art with recursion), `sword_cleave` with
`signature_strike_13` to fetch it, `rekindling`, `searing_guard`.
Board: `firestorm`, `scouring_flame`, `immolation`, `signature_combat_04`. Stops: 8, both kinds.

### Freestyle Swords, Caedan Vale
Plan: Drills the Mastery makes permanent, then chained sword signatures.
Bombs: `freestyle_drill_01` and `freestyle_noncombat_02` (any attack from Life Deck or discard).
Kept: `signature_drill_01`, `freestyle_drill_03` (its self-discard is switched off by the Mastery),
`signature_art_04` and `signature_strike_10` (each puts a Drill into play), `signature_noncombat_06`,
`signature_noncombat_03`, the Vale signature Strikes. Board: `signature_strike_12`, `signature_strike_11`, `freestyle_combat_06`.
Stops: 9. Cut: `freestyle_drill_04`, `freestyle_drill_05`, `freestyle_combat_01`, `freestyle_combat_07` (lockouts).

### Root Seals, Osric Thornwald (45 cards)
Plan: survive and carve all seven Marble Seals.
Bombs: `freestyle_noncombat_17` (a successful Art puts a Seal into play and captures one) and
`freestyle_art_07` (8 wounds, -3 Fervor).
Kept: all seven Seals, five Seal tutors plus `signature_drill_06`, `signature_drill_05` x2 so the Seals
cannot be captured. Arts: `root_art_04` (scales with Seals), `destruction_blast`, `root_combat_01`.
Stops: 10. Board: `freestyle_combat_17`, `freestyle_combat_19`, `freestyle_combat_06`.
Cut: `freestyle_art_08`, `signature_art_12`, `freestyle_noncombat_16`, `freestyle_combat_01` (lockouts), `freestyle_noncombat_13`.

### Shade Henchmen, Sable Draik
Plan: a hexer company on the table while the hand is stripped.
Bombs: `signature_art_06` (Sable only, unpreventable, Remain with two Allies) and `freestyle_art_02`.
Kept: Vesna and Brann with their own Strikes, which fetch more Allies on hit; `freestyle_combat_13`,
`freestyle_art_05`. Hand: `nightmare_hold`, `oblivion_touch`, `dread_grip`, `mind_rot`.
Board: `signature_art_03`, `signature_combat_04`. Stops: 9.

### Shade Mind Siege, Gideon Mourne (Marked)
Plan: take their hand, table and options, then finish.
Bombs: `freestyle_drill_01` and `freestyle_art_11` (trades wounds for their Drills).
Kept: the Whisper Strikes with `returning_whisper` to recur them, `sifting_whisper`,
`emptying_whisper`, `shade_drill_03`. `signature_strike_08` covers Focused attacks.
Stops: 9. New: this deck had no starter or opponent tiers before today.
Flag: `shade_drill_03` (they discard their whole hand at the Discard step) plays close to a
third bomb.

### Shade Salvage, Marrow (Construct)
Plan: a construct crew that makes each other stronger, then Arts.
Bombs: `signature_combat_09` x2 (Marrow only, two Allies into play at full Energy) and `freestyle_art_02`.
Kept: Cull and Orvath Kell, `freestyle_drill_07`, `signature_noncombat_01`. Arts: `rending_palm`,
`cutting_hand`, `umbral_lash`, `signature_art_08`. Board: `signature_art_03`, `freestyle_noncombat_11`,
`freestyle_noncombat_01`, `freestyle_noncombat_12`. Stops: 10. `signature_noncombat_05` answers an Ascension win.

### Steel Heir, Emrys Rooke
Plan: big Draconic Strikes, paid for with life cards.
Bombs: `steel_strike_16` (a flat 10 Energy Strike) and `signature_art_09`.
Kept: `steel_strike_18`, `steel_strike_17`, `steel_strike_21`, `stamp` and `tackle`,
`steel_drill_01`, `freestyle_noncombat_05`. Board: `headbutt`, `freestyle_combat_06`, `freestyle_noncombat_12`.
Stops: 8, both kinds. Dame Alder stays as the Ally.

### Storm Unbound, Siphon (Construct)
Plan: disruptive Arts while the Mastery keeps them off Strikes.
Bombs: `signature_art_09` and `seal_19`.
Kept: the five-wound Storm Arts, `storm_art_04`, `signature_noncombat_02`, Cull and Orvath Kell
with `freestyle_drill_07`. Stops: 10. Cut: `storm_art_10`, `signature_art_07` (lockouts).

### Storm Volley, Siphon (Construct)
Plan: a barrage of discounted Arts.
Bombs: `storm_art_05` (Empower 3, strips Drills) and `storm_strike_01` (unpreventable for the
rest of Combat).
Kept: `signature_art_02`, `signature_art_05`, `signature_art_10`, `signature_strike_24` to tutor, two
Sun Seals for draw. Stops: 9. `freestyle_art_02` x1 is the 40th card and plays close to a third bomb.

### Tide Companions, Dame Alder Rooke
Plan: Allies out, the Bond, then fight through Allies once the Duelist's Energy is spent.
Bombs: `freestyle_combat_08` (an Ally into play, their Seals discarded) and `freestyle_combat_09` (5 wounds, sets
her own Energy to 0, which is the plan).
Kept: **Tavin Vale and Ansel Rooke, the pair `personality_54` fuses**, with `freestyle_noncombat_08` x2,
`freestyle_noncombat_06` to tutor it, and `freestyle_combat_12` and `tide_art_05` to find Allies.
Stops: 8. Board: `drowning`, `signature_combat_05`, `freestyle_combat_06`.
**Correction:** the earlier starter kept Wren and Sir Edric, so its Bonding card had nothing to
fuse. Tide's win condition was dead in the starter and in the generated opponent tiers.
`tools/scale_deck.py` now keeps the Bond pair and the tiers are regenerated.

### Tide Deepwater, Sir Edric Rooke
Plan: hold their Fervor down with every blow and strip what they place.
Bombs: `freestyle_drill_01` and `signature_strike_30` x2 (drains their Energy every attack phase).
Kept: the Fervor-lowering Tide Strikes, `pull_under` with Moth Seals 3 and 4 for its Remain,
`signature_strike_05`. Stops: 7. Cut: `seal_28` (no Mastery, a lockout), `tide_strike_08`,
`tide_strike_06`.

## Open

- Three decks hold three or four limit-1 cards beyond their bombs: Root, Tide Companions and Shade
  Salvage run tutors that are printed at limit 1. They are there as tutors, not as bombs, but
  worth a look if those decks play too strong.
- None of these have been playtested. The next step is starter against tier 1 on the ladder.
