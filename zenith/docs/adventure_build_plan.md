# Adventure build plan

Tracking doc for building the story-mode adventure in `designs/zenith_adventure.md` (sections 4,
7 and 8). Started 2026-09-23. Update the status column as work lands, and add the date and the
test count when a step closes.

Status: `todo`, `doing`, `done`, `blocked` (the reason goes in the notes).

## Placeholder rule for lore

The character links (ally, rival, nemesis, unlock chain) are being written in a separate session.
Until they land, **every lore-driven choice is picked at random from the legal pool**, seeded per
run, and marked in code and data with `# LORE: placeholder, make lore-relevant` (or a `"lore":
"placeholder"` field in JSON). When the links arrive, search for that marker and replace the
random pick with a table lookup. This covers:

- who a key character node puts you against, and the act 1 and act 2 bosses
- which character joins at an Ally encounter
- which character a finish unlocks, and the order of the unlock chain
- story text on nodes, which stays empty

## Phase 1: the node map

The spine. Everything else hangs off it.

| # | Task | Status | Notes |
|---|---|---|---|
| 1.1 | Map data model in `adventure/` (RefCounted): acts, tiers, nodes, edges, node type, seeded from `run.run_seed` | done | 2026-09-23, `adventure/adventure_map.gd`, numbers in `data/adventure/map.json`. Never saved: the seed rolls the same map |
| 1.2 | Map generator: tiers 1 to 7 of each act with random node connections, tier 8 a single boss node; Sensei forced early in act 1; Quarr is the act 3 boss | done | 2026-09-23. 4 lanes, 4 walks, about 19 nodes an act. Fight chance 0.55 gives paths of 2 fights 8%, 3 or 4 fights 72%, 5 fights 20%. Twist and Encounter weights are 0 until phase 3. A run of `steel_beatdown` gets a random final boss until 6.7 |
| 1.2a | Key character node type | done | 2026-09-23. Random opponent from the act's band, marked `# LORE` |
| 1.3 | Run state: current node, path taken, save version bump | done | 2026-09-23. `node_id`, `path`, status `map`; `stage` counts duels won. Save version 5; an older save is dropped (user, 2026-09-23) |
| 1.4 | Replace `AdventureLadder` / `pipeline.json` as the source of duels, keeping tier, band and AI level per duel node | done | 2026-09-23. Deck-id helpers moved to `AdventureDecks`. Motes per duel 20 / 30 / 40 by act, per boss 40 / 60 / 80, completion 50. Reward tier gates read map progress |
| 1.5 | Map screen replacing `TournamentRoute`: nodes, paths, the next opponent visible, node icons | done | 2026-09-23. The map fills the screen: a scrolling board of all three acts beside a full-height side panel holding the run's standing (deck, act, duels won, Motes) over the picked node's preview; the run's Duelist portrait stands on the map as the player's token. Redone in Kenney the same day (user): a dark Kenney-framed board, nodes as Kenney Board Game Icons on dark stepped-corner tiles (the boss on the Double-style rule), a Kenney double rule between acts, framed act tags, Kenney corner brackets for here and scouted, dashed roads (trim tint where walked, red where open), and one badge left for an Aspect grant. The parchment board, the Isle of Lore hex terrain backdrop and its markers and flairs are gone. Art comes in through `tools/import_map_art.py`; sources and licences are in `assets/adventure_map/SOURCES.md` |
| 1.6 | `Session` flow: map, then node, then back to the map; settle on a win or a loss | done | 2026-09-23, `Session.enter_node`. Non-fighting nodes are passed through until phases 2, 4 and 5 |
| 1.7 | `tests/adventure_lab.gd` walks the map, picking paths at random | done | 2026-09-23. Adds a table per act and node type |
| 1.9 | Opponents never share the run's own character | done | 2026-09-23. Random draws skip every family whose Duelist is the run's character (`AdventureDecks.same_character_families`). A storyline's set boss may still be the same character |
| 1.10 | The bundle pool runs dry on long runs | todo | Found 2026-09-23: in an all-wins run, most starters have no eligible bundle from about the 11th to 13th duel on, because copy limits and taken bundles use up the pool. Runs now reach 18 duels. Ties in with 2.6 and 2.7 and with pool expansion (design doc 4.6) |
| 1.8 | Tests for the generator (fixed rows present, every path reaches the boss, same seed gives the same map) | done | 2026-09-23, three `test_adventure_map_*` tests. After 1.3 to 1.7 the suite is at 61157 checks, 0 failures; `sanctum_ui_smoke.gd` 38 checks, 0 failures |

## Phase 2: simple nodes

| # | Task | Status | Notes |
|---|---|---|---|
| 2.1 | Duel node on the map | todo | Existing duel flow |
| 2.2 | Elite node: a stronger band and a better reward | todo | What "better reward" means needs a number; propose one when building |
| 2.3 | Forge node: cut cards, add copies of cards already in the deck | todo | Cut exists (`AdventureRewards.apply_cut`) |
| 2.4 | Mana: run wallet, income per duel, spend API | todo | Income numbers pending the user |
| 2.5 | Shop node: stock roll, buy with Mana | blocked | What it sells and the prices are pending the user. Can reuse the vendor's shelf logic |
| 2.6 | Run deck size cap: starter size plus bought slots, plus per-run boosts up to a limit | todo | User, 2026-09-23. Where boosts come from, how big they are and the limit are not set yet; propose numbers when building |
| 2.7 | Run library: won cards outside the deck, saved with the run; a won card past the cap lands there | todo | Design doc 4.7. Settlement counts library cards as run gains |
| 2.8 | Library screen on the map: swap between Life Deck, library and Reserve, validated | todo | Replaces 4.6 as the place Reserve swaps happen |

## Phase 3: duel setup options

One per-duel options block passed from `Session` to the engine at setup, each with its own test.

| # | Task | Status | Notes |
|---|---|---|---|
| 3.1 | Setup options plumbing: `Session.build_referee` to `DuelEngine`, like `set_lives` | todo | |
| 3.2 | Guest Ally: a personality card placed in play on the player's side at setup, not part of the run deck | done | 2026-09-23, `DuelEngine.set_guest_ally`, called from `Session.build_referee`. Skips the alignment rule; every guest listed today matches its main's side |
| 3.3 | Ally encounter node using 3.2 | done | 2026-09-23. Encounter weight 10. The guest is drawn from the starter's `guests` in `data/adventure/storylines.json`; a starter with none (Ashmark, and every starter without a storyline) gets a plain duel instead |
| 3.4 | Twist: opponent starts with a Drill or Grounds in play | todo | |
| 3.5 | Twist: opponent opens at Fervor 3 | todo | |
| 3.6 | Twist: survival-only duel, `set_points_options` with Ascension and Seal points off | todo | Needs a real name from the user |
| 3.7 | Overkill counter and knockout prize for 3.6 | blocked | Threshold and prize pending the user |
| 3.8 | AI check: `tests/ai_arena.gd` with a guest Ally and each twist | todo | |

## Phase 4: Sensei and the Reserve

| # | Task | Status | Notes |
|---|---|---|---|
| 4.1 | Run holds a Relic and a Reserve; save, loadout and `Session.build_referee` carry them | todo | Starters have none, except `tide_companions` |
| 4.2 | Reserve bundle group in `bundles.json`: counter tech sorted by the archetype it answers | todo | Data work; source from `docs/archetypes.md`. Lockouts stay out |
| 4.3 | Sensei offers: Relic plus about five school-themed Reserve cards, one of three, once per run | todo | |
| 4.4 | Sensei node screen | todo | |
| 4.5 | Reserve bundles offered on reward screens as an option pack | todo | |
| 4.6 | Reserve side of the library screen (2.8), usable once the next opponent is shown | todo | |
| 4.7 | More Relics, each paralleling a printed Sensei card | todo | Only 4 exist. Source check and names need user approval |

## Phase 5: Resonances

| # | Task | Status | Notes |
|---|---|---|---|
| 5.1 | Engine: run-owned hidden Drill, cannot be discarded or removed, survives ascending | todo | |
| 5.2 | Resonance data, starting with the examples in the design doc | todo | Guard: nothing that touches the Ascension or MPPV win |
| 5.3 | Shrine node: pick one of three | todo | |
| 5.4 | Resonance display in the duel HUD | todo | |

## Phase 6: unlocks and missions

| # | Task | Status | Notes |
|---|---|---|---|
| 6.1 | Unlock save file (`user://adventure/unlocks.json`) and `playable_starters()` filtered by it | done | 2026-09-23, `AdventureUnlocks`. The start screen lists `Session.unlocks.available_starters()`; `playable_starters()` still lists every file, for tests and tools. Dev flags `--dev-unlock-all`, `--dev-unlock-reset` on the start screen |
| 6.2 | Starting three open: `tide_deepwater`, `shade_mind_siege`, `pyre_beatdown` | done | 2026-09-23, `open` in `storylines.json` |
| 6.3 | Remove the dead `"unlock"` field from the five setup starters | todo | |
| 6.4 | Finish-a-run unlock: next character | done | 2026-09-23, replaced by quests (`data/adventure/quests.json`, `AdventureQuests`): act 2 bosses open Caedan, Sable and Ember Ascendant; act 1 boss then a finished run opens Steel Inheritance, Scrap Requiem and Last Standing. The second steps are placeholders |
| 6.4a | Storyline act bosses and act 1 joins | done | 2026-09-23, `AdventureStory`: set act 1 and 2 bosses for the three starters; beating Edric's act 1 boss adds Emrys to the run deck, Mourne's adds Kell. The reward screen's footer names who joined and what unlocked |
| 6.5 | Second-deck unlocks for Edric, Bram and Siphon | todo | |
| 6.6 | Quarr unlock | blocked | Rule pending the user |
| 6.7 | Quarr's own run: final boss | blocked | Pending the user |
| 6.8 | Mission data model and tracking during runs | doing | 2026-09-23: quests track `boss_won` and `run_won` only. More conditions wait on the quest design with the user |
| 6.9 | Pool unlocks: Relics, Resonances, Grounds | todo | |
| 6.10 | Personality variant unlocks from encounters and quest nodes | todo | Each variant needs a printed source card first |
| 6.11 | Harder difficulty after a first clear | todo | |
| 6.12 | Gallery and epilogue screens | todo | Epilogue text needs tone approval |

## Phase 7: balance

| # | Task | Status | Notes |
|---|---|---|---|
| 7.1 | Lab sweep over the map for the starting three | todo | After 1.7 |
| 7.2 | Final boss tuning for `steel_beatdown` | blocked | Target win rate pending the user. It won 16 of 20 boss stages in the last lab |
| 7.3 | `pyre_beatdown` as a first-run deck (4.8 stages cleared) | todo | |
| 7.4 | Opponent bands for the map's node types | todo | |

## Expansion, not scheduled

- True 2v2 team duels. Large engine pass, the engine assumes two seats throughout.
- Mystery event nodes. Need writing and tone approval.

## Art library

`F:\UnityNVME\Art` holds packs usable for textures and icons. Check each pack's licence file
before shipping anything from it.

| Pack | Path | Likely use |
|---|---|---|
| Ornate Fantasy UI Assets v1.3 | `Sprites\Ornate Fantasy UI Assets v1.3` | Panels, frames and buttons for the map and node screens |
| Isle of Lore 2 hex tiles | `Sprites\HexMaps` | Not used since 2026-09-23 (terrain and markers dropped for Kenney) |
| Kenney Board Game Icons (CC0) | `Sprites\UI\kenney_board-game-icons` | Map node icons and the Aspect-grant badge |
| 2D Medieval Backgrounds Pack | `Backgrounds\2D Medieval Backgrounds Pack` | Act backdrops, at 320x180 up to 1920x1080 |
| Nature Landscapes, Free Pixel Art Forest | `Backgrounds\Nature Landscapes Free Pixel Art`, `Sprites\Background\Free Pixel Art Forest` | Act backdrops |
| P2e condition markers | `Sprites\P2eConditionMarkers` | 64 small icons, candidates for twist and node icons |
| Fonts | `Fonts` (Alagard, Knightwood, Pixeloid, PixelBastarda, Compass) | Map and title text |
| Medieval Music Pack, The Old Kingdom | `Music\Medieval Music Pack The Old Kingdom` | Map and menu music, with a licence PDF |
| PolyBlocks EffectBlocks | `GodotVFX` | Duel VFX, see `docs/polyblocks/` |
| Palettes | `Palette` | Colour matching |

`_Zenith` looks like collected reference images from the web. Treat it as reference only, not as
assets.
