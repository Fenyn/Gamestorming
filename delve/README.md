# Delve

PF2e roguelite prototype, driven by the full Pf2e.Core Remaster rules engine. The game boots into a run: pick one starting character from the roster, then climb a branching node map of Skirmish, Lair, Happenstance and Campsite nodes to the Depths Warden. The run starts with that character alone and the party grows to four as companions join; where the companions come from is not designed yet. Fights play out in the HD-2D combat scene on a generated battle map. A downed PC leaves the field at 1 HP and keeps its Wounded value, so only a full wipe ends a run. The framework is a skeleton: one enemy, one event and no rewards yet. Rat sprites stand in for every enemy — the only combat art that exists is the rat family (see `scripts/data/EnemySpriteMap.cs`).

The Pf2e.Core data path is the `delve/pf2e_pack_path` project setting in `project.godot`. Point it at this machine's `Pf2e.Core/Data/pf2e-source/packs/pf2e` folder.

## Run

```
dotnet build Delve.sln -c Debug
G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe --path G:/Godot/Gamestorming/delve
```

The main scene is `scenes/run/run.tscn`. `scenes/dev/combat_test.tscn` stays as the single-fight harness.

## Spikes

Headless, each prints `SPIKE RESULT: PASS`:

```
...console.exe --path G:/Godot/Gamestorming/delve --headless res://scenes/dev/<name>_spike.tscn
```

for `combat_juice`, `player_turn`, `encounter_reset`, `reaction_dying`, `reaction_prompt`, `spell_cast`, `terrain_spatial`, `terrain_cliff`, `terrain_skirt`, `terrain_skirt_render`, `elevation_move`, `ai_stack`, `ai_caster`, `strike_audit`, `chassis`, `class_combo`, `run_map`, `run_recovery`, `run_short_rest`, `run_event`, `run_encounter`, `run_flow`, `hero_select`.

`combat_shot` captures the board, `ui_shot` captures the run's menu screens, `run_map_shot`
captures the run map fresh and mid-run, and `terrain_skirt_shot` captures top-down and oblique
views of the skirted terrain per biome and seed. All four need a real window, so they run
WITHOUT `--headless`:

```
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/combat_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/ui_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/run_map_shot_spike.tscn
...console.exe --path G:/Godot/Gamestorming/delve res://scenes/dev/terrain_skirt_shot_spike.tscn
```

They write their PNGs to `user://dev_shots` and print each file's OS path.
