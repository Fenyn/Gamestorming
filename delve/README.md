# Delve

PF2e roguelite prototype — standalone combat proof extracted from bulwark. Boots straight into a playable HD-2D encounter: 4 preset PCs (fighter, rogue, cleric, wizard) vs 5 goblin warriors on a procedurally generated map, driven by the full Pf2e.Core Remaster rules engine (`F:\dev\Pf2e.Core`). Roguelite meta-layer design comes after this proof.

## Run

```
dotnet build Delve.sln -c Debug
G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe --path G:/Godot/Gamestorming/delve
```

## Spikes

Headless, each prints `SPIKE RESULT: PASS`:

```
...console.exe --path G:/Godot/Gamestorming/delve --headless res://scenes/dev/<name>_spike.tscn
```

for `combat_juice`, `player_turn`, `reaction_dying`, `reaction_prompt`, `spell_cast`, `terrain_spatial`, `ai_stack`, `ai_caster`, `strike_audit`, `chassis`, `class_combo`.
