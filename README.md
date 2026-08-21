# Gamestorming

A sampler platter of game ideas. Each subfolder is a standalone prototype with its own README.

Projects developed with assistance of Claude.

## Games

| Game | Description | Play |
|---|---|---|
| [autobattler](autobattler/) | TFT-style Pathfinder 2e autobattler with a full-fidelity PF2e Remaster rules engine. C#. | — |
| [coinshot](coinshot/) | First-person Mistborn traversal. Steel-push and iron-pull on metal anchors to fly through a city. | [Play in browser](https://fenyn.github.io/Gamestorming/coinshot/) |
| [combat-proto](combat-proto/) | 3D melee combat prototype. For Honor directional stance meets Sekiro posture/deflection. Greybox. | — |
| [delve](delve/) | PF2e roguelite combat proof. HD-2D tactical encounters on generated maps, full Remaster rules engine. C#. | — |
| [drifter](drifter/) | Roguelite dice combat on a barren alien planet. Pixel art cards, physical 3D dice. | — |
| [end-of-the-line](end-of-the-line/) | Logistics incremental with sentient trains. Rail network expansion inside a 3-day time loop. | — |
| [green-bean](green-bean/) | First-person barista simulator. Ring up orders, print tickets, assemble drinks via tactile mini-games. | [Play in browser](https://fenyn.github.io/Gamestorming/green-bean/) |
| [heirloom](heirloom/) | First-person rural life sim in mid-2000s Washington. Pay the land bills, rebuild grandpa's '69 Camaro. | — |
| [life-magic](life-magic/) | Idle game powered by your heartbeat. Tick speed scales with real heart rate. | [Play in browser](https://fenyn.github.io/Gamestorming/life-magic/) |
| [mythos](mythos/) | Lane-combat card game with city building. Norse mythology, summon units, destroy the Grand Lodge. | [Play in browser](https://fenyn.github.io/Gamestorming/mythos/) |
| [redshift](redshift/) | Zero-g Newtonian spaceship time-trial racer. 6DOF flight with ghost replays. | — |
| [skeleton-crew](skeleton-crew/) | 2–4 player co-op roguelike ship sim. First-person, multiplayer, FTL meets friendslop. | — |
| [spacefarm](spacefarm/) | 2D top-down sci-fi farming aboard an alien ship. First-contact survival, crew of 16. | — |
| [the-maw-of-rrrbl](the-maw-of-rrrbl/) | Builder-incremental. Place marble track pieces in 3D, earn Sparks, feed The Maw. | — |
| [war-tactics](war-tactics/) | WWII isometric squad-tactics roguelike. Shooting minigames, permadeath, and medal pickups. | [Play in browser](https://fenyn.github.io/Gamestorming/war-tactics/) |
| [worldseed](worldseed/) | Terraform an alien planet by farming exotic crops. Manage power and deploy nanobot bees. | — |

## Shared code

- [godot-base](godot-base/) — shared addon (state machine, save, audio, input, transitions, UI scaffolding). See its README for the module list and install instructions.
- [designs](designs/) — design documents for game concepts that don't have a project folder yet.

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
