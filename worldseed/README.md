# Worldseed

Terraform an alien planet by farming exotic crops. Manage power, deploy nanobot
bees, and watch a barren rock become a living world.

- **Engine:** Godot 4.6 (Forward Plus), GDScript
- **Status:** prototype
- **Run:** Open `worldseed/project.godot` in Godot 4.6 and press F5.

## Controls

- **WASD** — move
- **Space** — jump
- **Shift** — sprint
- **E** — interact

## Notes

- Terraforming/farming sim with O2 survival and a power economy; assignable nanobot bees automate work, and a build system expands the station.
- Dedicated manager autoloads per system (PlotManager, BeeManager, TerraformManager, PowerManager, O2Manager, BuildManager, MilestoneManager, WorldProgressor, and more).
- Uses the shared `godot_base` addon at `addons/godot_base/`.
