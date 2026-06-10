# War Tactics

WWII isometric squad-tactics roguelike: a mysterious fog separates your squad
from the front line, and every shot is a small skill-check minigame. Permadeath,
medal pickups, and a forward base between battles.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** playable
- **Run:** Open `war-tactics/project.godot` in Godot 4.6 and press F5.

## Controls

- **Left click** — select unit / move / attack
- **Right click / Esc** — cancel targeting, deselect
- **Space** — end turn
- **Tab** — cycle to next unit
- **G** — grenade targeting
- **O** — overwatch targeting
- **Q / E** — rotate view
- **Mouse wheel** — zoom

## Notes

- Playable in browser at https://fenyn.github.io/Gamestorming/war-tactics/.
- Hit resolution via skill-check minigames: wobbly-cursor (rifle) and timing-bar (sniper).
- 2D isometric on a 64x32 diamond grid with greybox placeholder art; final sprites from a collaborating artist.
- Uses the shared `godot_base` addon; 5 autoloads (EventBus, RunState, MetaState, Database, Grid).
