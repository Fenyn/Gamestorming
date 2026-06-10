# Redshift

A zero-g spaceship time-trial racer with fully Newtonian 6DOF flight — momentum carries, and stopping is your problem.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** prototype
- **Run:** Open `redshift/project.godot` in Godot 4.6 and press F5.

## Controls
Keyboard and gamepad are both mapped:
- W / S — thrust forward / backward (gamepad triggers)
- A / D — strafe left / right (left stick)
- Space / Ctrl — thrust up / down
- Q / E — roll left / right
- Shift — afterburner
- F — toggle rotation dampening, V — toggle translation dampening
- G — toggle racing line
- R — restart race

## Notes
- Jolt Physics with default gravity set to 0 — all movement is pure Newtonian thrust.
- Ghost replay system (`ghost/`), track and ship scenes, dedicated `InputManager` autoload.
- Uses the D3D12 rendering driver on Windows.
