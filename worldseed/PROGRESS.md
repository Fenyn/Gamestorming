# Worldseed — Progress Tracker

Full design lives in `PLAN.md`. Asset choices live in `ASSET_MAP.md`. This doc tracks what's built, what's next, and decisions made along the way.

---

## Implementation Status

### P0 — Scaffold ✅ COMPLETE

- [x] `project.godot` — Godot 4.6, Forward Plus, GDScript, 1920x1080
- [x] Input map: WASD, mouse look, jump (Space), sprint (Shift), interact (E)
- [x] 13 autoloads registered and wired:
  - [x] `event_bus.gd` — all worldseed signals (plants, delivery, bees, power, O2, building, milestones)
  - [x] `game_state.gd` — delivery counts, resource inventory, plant unlocks, O2 tier, autosave/load, sandbox flag
  - [x] `tick_engine.gd` — 0.25s tick timer (standalone, not heartbeat-driven like life-magic)
  - [x] `plot_manager.gd` — plot registry scaffold
  - [x] `bee_manager.gd` — fleet registry, role assignment, upgrade tracking, power draw calc
  - [x] `terraform_manager.gd` — delivery routing, axis percentage helpers, milestone check trigger
  - [x] `milestone_manager.gd` — loads 9 milestone .tres files, condition evaluation, reward dispatch (bees, plants, O2, world transforms, win)
  - [x] `power_manager.gd` — supply/demand tracking, brownout detection
  - [x] `o2_manager.gd` — drain outside safe zones, refill inside, 3 tank tiers, death triggers reload
  - [x] `build_manager.gd` — hub radius checks, ghost tracking scaffold
  - [x] `world_progressor.gd` — milestone application tracking
  - [x] `sound_manager.gd` — pooled audio (green-bean pattern, worldseed SFX keys)
  - [x] `station_utils.gd` — collision toggling, item placement, label creation
- [x] 4 data resource classes:
  - [x] `PlantData` — id, name, color, growth_seconds, water_drain_rate, pollination_window, terraform_axis, seed_dispense_cooldown
  - [x] `MilestoneData` — id, display_name, description, condition_type/value, reward_type/target/value
  - [x] `BeeUpgradeData` — upgrade_id, display_name, tier, resource_cost, effect_type, effect_multiplier
  - [x] `BlueprintData` — id, display_name, scene_path, resource_cost, unlock_condition
- [x] Player controller (adapted from green-bean):
  - [x] FPS movement with WASD + mouse look + jump + sprint
  - [x] E to interact, click to pickup/place, one-item carry (Skyrim-style)
  - [x] InteractMode: FREE, MINI_GAME, SCREEN (stripped INFO mode, all coffee logic)
  - [x] HUD: O2 bar with countdown timer, power display, crosshair, interact prompts
  - [x] Camera lock/restore for screen mode and mini-game mode
  - [x] Exit cooldown frames to prevent accidental input
- [x] `scenes/player/player.tscn` — CharacterBody3D + Camera3D (FOV 75) + InteractRay + HoldPoint + HUD/Crosshair
- [x] `scenes/main.tscn` — entry scene with environment, lighting, terrain, dust particles, player spawn
- [x] `scenes/asset_browser.tscn` — utility scene for browsing all 264 pack assets with labels, AABB-aware layout, trimesh collision

### P1 — Walking Around + O2 🔧 IN PROGRESS

- [x] O2 system functional: drains outside, refills in safe zone, death reloads scene
- [x] O2 HUD: progress bar + countdown text (e.g. "O2  0:47")
- [x] Autosave on safe zone entry, full reload on death
- [x] `planet_base.tscn` — all stations placed as editor-visible instances (not script-spawned):
  - [x] Habitat Hub (Module_01) at center
  - [x] Terraforming Hub (Building_14) to north
  - [x] Bee Hive (Building_16_01) to west
  - [x] Solar Panel (Building_20) to east
  - [x] Water Reservoir (Building_17) near terraform hub
  - [x] Landed Shuttle (Vehicles_05) flavor prop
  - [x] 9 Plot tiles (Agro_04/05/06) in 3x3 grid to south
  - [x] 10 small rocks + 4 large rocks scattered
  - [x] 5 crystals scattered
  - [x] 6 terrain pieces (Nature_Planet_01/02/03) at mid-range
  - [x] 8 mountains at distant horizon (scaled 3x, pushed to 130-170m)
- [x] Safe zone: Area3D at habitat, wired to O2Manager enter/exit
- [x] Trimesh collision auto-generated for all placed models
- [x] Death handler: EventBus.player_died → reload scene
- [ ] **Procedural terrain** — shader-based vertex displacement with ridged FBM noise
  - [x] `shaders/terrain.gdshader` — ridged noise, height-based coloring, steep slope darkening, flat zone around base
  - [x] `scripts/world/terrain.gd` — @tool script, syncs all exports to shader in real-time, generates matching CPU collision at runtime
  - [ ] Terrain needs testing and tuning (user requested proper alien planet surface)
- [ ] Dust particles need mesh assigned (QuadMesh added but untested)
- [ ] Station label placement may need height adjustment per model
- [ ] Seed Dispenser not yet placed (asset TBD — "combination of props to figure out later")

### P2 — Plant + Water + Harvest (manual) ❌ NOT STARTED

- [ ] `seed_pod.gd` — carriable RigidBody3D, plant_type field, Props_Box_09 with tinted emissive
- [ ] `seed_dispenser.gd` — E to cycle plant type, E again to spawn seed pod
- [ ] `plot.gd` — state machine: EMPTY → PLANTED → GROWING → BLOOMED
- [ ] `plot_manager.gd` — per-tick growth advance, water drain
- [ ] `water_canister.gd` — carriable, water_level (0..1), Props_Box_09 with fill-based light
- [ ] `water_reservoir.gd` — receives canister, fills water_level
- [ ] `harvest_crate.gd` — carriable, plant_type field, Props_Box_08 with tinted emissive
- [ ] Plant visuals: Nature_Plants_07/08/09 scaled by growth progress

### P3 — Pollination + Delivery + Resource Choice + Power ❌ NOT STARTED

- [ ] Plot POLLINATING substate (glowing icon, ~15s window, stall if missed)
- [ ] `terraform_hub.gd` — 3 intakes, consume crates, route to terraform_manager
- [ ] Resource economy: deliver for progress OR spend for upgrades/building
- [ ] Power system live: machines draw watts, brownout on over-allocation
- [ ] Build system: ghost placement, resource deposit, hold-E assembly
- [ ] Hub info screen (screen mode): terraform meters + power status

### P4 — Bees (core) ❌ NOT STARTED

- [ ] `bee.tscn` — glowing bioluminescent mote, tween flight, trail VFX
- [ ] `bee.gd` — state machine: IDLE → FLYING_TO_SOURCE → WORKING → FLYING_TO_TARGET → RETURNING
- [ ] Bee hive UI (screen mode): fleet list, role assignment, power draw display
- [ ] Pollinator + Hydrator roles
- [ ] Atmo 25% milestone activates hive
- [ ] Visual swarm verification (3-5 bees)

### P5 — Bees (full) + Upgrades + Assembler ❌ NOT STARTED

- [ ] Harvester + Planter + Assembler roles
- [ ] Assembler bees: carry resources to ghosts + auto-build
- [ ] Upgrade purchase flow at hive (spend harvest crates → speed/carry upgrades)
- [ ] Rebalancing tension playtest

### P6 — Terraforming Milestones + World Progression + Win + Sandbox ❌ NOT STARTED

- [ ] 9 milestone .tres files authored
- [ ] `world_progressor.gd` — visual tweens per milestone (skybox, fog, dust, grass, clouds, rain, lake)
- [ ] Plant unlocks: Loamspine at Atmo 25%, Tidefern at Soil 33%
- [ ] O2 tank upgrades purchasable at Atmo 50%/75%
- [ ] Free breathing at Atmo 100%
- [ ] Wind turbine unlock at Atmo 100%, geothermal at Soil 66%
- [ ] Rain auto-watering at Hydro 66%
- [ ] Win cinematic at all axes 100%
- [ ] End card with stats
- [ ] "Continue in Sandbox" button
- [ ] Milestone toast UI

### P7 — Polish ❌ NOT STARTED

- [ ] SFX: ambient hum, plant bloom, harvest pop, delivery thunk, bee buzz, milestone fanfare, O2 warning beep, win sting
- [ ] VFX: dust storms, bee bioluminescent trails, pollen sparkle, plot bloom pulse, hub light pillar, brownout flicker
- [ ] End-card stats: time, deliveries, bees deployed, upgrades purchased, structures built, deaths
- [ ] Web export verification

---

## Design Decisions (confirmed during planning)

| Decision | Choice | Rationale |
|---|---|---|
| Win condition | Complete all terraforming tasks (not fill bars) | Planet Crafter-inspired; logical progression |
| Resource economy | Deliver OR invest (player chooses per crate) | Central tension: speed vs. automation |
| Plant unlocks | Progressive (Aerolume → Loamspine → Tidefern) | Focuses early game, opens complexity gradually |
| O2 death | Full reload last autosave (everything since hub lost) | Real stakes, meaningful hub visits |
| O2 tank upgrades | Purchased with harvest crates | Resources as investment currency, not power |
| Bee automation | Assignable roles, power-constrained | Player allocates, not just unlocks — Factorio bots |
| Bee upgrades | One-time resource cost (speed/carry) | Distinct from power (operational) cost |
| Build system | Ghost placement → deposit resources → hold E to assemble | Two-step, fully automatable by assembler bees |
| Build constraints | No mesh overlap, within hub influence radius | Prevents griefing layout, creates expanding footprint |
| Post-win | Sandbox mode (keep building, no new objectives) | Satisfaction of watching a fully automated planet |
| Scene objects | Always placed in .tscn as editor instances, never script-spawned | Must be visible and movable in the Godot editor |
| Terrain | Procedural noise-based vertex displacement shader | Alien rocky crags, flat zone around base, tweakable in editor |

---

## Asset Pack

**Source:** [Low Poly Sci-Fi Planet Base](https://justcreate3d.itch.io/low-poly-sci-fi-planet-base) by JustCreate3D

- 264 GLB models imported into `worldseed/assets/` (buildings, props, nature, animals, vehicles)
- 7 textures including 2 ground textures, 1 emissive map, 1 grass texture
- No animations in pack — all movement (doors, turbines, bees) built in Godot with tweens/AnimationPlayer
- Multi-piece models (doors, drawers, building modules) assembled by hand in editor
- Full asset mapping in `ASSET_MAP.md`

---

## File Inventory

```
worldseed/
  project.godot                          # Godot 4.6 project config + 13 autoloads + input map
  PLAN.md                                # Full game design document
  ASSET_MAP.md                           # Asset-to-game-element mapping (user-filled)
  PROGRESS.md                            # This file
  icon.svg                               # Placeholder icon

  shaders/
    terrain.gdshader                     # Ridged FBM terrain with height coloring + flat zone

  scenes/
    main.tscn                            # Entry scene: environment, terrain, dust, planet_base, player
    asset_browser.tscn                   # Utility: browse all 264 assets with labels + collision
    player/
      player.tscn                        # FPS player: CharacterBody3D + Camera + Ray + HUD
    world/
      planet_base.tscn                   # World layout: all stations, rocks, crystals, terrain, mountains

  scripts/
    asset_browser.gd                     # Asset browser loader + FPS controller
    player/
      player.gd                          # FPS controller, item carry, interact, O2/power HUD
    world/
      planet_base.gd                     # Safe zone logic, collision generation, death handler
      terrain.gd                         # @tool terrain: syncs exports to shader, generates collision
    autoload/
      event_bus.gd                       # Signal bus (plants, delivery, bees, power, O2, building, milestones)
      game_state.gd                      # Game state, resource inventory, autosave/load
      tick_engine.gd                     # 0.25s game tick
      plot_manager.gd                    # Plot registry (scaffold)
      bee_manager.gd                     # Bee fleet, roles, upgrades, power draw
      terraform_manager.gd              # Delivery routing, axis percentages, milestone trigger
      milestone_manager.gd              # 9 milestones, condition eval, reward dispatch
      power_manager.gd                   # Supply/demand, brownout
      o2_manager.gd                      # O2 drain, safe zones, tank tiers, death
      build_manager.gd                   # Hub radius, ghost tracking (scaffold)
      world_progressor.gd               # Milestone visual tracking (scaffold)
      sound_manager.gd                   # Pooled audio player
      station_utils.gd                   # Collision/placement/label helpers
    data/
      plant_data.gd                      # PlantData resource class
      milestone_data.gd                  # MilestoneData resource class
      bee_upgrade_data.gd                # BeeUpgradeData resource class
    build/
      blueprint_data.gd                  # BlueprintData resource class

  assets/
    buildings/    (70 GLB files)
    props/        (121 GLB files)
    nature/       (51 GLB files)
    animals/      (12 GLB files)
    vehicles/     (5 GLB files)
    textures/     (7 PNG files including 2 ground textures, emissive, grass)
```
