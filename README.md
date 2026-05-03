# Gamestorming

A sampler platter of game ideas. Each subfolder is a standalone prototype.

Projects developed with assistance of Claude Opus 4.6

## Games

| Game | Description | Play |
|---|---|---|
| [coinshot](coinshot/) | First-person Mistborn traversal prototype. Push and pull on metal to fly through a city. | [Play in browser](https://fenyn.github.io/Gamestorming/coinshot/) |
| [green-bean](green-bean/) | First-person barista simulator. Take orders, print tickets, and assemble drinks by hand. | [Play in browser](https://fenyn.github.io/Gamestorming/green-bean/) |
| [life-magic](life-magic/) | Idle game powered by your heartbeat. Grow a wizard's garden faster by exercising. | [Play in browser](https://fenyn.github.io/Gamestorming/life-magic/) |
| [mythos](mythos/) | Lane combat card game with city building. Norse mythology meets tactical deckbuilding. | [Play in browser](https://fenyn.github.io/Gamestorming/mythos/) |

## Adding a new game

1. Create a new folder at the root (e.g. `my-game/`)
2. Put the full Godot project inside it (with its own `project.godot`)
3. Add an entry to the `games` matrix in `.github/workflows/build-all.yml`
4. Add a row to the table above
