# Gamestorming

A sampler platter of game ideas. Each subfolder is a standalone prototype with its own README.

Projects developed with assistance of Claude.

## Games

| Game | Description | Play |
|---|---|---|
| [autobattler](autobattler/) | TFT-style Pathfinder 2e autobattler running a full-fidelity rules engine. C#. | — |
| [coinshot](coinshot/) | First-person Mistborn traversal prototype. Push and pull on metal to fly through a city. | [Play in browser](https://fenyn.github.io/Gamestorming/coinshot/) |
| [drifter](drifter/) | Roguelite dice combat on a barren alien planet. Pixel art cards, physical 3D dice. | — |
| [end-of-the-line](end-of-the-line/) | Train network management. Route trains, grow the rail graph. | — |
| [green-bean](green-bean/) | First-person barista simulator. Take orders, print tickets, and assemble drinks by hand. | [Play in browser](https://fenyn.github.io/Gamestorming/green-bean/) |
| [heirloom](heirloom/) | Rural Washington life sim. Pay the land bills and rebuild grandpa's '69 Camaro. | — |
| [life-magic](life-magic/) | Idle game powered by your heartbeat. Grow a wizard's garden faster by exercising. | [Play in browser](https://fenyn.github.io/Gamestorming/life-magic/) |
| [mythos](mythos/) | Lane combat card game with city building. Norse mythology meets tactical deckbuilding. | [Play in browser](https://fenyn.github.io/Gamestorming/mythos/) |
| [redshift](redshift/) | Zero-g Newtonian spaceship time-trial racing with ghost replays. | — |
| [skeleton-crew](skeleton-crew/) | 4-player co-op ship sim. Crew one vessel together: fly, fix, and fight. | — |
| [spacefarm](spacefarm/) | Top-down space-station farming. Stardew pacing, Factorio processing chains. | — |
| [the-maw-of-rrrbl](the-maw-of-rrrbl/) | Marble-run builder incremental. | — |
| [war-tactics](war-tactics/) | WWII squad-tactics roguelike. Isometric grid combat with shooting minigames, cover, and overwatch. | [Play in browser](https://fenyn.github.io/Gamestorming/war-tactics/) |
| [worldseed](worldseed/) | Terraform an alien planet by farming exotic crops under O2 and power pressure. | — |

## Shared code

[godot-base](godot-base/) is the shared addon (state machine, save, audio, input, transitions, UI scaffolding). See its README for the module list and how to install it into a project.

## Conventions

- Godot 4.6, GDScript with explicit type annotations (no `:=` with untyped sources)
- Autoloads live in `scripts/autoload/` and never declare `class_name`
- snake_case file names; objects placed in `.tscn` scenes, not spawned from scripts
- Each project is self-contained; cross-project reuse goes through `godot-base`

## Adding a new game

1. Create a new folder at the root (e.g. `my-game/`)
2. Put the full Godot project inside it (with its own `project.godot`)
3. Add a `README.md` and an entry to the `games` matrix in `.github/workflows/build-all.yml` (if web-exportable)
4. Add a row to the table above
