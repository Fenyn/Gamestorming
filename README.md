# Gamestorming

A sampler platter of game ideas. Each subfolder is a standalone prototype.

## Games

| Game | Description | Play |
|---|---|---|
| [coinshot](coinshot/) | First-person Mistborn traversal prototype. Push and pull on metal to fly through a city. | [Play in browser](https://fenyn.github.io/Gamestorming/coinshot/) |

## Adding a new game

1. Create a new folder at the root (e.g. `my-game/`)
2. Put the full Godot project inside it (with its own `project.godot`)
3. Add an entry to the `games` matrix in `.github/workflows/build-all.yml`
4. Add a row to the table above
