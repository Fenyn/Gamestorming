# Timberline

A first-person lumberjack game that is part simulation, part incremental. Start with an axe, a cabin, and a forest plot: fell trees with repeated chops, delimb and buck them by hand, split logs into firewood, and carry it all to the roadside bin to sell. Every stage of the chain is physical — and every stage can be upgraded and automated, ending with logs rolled into the river and a waterside sawmill doing the rest. The clearing you carve out of the forest is the progress bar.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** design + scaffold — no gameplay yet. See the full design doc at [`designs/timberline.md`](../designs/timberline.md).
- **Run:** Open `timberline/project.godot` in Godot 4.6 and press F5. (Currently an empty greybox ground plane.)

## Planned controls

- WASD — move, Space — jump, mouse — look
- Left click — chop / pick up / place / primary action
- Right click — drop / toss
- E — interact with stations and the cabin catalog

## Notes

- Diegetic, tactile design in the green-bean tradition: wood is physics objects you carry, not inventory counters. No timers, no stamina — a zen sandbox paced by the incremental economy.
- Uses the shared `godot_base` addon (`addons/godot_base`).
- Planned structure follows green-bean's layout: `scenes/{player,items,stations,ui}`, `scripts/{autoload,player,trees,stations,items,data}`.
