```
                                        .
                                       /|\
                                      / | \
                                     /  |  \
                                    /   |   \
                              .----'    |    '----.
                             /          |          \
                 ___________/___________+___________\___________
                |           |     . ~ ~ ~ ~ ~ .     |           |
                |           |   ~   T H E   ~   |           |
                |     ||    | ~  M I S T S  ~  |    ||     |
                |     ||    |   ~   A R E   ~   |    ||     |
                |     ||    |     ~ Y O U R S ~     |    ||     |
                |     ||    |       ~ ~ ~ ~ ~       |    ||     |
                |     ||    |           |            |    ||     |
                |     ||    |          /|\           |    ||     |
                |     ||    |         / | \          |    ||     |
           _____|_____||____|________/__|__\_________|____||_____|_____
          /     |     ||    |       /   |   \        |    ||     |     \
         /      |     ||    |      /    |    \       |    ||     |      \
        /  .    |     ||    |     / --- + --- \      |    ||     |    .  \
       / /|\ . |     ||    |    /      |      \     |    ||     | . /|\ \
      / / | \  |     ||    |   /  C O I N S H O T   |    ||     |  / | \ \
     /./  |  \.|_____||----|--/--------|--------\----|----||_____|./  |  \.\
    //    |    \\     |    | /         |         \   |    |     //    |    \\
   //____ | ____\\____|____|/_________/ \_________ \|____|____//_____|_____\\
  ========+========================================================================
          |       ~ . ~ push ~ . ~ pull ~ . ~ fly ~ . ~
          |
     _____|_____
    |           |
    | STEEL     |      A Mistborn traversal prototype
    | PUSHING   |      Push and pull on metal anchors.
    |           |      Drop coins. Defy gravity.
    | IRON      |
    | PULLING   |      Built in Godot 4.6 with Jolt Physics.
    |___________|
```

# Coinshot

A first-person traversal prototype inspired by Brandon Sanderson's *Mistborn* — push and pull on metal anchors to fly through a dark, ash-choked city.

## Run

1. Install [Godot 4.6 stable](https://godotengine.org/download/) (4.4+ should also work).
2. Open this folder in Godot (`Import` → select `project.godot`).
3. Press **F5** to play.

## Controls

| Action | Binding |
|---|---|
| Move | W A S D |
| Look | Mouse |
| **Lock target** | Left mouse (hold) |
| **Add anchor** | Right mouse (while locked) |
| **Push** (steel) | Space |
| **Pull** (iron)  | E |
| **Drop coin** | Q |
| **Coinshot** (fire coin forward) | F |
| Burn intensity | Scroll wheel |
| Toggle mist-vision | Tab |
| Respawn | R |
| Switch levels | \[ / \] |
| Quit | Esc |

## Levels

| # | Name | Teaches |
|---|------|---------|
| 1 | **The Ash Yard** | Lock, push, pull, multi-target, push+pull combo |
| 2 | **The Iron Arches** | Slingshot maneuvers — push a wall, pull an arch to curve mid-flight |
| 3 | **The Steel Run** | High-speed pull chains and momentum redirection |
| 4 | **The Crucible** | Multi-target hovering, burn control, moving anchor tracking |
| 5 | **The Black Spire** | Everything combined in a vertical ascent |

## What this prototype demonstrates

- **Sense-through-walls metal vision** — blue lines penetrate geometry like a sixth sense. Heavier anchors render brighter.
- **Newton's-3rd push/pull** — light coins fly away, heavy crates barely budge, anchored girders fling the player.
- **Multi-target tethering** — lock multiple anchors with RMB for combined force. Three floor girders launch you three times as high.
- **Slingshot traversal** — push off a wall for speed, pull an arch to curve your trajectory mid-flight.
- **Hover control** — push off anchors below you to hover. Scroll to adjust burn intensity and altitude.

## Scope

Traversal core only — no combat, no enemies. If the basic verb feels good, combat layers on top later.
