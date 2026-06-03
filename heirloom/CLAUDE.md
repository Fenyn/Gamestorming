# CLAUDE.md

# Heirloom -- Rural Life Sim

A first-person 3D life sim set in rural Washington state, mid-2000s. The player inherits their grandfather's homestead and must pay monthly land costs while rebuilding grandpa's rusted-out 1969 Camaro for a tribute road trip. Inspired by My Summer Car, Mon Bazou, and Stardew Valley.

## Development

- **Engine:** Godot 4.6 stable. Open `heirloom/project.godot` in the editor, F5 to run.
- **Language:** GDScript only.
- **GDScript type inference rule:** Never use `:=` with untyped sources (Array elements, Dictionary values, Variant returns). Always use explicit type annotations: `var x: int = value`.
- **Autoloads must not use class_name.** The autoload name IS the global identifier.
- **Scene placement:** Always place objects in `.tscn` files via the editor. Never spawn objects with scripts unless they're runtime items (logs, firewood, fish, camaro parts).
- **Renderer:** Forward Plus (3D).
- **Art style:** PSX-style low-poly. Assets sourced from PSX Mega Pack, PSX Mega Pack II, PSX Nature, and psxpack-1.0_base. All in `assets/psx/`.
- This project lives inside the Gamestorming monorepo alongside other prototypes.

## Architecture

### Autoloads (6)
- `EventBus` -- Signal-only bus for cross-system communication
- `GameState` -- All persistent data (money, day, needs, camaro, upgrades, inventory, materials, friendships)
- `TimeManager` -- Day/night cycle, clock, month tracking
- `SaveManager` -- JSON save/load to user://, autosaves on sleep, loads on startup
- `Economy` -- Price tables, buy/sell logic, monthly bill system
- `HomesteadManager` -- 16 upgrade definitions, prerequisite checks, build logic

### Core Systems
- **Survival needs:** Hunger, thirst, fatigue drain over time. Collapse at fatigue 0.
- **Economy:** Earn from firewood ($5), fishing ($8-25), farming, eggs. Monthly $200 land payment, 2 misses = foreclosure.
- **Homestead upgrades:** 4 tiers, 16 upgrades, each with distinct purpose. Reduce survival costs over time.
- **Camaro rebuild:** 11 components with prerequisite chain. Buy at store, carry to garage, install.
- **NPCs:** Earl (store owner), Dale (mechanic). Friendship 0-5, dialogue changes by level.

### Prefab Scenes
All interactables are in `scenes/interactables/` as instancable scenes with PSX models:
- bed, well, kitchen, choppable_tree, splitting_stump, fishing_spot
- store_counter, upgrade_site, scavenge_pile, mailbox, scene_door

Items in `scenes/items/`: log, firewood, fish, camaro_part
NPCs in `scenes/npcs/`: earl, dale
Vehicles in `scenes/vehicles/`: camaro

### Asset Structure
```
assets/psx/
  tools/       -- axes, hammers, wrenches, shovels (GLB)
  furniture/   -- beds, chairs, tables, shelves, lamps (GLB)
  structures/  -- walls, doors, floors, stairs, fences, garages, sheds (GLB + OBJ)
  nature/      -- trees, stumps, logs, grass, rocks, wheat (GLB + OBJ)
  props/       -- barrels, crates, tools, food, electronics, pipes (GLB + OBJ)
  vehicles/    -- Car01, Car02, KWagen, Excavator (Blend)
  characters/  -- earl, dale (FBX)
```

## Controls
- WASD -- movement
- Mouse -- look
- E -- interact
- Left click -- pick up / place items
- Shift -- sprint (drains fatigue faster)
- B -- toggle bicycle (2x speed, can't carry items)
- Esc -- pause menu
