# Adventure starters

Hand-authored 2026-09-20, deck by deck. Files are `data/adventure/starters/<deck>_start.json`.
They replace the generated starters, which culled by a power score and left several decks without
their own plan. `tools/scale_deck.py` no longer writes starters; it writes the opponent tiers only.

## The brief

- 40 cards, 45 for Root. Two Aspects.
- One or two bombs, listed in each file's `bombs` field.
- Enough interaction: stops for both Strikes and Arts, ways to touch the board or the hand, and
  enough offense or goal cards to win.
- Cuts leave the deck's key strong elements intact and make room to build around them.

## Rules held across every deck

- Every card comes from that deck's own precon, at or under the precon's count.
- No lockouts: nothing that stops all attacks, or all of a kind, for the rest of Combat, and nothing
  that forbids a card type. Those stay in the precons as ladder threats and unlocks. `will_not_break`
  and `tide_breakwater` are left out on the same grounds: they prevent all damage, or all Art
  wounds, for the rest of Combat, which plays as a stop-all even though the filter does not flag it.
- No Grounds. They are unlocks.
- At most two of any card, with two exceptions where the precon ran out of non-lockout cards:
  `pyre_cinder_guard` x3 in Pyre Beatdown and `cold_appraisal` x3 in Shade Salvage.
- `cut_short` (stops a Combat card's effects) is in every starter, as the universal answer to a
  trick.

## Open and advanced starters

Decided 2026-09-20 after the first playtest. Nine starters are open from the first run. Five are
**advanced**: locked until the deck-cap track reaches 50, and they start bigger and further along.

| advanced | starts at | Aspects | upgrades built in |
|---|---|---|---|
| steel_heir | 50 | 3 | third copies of the Draconic Strikes and both Energy-drain stops, `rites_unmade` |
| shade_salvage | 50 | 3 | all four Allies (Gideon Mourne, Pim), third copies of the Arts and construct cards, `lucky_find`, `sever_the_leyline` |
| tide_companions | 50 | 3 | all four companions (Wren, Sir Edric), `edrics_vow`, third copies of the Ally tutors and Arts |
| storm_unbound | 50 | 3 | Pim, third copies of the Storm Arts, the guards and `corins_conditioning` |
| root_seals | 55 | 3 | third copies of the Arts, stops and `keepers_drill`, `lucky_find`, `gates_boon` |

Each file carries `"unlock": {"track": "deck_cap", "step": 50}`. Nothing reads that field yet: the
runtime has no unlock system, and a starter is playable only when it has a ladder file under
`data/adventure/ladders/`. None of these five has one. Advanced starters may run a third copy of a
card; the open ones still cap at two.

Why these five: in the first playtest (336 games, each starter against six tier-1 opponents) they
came in lowest. Tide Companions 37.5%, Shade Salvage 41.7%, Steel Heir 41.7%, Storm Unbound 54.2%,
Root Seals 58.3%. Their plans need setup, and the duels at starter size run only 3 to 5 turns.

## Deck by deck

The per-deck notes below describe the open 40-card builds. The five advanced starters keep the same
plan and bombs, with the additions in the table above.

Stop counts include every card that can stop an attack.

### Steel Beatdown, Halden Quarr
Plan: heavy Strikes backed by Might and card draw from the Mastery.
Bombs: `steel_immovable_guard` (stops a Strike, Remain 9 while Quarr out-Mights them) and
`shrugs_it_off` (Quarr only, stops either kind, Remain 1, shuffles back).
Kept: the Endurance Strikes (`hammer_blow`, `iron_fist`, `scar_tissue`), `battering_ram`,
`piston_slam`, Quarr's `crushing_blow`. Board: `crushing_weight`, `headbutt`, `cold_appraisal`.
Stops: 8, with `ironhide` and `bracing` covering Arts. `iron_knee` fetches the two Moth Seals kept.
Cut: `quarrs_roar`, `steel_shockwave`, `no_quarter`, `relentless_fury` (lockouts), `bull_charge`.

### Pyre Beatdown, Bram Ashmark
Plan: attack every Combat, Focus through blocks with the Mastery, climb on Fervor.
Bombs: `bravado_drill` (starts in play, drains their Fervor and feeds Energy every Combat) and
`sever_the_leyline` (sets their duelist to Aspect 1).
Kept: `pyre_kindling` (makes the rest of the Combat Focused), `flame_lash`, `rekindling`,
`all_or_nothing` and `blazing_charge` (unstoppable by Strike cards), `stokes_the_coals`.
Board: `firestorm`, `scouring_flame`, `immolation`, `cold_appraisal`.
Stops: 5, the thinnest of any starter. That is the deck: Pyre trades defense for tempo, and every
other defensive card in the precon is a lockout. `wall_of_flame` covers Arts and Focused attacks.

### Pyre Ascent, Sir Edric Rooke
Plan: weather the early game on guards that also raise Fervor, then climb.
Bombs: `declaration` (+2 own Fervor, -2 theirs) and `edrics_opening_strike` (Remain 1 for Edric).
Kept: six kinds of guard, most of which raise Fervor as they stop, so defending is progress.
`hasks_flying_kick`, `edrics_training`, the Pyre climbing Strikes. Dame Alder stays as the Ally.
Stops: 12. Board: `immolation`, `firestorm`, `watchful_eye`.
Cut: `dismissal` (would remove Dame Alder too), `rites_unmade`, `respite`, `spoiled_rite`.

### Pyre Attrition, Bram Ashmark (Marked)
Plan: strip their table, out-last them, refill the Life Deck.
Bombs: `spent_to_the_last` (wipes every Non-Combat and Ally in play) and `declaration`.
Kept: `headlong_plunge`, `ashmarks_ember_spray` (Marked Art with recursion), `sword_cleave` with
`vales_sword_draw` to fetch it, `rekindling`, `searing_guard`.
Board: `firestorm`, `scouring_flame`, `immolation`, `cold_appraisal`. Stops: 8, both kinds.

### Freestyle Swords, Caedan Vale
Plan: Drills the Mastery makes permanent, then chained sword signatures.
Bombs: `bravado_drill` and `recalled_lesson` (any attack from Life Deck or discard).
Kept: `swordplay_drill`, `lone_blade_drill` (its self-discard is switched off by the Mastery),
`committed_cut` and `sword_flourish` (each puts a Drill into play), `heirloom_blade`,
`vales_insight`, the Vale signature Strikes. Board: `sword_thrust`, `sword_sweep`, `watchful_eye`.
Stops: 9. Cut: `counterplay_drill`, `no_retreat_drill`, `stillness`, `kept_at_bay` (lockouts).

### Root Seals, Osric Thornwald (45 cards)
Plan: survive and carve all seven Marble Seals.
Bombs: `eyes_beyond_the_gate` (a successful Art puts a Seal into play and captures one) and
`sharp_rebuke` (8 wounds, -3 Fervor).
Kept: all seven Seals, five Seal tutors plus `guardian_drill`, `keepers_drill` x2 so the Seals
cannot be captured. Arts: `root_dragon_blast` (scales with Seals), `destruction_blast`, `root_bolt`.
Stops: 10. Board: `dismissal`, `seal_seizure`, `watchful_eye`.
Cut: `blinding_flare`, `suppressing_shot`, `kins_rescue`, `stillness` (lockouts), `gates_boon`.

### Shade Henchmen, Sable Draik
Plan: a hexer company on the table while the hand is stripped.
Bombs: `black_hands` (Sable only, unpreventable, Remain with two Allies) and `unerring_bolt`.
Kept: Vesna and Brann with their own Strikes, which fetch more Allies on hit; `hired_blades`,
`knife_volley`. Hand: `nightmare_hold`, `oblivion_touch`, `dread_grip`, `mind_rot`.
Board: `sabotage`, `cold_appraisal`. Stops: 9.

### Shade Mind Siege, Gideon Mourne (Marked)
Plan: take their hand, table and options, then finish.
Bombs: `bravado_drill` and `marked_demise` (trades wounds for their Drills).
Kept: the Whisper Strikes with `returning_whisper` to recur them, `sifting_whisper`,
`emptying_whisper`, `shade_faltering_drill`. `wall_of_flame` covers Focused attacks.
Stops: 9. New: this deck had no starter or opponent tiers before today.
Flag: `shade_faltering_drill` (they discard their whole hand at the Discard step) plays close to a
third bomb.

### Shade Salvage, Marrow (Construct)
Plan: a construct crew that makes each other stronger, then Arts.
Bombs: `marrows_retinue` x2 (Marrow only, two Allies into play at full Energy) and `unerring_bolt`.
Kept: Cull and Orvath Kell, `assembly_drill`, `mercy_smiles`. Arts: `rending_palm`,
`cutting_hand`, `umbral_lash`, `threefold_bolt`. Board: `sabotage`, `breakers_yard`,
`rites_unmade`, `spoiled_rite`. Stops: 10. `mourne_takes_measure` answers an Ascension win.

### Steel Heir, Emrys Rooke
Plan: big Draconic Strikes, paid for with life cards.
Bombs: `steel_cross` (a flat 10 Energy Strike) and `declaration`.
Kept: `steel_talon`, `steel_rake`, `steel_reverse`, `stamp` and `tackle`,
`steel_conditioning_drill`, `the_long_year`. Board: `headbutt`, `watchful_eye`, `spoiled_rite`.
Stops: 8, both kinds. Dame Alder stays as the Ally.

### Storm Unbound, Siphon (Construct)
Plan: disruptive Arts while the Mastery keeps them off Strikes.
Bombs: `declaration` and `sun_seal_5`.
Kept: the five-wound Storm Arts, `storm_smiting_bolt`, `corins_conditioning`, Cull and Orvath Kell
with `assembly_drill`. Stops: 10. Cut: `storm_plasma_beam`, `mournes_jolting_arc` (lockouts).

### Storm Volley, Siphon (Construct)
Plan: a barrage of discounted Arts.
Bombs: `storm_thunderhead` (Empower 3, strips Drills) and `storm_maelstrom` (unpreventable for the
rest of Combat).
Kept: `scattered_ashes`, `draiks_reckoning`, `lingering_curse`, `siphons_sidestep` to tutor, two
Sun Seals for draw. Stops: 9. `unerring_bolt` x1 is the 40th card and plays close to a third bomb.

### Tide Companions, Dame Alder Rooke
Plan: Allies out, the Bond, then fight through Allies once the Duelist's Energy is spent.
Bombs: `warding_call` (an Ally into play, their Seals discarded) and `last_gasp` (5 wounds, sets
her own Energy to 0, which is the plan).
Kept: **Tavin Vale and Ansel Rooke, the pair `bonded_pair` fuses**, with `bonding_rite` x2,
`lucky_find` to tutor it, and `rallying_call` and `tide_springwater` to find Allies.
Stops: 8. Board: `drowning`, `rookes_deluge`, `watchful_eye`.
**Correction:** the earlier starter kept Wren and Sir Edric, so its Bonding card had nothing to
fuse. Tide's win condition was dead in the starter and in the generated opponent tiers.
`tools/scale_deck.py` now keeps the Bond pair and the tiers are regenerated.

### Tide Deepwater, Sir Edric Rooke
Plan: hold their Fervor down with every blow and strip what they place.
Bombs: `bravado_drill` and `ashmarks_choke_hold` x2 (drains their Energy every attack phase).
Kept: the Fervor-lowering Tide Strikes, `pull_under` with Moth Seals 3 and 4 for its Remain,
`edrics_opening_strike`. Stops: 7. Cut: `moth_seal_7` (no Mastery, a lockout), `tide_deadweight`,
`tide_deep_anchor`.

## Open

- Three decks hold three or four limit-1 cards beyond their bombs: Root, Tide Companions and Shade
  Salvage run tutors that are printed at limit 1. They are there as tutors, not as bombs, but
  worth a look if those decks play too strong.
- None of these have been playtested. The next step is starter against tier 1 on the ladder.
