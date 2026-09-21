#!/bin/bash
i=$1
GODOT="G:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe"
"$GODOT" --headless --path zenith -s tests/matchlab.gd --   --mode=sample --games=700 --seed=11   --a=search --a-branch-margin=0.5 --b=search --b-branch-margin=0   --budget=150 --samples=1 --field="freestyle_swords,pyre_ascent,pyre_attrition,pyre_beatdown,root_seals,shade_henchmen,shade_mind_siege,shade_salvage,steel_beatdown,steel_heir,storm_unbound,storm_volley,tide_companions,tide_deepwater"   --shard=$i/12 --json=res://../reports_ab/shard_$i.json >/dev/null 2>&1
