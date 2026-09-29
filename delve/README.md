# Delve

PF2e roguelite prototype, driven by the Pf2e.Core Remaster rules engine. Form a party from four unlocked characters: all four are player-controlled, with no leader slot. When a system needs one character, it makes a seeded random choice from the assembled party. Character-specific dialogue POV remains planned content. Explore connected dungeon rooms through Skirmish, Lair, Happenstance, Campsite and Wayfarer encounters to the Depths Warden. A surviving Wayfarer can replace one companion after victory; temporary membership never grants a permanent unlock. Recruitment requires its authored steps and an explicit overnight stay at the outpost. Recruitment and outpost progress are shared across the campaign, while personal progress stays with each character.

The starter roster is Aldric, Elara, Tharr and Fenwick. All fourteen other Bulwark characters are locked, meetable recruits with native class builds and signature combat actions. See [roster adaptation](design/roster_adaptation.md) for the builds and current rules coverage, and [level 1-10 feat tracks](design/roster_feats.md) for class-feat selections. Run `roster_feat_spike.tscn` to verify progression; `roster_feat_combat_test.tscn` previews a level-10 party. Test them directly in `scenes/dev/wayfarer_combat_test.tscn`; `PreviewParty` selects catalog IDs without changing campaign unlocks. Fights use generated HD-2D battle maps. Surviving members recover downed companions after a win. Only a party wipe ends combat in defeat.

The Pf2e.Core data path is the `delve/pf2e_pack_path` project setting in `project.godot`. Point it at this machine's `Pf2e.Core/Data/pf2e-source/packs/pf2e` folder.

## Run

Enemy art preview: open `scenes/dev/enemy_sprite_preview.tscn` and press F6 to play a fight against a rat, goblin, kobold, and wolf. The new bases use breathing and blink idles; rats keep their existing animation. Per-sprite clips, timing, and placement are authored in [enemy sprite resources](assets/sprites/enemies/README.md).

```
dotnet build Delve.sln -c Debug
G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe --path G:/Godot/Gamestorming/delve
```

The main scene is `scenes/run/dungeon_run.tscn` (F5). The original node-map run remains at `scenes/run/run.tscn` (F6). `scenes/dev/combat_test.tscn` stays as the single-fight harness.

Dungeon experiment: open `scenes/dungeon/dungeon_test.tscn` and press F6 for a separate twelve-room crawl. Each room prefab generates its own terrain and decoration variants. Resolve the room, then click a door; all crossings, including backtracking, drain ward. `scenes/dungeon/combat_comparison.tscn` compares 12/14/16 tile rooms, open/pillared layouts, and entry directions. See [dungeon authoring and verification](scenes/dungeon/README.md). This standalone test does not write campaign saves.

Party selection takes place at the outpost campfire. Select any four seated residents to assemble the party. Selected residents rise into a ready stance with their character-colored outline; clicking them again removes them. Every selected resident toggles independently. Clear party removes all selections. Up/Down previews residents; confirm selects or removes the focused resident. Character details opens the full sheet, and Escape returns to camp. Permanent recruits appear at stable camp positions as they unlock. Recruitment retains its explicit overnight-stay requirements.

## Spikes

Promotions: XP now marks characters for promotion without applying the level.
Open their sheet from results, a dungeon character, or a node-map party entry.
In Progression, select a feat and confirm to apply one level. Closing the sheet
does not spend the choice. Confirm pending promotions before the next fight.
The first version uses existing playable feats; if none is eligible, an explicit
promotion keeps the unspent feat choice for later. Starting builds still use
the level-2 presets. Full prefab trees and level-1 setup remain separate work.
`promotion_spike` checks queued levels, selection, cancellation, resources,
duplicate rejection and all 18 characters through level 10. Run it rendered to
capture `.godot/promotion_sheet.png`.

Enemy animation checks: `enemy_sprite_spike` (headless). Rendered mixed-species checks and a close-up: `enemy_sprite_shot_spike` (without `--headless`). Both use the invocation pattern below.

Headless, each prints `SPIKE RESULT: PASS`:

```
...console.exe --path G:/Godot/Gamestorming/delve --headless res://scenes/dev/<name>_spike.tscn
```

for `combat_juice`, `player_turn`, `encounter_reset`, `reaction_dying`, `reaction_prompt`, `spell_cast`, `terrain_spatial`, `terrain_cliff`, `terrain_skirt`, `terrain_skirt_render`, `elevation_move`, `ai_stack`, `ai_caster`, `ai_caution`, `ai_tactics`, `strike_audit`, `chassis`, `class_combo`, `run_map`, `run_recovery`, `run_short_rest`, `rest_presentation`, `run_event`, `run_encounter`, `run_flow`, `run_meeting`, `hero_select`, `party_control`, `campaign_progress`, `combat_log`, `target_click`, `move_chain`, `delay_turn`, `focus`, `theme_lint`, `pause_menu`, `knowledge_journal`, `movement_conditions`.

Movement conditions: Grabbed, Restrained and Immobilized allow no move actions, so Move is unavailable and the hint reads "Immobilized: cannot move". A prone hero gets 5 ft Crawl bands, the hint "Prone: Crawl 5 ft or Stand", and a Stand chip first on the signature row. A grabbed hero gets an Escape chip. `movement_conditions_spike` checks these and that a grabbed or prone AI never Strides.

Knowledge journal: species are listed when they enter a fight; each Recall Knowledge success reveals the next field (two on a critical success). The journal lives in the campaign save. J or the log heading's Journal button opens the fight's creatures; the outpost's Bestiary button lists the campaign's whole creature pool, with unmet species as dark silhouettes named "???". `knowledge_journal_spike` checks the reveal order, the save round trip, a version 1 save, masking, the locator lifetime and the met and unmet bestiary pages; run it rendered for `knowledge_journal_combat.png`, `knowledge_journal_bestiary.png` and `knowledge_journal_bestiary_unmet.png`.

Delay: a Delay may return after anyone still to act this round or anyone acting next round before the delayer's own slot, so the last actor of a round can Delay too.

Pause menu: Esc opens Resume, Controls, Options and Quit at the outpost, in exploration and in combat once nothing else takes Esc (a dice beat skips, or a flyout, a targeting pick, a modal, a tooltip or an outpost pick closes first). It pauses the tree and freezes combat at once. Options (fullscreen, dice reveal) persist to `user://settings.cfg`. `pause_menu_spike` checks precedence, pausing, a 2 s freeze mid enemy turn, the modal stack, persistence to its own spike file and the quit confirmation; run it rendered for `pause_menu*.png`.

Exploration: the room banner sits top centre, the Ward and goal panel top right, the party face cards along the bottom and the round floor plan bottom right. The parchment party menu (Camp F, Potion P, Rest R, Stairs G) opens beside the party. Tab or the arrow keys cycle the doors and Enter travels; the door tooltip shows the destination, "Ward 35 → 30" and any warning. A party wipe goes straight to the run end. Victory, rest and morning results read as before → after pairs, one row per changed hero, with Choose feat on pending promotions.

`combat_shot` captures the board, `ui_shot` captures formation and recruitment screens, `meetup_shot`
captures the guest replacement screen, and `run_map_shot`
captures the run map fresh and mid-run, and `terrain_skirt_shot` captures top-down and oblique
views of the skirted terrain per biome and seed, and `resolution_sweep` sets the window to
1280x720, 1920x1080 and 2560x1440 and checks the camp, the combat HUD and the short rest modal
at each size. All six need a real window, so they run WITHOUT `--headless`:

```
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/combat_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/ui_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/meetup_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/run_map_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/terrain_skirt_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/resolution_sweep_spike.tscn
```

They write their PNGs to `user://dev_shots`, or to `DELVE_SHOT_DIRECTORY` when it is set, and
print each file's OS path.

Movement: Move (M) shows the active unit's reach as bands, one colour per action the move costs, green where a Step reaches safely. Hover a tile for the route and its cost pips, click to move; the board clears after the move or on cancel. Z and X turn the camera a quarter turn. C re-centres the camera on the active unit; WASD pans and stops the camera following until the next turn.

Combat UI (FFT layout, 2026-09-28): a numbered portrait timeline runs up the left edge from the actor (1); the same numbers sit beside each unit's HP plate on the board, and clicking a hero's tile focuses them. The unit card at the bottom left shows the hovered unit, else the actor, with HP, AC, conditions, action pips and the reaction. The parchment command menu floats beside the active unit (Move, Strike, Shield, Spells, Abilities, Delay, End Turn, Control), closes while a tile or target is picked or an action plays, and opens sub-menus to its side. The forecast sits at the bottom centre and the defender card at the bottom right. An instruction pill at the top centre and key hints at the bottom right follow the turn mode; the hovered tile's height and surface show at the top right above the log. On enemy turns the attacker card takes the bottom left and the target card the bottom right, with the roll row over the reaction prompt between them. Control opens the AI and automatic reaction preferences, Plan orders and Overview. Escape closes an open menu. The board marks only Dying; the forecast and the roll row name the modifiers conditions apply. `combat_shot_spike` checks the zones, the clear board box, the screen budget and the condition markers.

Combat log: the compact panel under the initiative list shows three recent actions, result first with short enemy names ("CRIT 29 vs 17  Aldric → Spider A  18 slashing"), wrapping to a second line only between figure groups. Strides stay in history. Click an action to expand its details in place. L or the panel heading opens full history with full names, including turn headings and strides. Expanded entries stay visible as new actions arrive; Jump to latest resumes following the log. See [the combat UI review](design/combat-ui-review/review.md) for the rationale and visual comparisons.

Short rest now submits one activity per living character for a shared ten-minute window.
Treat Wounds selects a healer and patient; Repair Shield selects a worker and shield owner.
The schedule spends ward once. Invalid or duplicate assignments spend nothing.
`rest_presentation_spike` checks the schedule UI, HP refresh, the condition marks and the Dying badge;
run it with rendering enabled to save previews under `.godot/`.
Condition markers use the supplied P2eConditionMarkers pack in `assets/ui/conditions`. HUD rows use 22 px tiles baked from it (bone on a dark tile, Palette colours): re-run `python tools/art/bake_condition_tiles.py` after a palette change.

The default game (F5) now runs `scenes/run/dungeon_run.tscn`: select a party, explore rooms,
resolve encounters, and descend through all three floors. It shares XP, recovery, recruitment,
campaign progress, and the run summary with the original run flow.
The original node-map mode remains at `scenes/run/run.tscn` (F6); its scenes and generator remain available.
`dungeon_run_spike` checks hosted combat and rewards, recruitment, floor transitions, and run restart.
The standalone `scenes/dungeon/dungeon_test.tscn` remains available for room-generation tests.

Combat signature abilities: up to three character-defining shortcuts appear above the action bar.
Abilities (E) opens Character and General groups; spell shortcuts with variants open their cost choices.
Unavailable shortcuts keep their positions and explain the restriction on hover.
Run `res://scenes/dev/ability_audit_spike.tscn` headless to check roster coverage, live progression,
Double Slice, Marshal Stance, Treat Condition, and shortcut routing.
See [the ability review](design/combat_ability_discoverability.md) for the authored defaults.

Presentation: combat victories ease back into the exploration camera. Results report recovered
companions and new level features, spells, and slots; Character details opens the current party sheet.
Wayfarers are named during the combat intro, with a departure/joining notice after the swap decision.
Departure, descent, and return to the outpost use short chapter fades. Campsite nights show a morning
report with actual HP and ward recovery. Expedition summaries include recruitment and campaign gains;
the outpost journal highlights companions ready for an explicit overnight invitation.

`run_presentation_spike` checks these summaries and dungeon rest/return wiring headless. Run it with
rendering enabled to check fade cancellation and capture reward, campaign, and morning previews under
`.godot/polish_*.png`. Rendered `dungeon_run_spike` also exercises the combat camera return.
