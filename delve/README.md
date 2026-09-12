# Delve

PF2e roguelite prototype, driven by the Pf2e.Core Remaster rules engine. Form a party from four unlocked characters: one player-controlled leader and three AI companions. The leader sets the personal progression focus. Character-specific dialogue POV remains planned content. Follow branching Skirmish, Lair, Happenstance, Campsite and Wayfarer nodes to the Depths Warden. A surviving Wayfarer can replace one companion after victory; temporary membership never grants a permanent unlock. Recruitment requires its authored steps and an explicit overnight stay at the outpost. Recruitment and outpost progress are shared across leaders, while personal progress stays with each leader.

The starter roster is Aldric, Elara, Tharr and Fenwick. Raven and Thistle are locked guests with supported prototype builds. See [roster adaptation](design/roster_adaptation.md) for the Bulwark cast mapping and remaining class/content work. Fights use generated HD-2D battle maps. Surviving members recover downed companions after a win, including the leader. Only a party wipe ends combat in defeat.

The Pf2e.Core data path is the `delve/pf2e_pack_path` project setting in `project.godot`. Point it at this machine's `Pf2e.Core/Data/pf2e-source/packs/pf2e` folder.

## Run

Enemy art preview: open `scenes/dev/enemy_sprite_preview.tscn` and press F6 to play a fight against a rat, goblin, kobold, and wolf. The new bases use breathing and blink idles; rats keep their existing animation. Per-sprite clips, timing, and placement are authored in [enemy sprite resources](assets/sprites/enemies/README.md).

```
dotnet build Delve.sln -c Debug
G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe --path G:/Godot/Gamestorming/delve
```

The main scene is `scenes/run/run.tscn`. `scenes/dev/combat_test.tscn` stays as the single-fight harness.

## Spikes

Enemy animation checks: `enemy_sprite_spike` (headless). Rendered mixed-species checks and a close-up: `enemy_sprite_shot_spike` (without `--headless`). Both use the invocation pattern below.

Headless, each prints `SPIKE RESULT: PASS`:

```
...console.exe --path G:/Godot/Gamestorming/delve --headless res://scenes/dev/<name>_spike.tscn
```

for `combat_juice`, `player_turn`, `encounter_reset`, `reaction_dying`, `reaction_prompt`, `spell_cast`, `terrain_spatial`, `terrain_cliff`, `terrain_skirt`, `terrain_skirt_render`, `elevation_move`, `ai_stack`, `ai_caster`, `ai_caution`, `ai_tactics`, `strike_audit`, `chassis`, `class_combo`, `run_map`, `run_recovery`, `run_short_rest`, `run_event`, `run_encounter`, `run_flow`, `run_meeting`, `hero_select`, `party_control`, `campaign_progress`, `combat_log`.

`combat_shot` captures the board, `ui_shot` captures formation and recruitment screens, `meetup_shot`
captures the guest replacement screen, and `run_map_shot`
captures the run map fresh and mid-run, and `terrain_skirt_shot` captures top-down and oblique
views of the skirted terrain per biome and seed. All five need a real window, so they run
WITHOUT `--headless`:

```
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/combat_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/ui_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/meetup_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/run_map_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/terrain_skirt_shot_spike.tscn
```

They write their PNGs to `user://dev_shots` and print each file's OS path.

Movement: with no action selected the board shows the active unit's reach as bands, one colour per action the move costs, green where a Step reaches safely. Hover a tile for the route and its cost pips, click to move. C re-centres the camera on the active unit; WASD pans and stops the camera following until the next turn.

Combat log: click an action or its + button to expand its details in place. L or More history opens the sidebar. Expanded entries stay visible as new actions arrive; Jump to latest resumes following the log.
