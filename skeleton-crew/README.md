# Skeleton Crew

FTL meets friendslop: a 2-4 player co-op roguelike ship sim where each player is one crewmate, first-person, aboard a single ship fleeing through hostile space. No one has the full picture; everyone's yelling.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** greybox prototype
- **Run:** Open `skeleton-crew/project.godot` in Godot 4.6 and press F5.

## Controls
Input is context-based (PLAYER / HELM / TURRET / TERMINAL — shared keys change meaning per context):
- Walking: WASD move, mouse look, E interact, B mag boots, Tab wrist display, F3 debug
- Piloting: mouse yaw/pitch, W/S throttle, A/D strafe, Q/E roll, Space/Ctrl vertical thrust, Shift afterburner, F flight assist
- Turret: mouse aim, LMB fire, Esc exit
- Terminal: mouse on 3D UI, Esc exit

## Notes
- Server-authoritative ENet multiplayer: clients request via `rpc_id(1, ...)`, the server validates and broadcasts; supports LISTEN (host plays) and DEDICATED server modes.
- Ship systems (hull, shield, power, weapons, flight, atmosphere) are independent components under a mediator ship node; UI is diegetic (in-world screens). The ship stays at world origin — enemies and skybox move relative to it.
- Jolt Physics, D3D12 driver on Windows. The `assets/Sci-Fi Modular Environment Pack Vol.1` asset pack is gitignored (large, local-only).
- Full design doc: `../designs/skeleton-crew.md`.
