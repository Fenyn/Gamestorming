# Skeleton Crew — Development Guide

## Project

Co-op roguelike ship sim. Godot 4.6, GDScript, 3D first-person, multiplayer.
Design doc: `../designs/skeleton-crew.md`
Architecture plan: see `.claude/plans/mighty-sauteeing-stardust.md`

## GDScript Rules

- Always use explicit type annotations. Never use `:=` with untyped sources.
- `sin()` not `sinf()`, `cos()` not `cosf()` — GDScript is not C.
- Autoload scripts must NOT use `class_name`. The autoload name IS the global identifier. Using `class_name` with the same name causes a "hides an autoload singleton" parse error.
- Non-autoload scripts can and should use `class_name` for type safety.

## Scene Files (.tscn)

- `[sub_resource]` blocks must appear BEFORE any `[node]` that references them.
- CSG doorways: use gap-based construction (two wall segments + a lintel above), not CSG boolean subtraction. Subtraction only works parent-child, not siblings.
- Place objects in .tscn files, not spawned by scripts, unless dynamic (players, projectiles).
- When placing flat meshes (QuadMesh, status screens) against walls, rotate the mesh to face the room interior and offset ~0.05-0.1m from the wall surface so it doesn't clip into the wall geometry.

## Multiplayer Patterns

- Server authority: clients send requests via `rpc_id(1, ...)`, server validates and broadcasts via `rpc()`.
- Never check `peer_id == 1` to mean "the host player." Use `multiplayer.is_server()` for authority, `NetworkManager.get_player_peers()` for player enumeration.
- Server mode abstraction: `NetworkManager.server_mode` is LISTEN (host plays) or DEDICATED (host is server-only). All game logic is mode-agnostic.
- Camera/input code guards on `is_multiplayer_authority()`. Never set `camera.current = true` on a remote player.
- Frame-rate dependent math: always multiply per-frame deltas by `delta`. Use `move_toward(value, target, rate * delta)` not `move_toward(value, target, fixed_step)`.

## Architecture

- Ship systems (hull, shield, power, weapons, flight, atmosphere) are independent component nodes under a container. The ship script mediates between them (Mediator pattern). Systems don't reference each other directly.
- Signals flow up (system → mediator), commands flow down (mediator → system). Cross-boundary events (gameplay → UI/audio) go through `EventBus` autoload.
- `EventBus` is signals only, no state. Ship state lives on the ship node.
- Player input uses `InputContext.Mode` enum (PLAYER/HELM/TURRET/TERMINAL/DISABLED). Only one context is active at a time. Shared keys (WASD, E) are interpreted differently per context — no input map conflicts needed.
- Ship stays at world origin. Enemy and skybox move relative to the ship's logical transform.

## Future Improvements

- **Modular room prefabs with connection points**: Each room should define doorway connection points so rooms snap together without manual Z-position math. Enables modular ship assembly for different ship sizes/layouts and eventually a ship editor. Current approach uses manual positioning in player_ship.tscn.

## Physics Layers

1. Environment (ship interior CSG)
2. Players (CharacterBody3D)
3. Interactable (station Area3D zones)
4. PlayerProjectile
5. EnemyProjectile
6. PlayerShipHitbox
7. EnemyShipHitbox
8. RoomZone (room Area3D volumes for player tracking)

## Controls

### Walking (PLAYER context)
WASD move, E interact, mouse look, B mag boots, Tab wrist, F3 debug

### Piloting (HELM context)
Mouse yaw/pitch, W/S throttle, A/D strafe, Q/E roll, Space thrust up, Ctrl thrust down, Shift afterburner, F flight assist

### Turret (TURRET context)
Mouse aim, LMB fire, Esc exit

### Terminal (TERMINAL context)
Mouse interacts with 3D UI, Esc exit
