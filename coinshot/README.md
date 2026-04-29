# Coinshot

A first-person traversal prototype inspired by Brandon Sanderson's *Mistborn* — push and pull on metal anchors, drop coins to launch yourself off the ground.

## Run

1. Install [Godot 4.6 stable](https://godotengine.org/download/) (4.4+ should also work).
2. Open this folder in Godot (`Import` → select `project.godot`).
3. Press **F5** to play.

## Controls

| Action | Binding |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Jump | Space |
| **Push** (steel) | Left mouse |
| **Pull** (iron)  | Right mouse |
| **Drop coin** (vertical launches) | Q |
| **Toss coin** (horizontal dashes) | F |
| Burn intensity | Mouse wheel |
| Toggle mist-vision | Tab |
| Respawn (clears coins, resets position) | R |
| Quit | Esc |

## What this prototype demonstrates

- **Sense-through-walls metal vision** (blue lines) — lines penetrate geometry like a sixth sense.
- **Newton's-3rd push/pull** — light coins fly, heavy crates kick the player, anchored girders fling the player.
- **Coin shots** — drop a coin and immediately push to launch yourself; toss-and-push for forward dashes.
- **Mass-coded line thickness** — heavier anchors render brighter, like the books' "thick as yarn".

## Scope

Traversal core only — no combat, no enemies. See `/root/.claude/plans/let-s-put-together-a-spicy-leaf.md` for the full plan and lore-accuracy notes.
