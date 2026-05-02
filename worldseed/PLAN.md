# Worldseed — Implementation Plan

## Context

A new sci-fi farming prototype to live alongside `coinshot/`, `life-magic/`, and `green-bean/` in the Gamestorming monorepo. The player is a solo settler terraforming a barren alien planet. They grow exotic crops, manage limited power, and deploy nanobot bee swarms to automate their operation — transforming a lifeless rock into a world fit for human habitation.

The **central design pillar is incremental automation under resource constraints**. The player starts doing every chore manually while surviving on limited oxygen. As terraforming progresses, survival constraints fall away and **bees** (sci-fi nanobot drones) become available — but bees draw power and must be deliberately assigned to tasks. The player's role evolves from manual laborer to resource allocator: deciding where to focus automation, when to invest in bee upgrades, and how to balance power across a growing operation. The dopamine comes from two directions — "I no longer have to do that thing" and "look at all those little lights working for me."

The **win condition** is completing all major terraforming tasks required to make the planet livable for humans — breathable atmosphere, stable water cycle, living soil. Inspired by Planet Crafter's progression and Factorio's bot logistics. Designed tight for prototype (three plant types, one power source, one bee chassis) but expandable.

Built in Godot 4.6, GDScript, first-person 3D, web-exportable. Targets a 10–15 minute play session. Heavily reuses green-bean's FPS interaction patterns and life-magic's milestone/data patterns.

Art uses [Low Poly Sci-Fi Planet Base](https://justcreate3d.itch.io/low-poly-sci-fi-planet-base) (modular base/dome aesthetic). The asset pack's full inventory couldn't be auto-fetched (403); the plan assumes general low-poly sci-fi habitat props (domes, antennas, terminals, walkways).

---

## A. Game Loop

### Survival Layer — Oxygen

The player starts with a **basic O2 tank** that lasts ~60 seconds outside the pressurized hub. The hub is safe — breathable air, powered by solar. Outside, the O2 gauge drains. This creates a natural early rhythm: venture out → work → retreat to breathe.

**O2 tank progression** (Subnautica-style):

| Tank | Duration | How to get |
|---|---|---|
| **Basic** | ~60s | Starting gear |
| **Extended** | ~120s | Purchase with harvest crates (available after Atmo 50%) |
| **Advanced** | ~180s | Purchase with harvest crates (available after Atmo ~75%) |
| **Retired** | ∞ | Atmo 100% reached — air is breathable, tank UI disappears |

**Death & autosave:** The game autosaves whenever the player enters a safe zone (hub interior). If O2 hits zero, the player blacks out and **full reloads the last autosave** — all progress since the last hub visit is lost (deliveries, planting, building, everything). This makes hub visits feel meaningful and adds real weight to "one more trip before heading back."

### The Three Plants

| Plant | Terraform Axis | Growth Time | Quirk |
|---|---|---|---|
| **Aerolume** (fast, plentiful) | Atmosphere | ~25s | The "wheat" — you grow many. Produces O2, clears the sky. |
| **Loamspine** (medium) | Soil | ~50s | Roots crack rock into fertile ground; mid-tier. |
| **Tidefern** (slow, scarce) | Hydrosphere | ~100s | The "boss crop." Seed dispenser only emits one every ~40s; needs more water than the others. Generates moisture, eventually rain. |

Ratios (4:2:1 in growth time, 4:2:1 in milestone quotas) make all three roughly co-bottlenecked. Each plant logically contributes to its terraform axis — Aerolume makes air, Loamspine makes soil, Tidefern makes water.

**Plant unlocks:** Only Aerolume is available at start. New plants unlock at terraforming thresholds:
- **Loamspine** unlocks at **Atmo 25%** (3 Aerolume delivered) — atmosphere is stable enough for complex root systems.
- **Tidefern** unlocks at **Soil 33%** (2 Loamspine delivered) — soil can support water-heavy plants.

This focuses the early game on Aerolume + O2 survival, then gradually opens up complexity.

### Manual Chores (start state — player does all of this)

Per plot, per cycle:

1. **Plant** — grab seed from dispenser → walk to plot → click to plant.
2. **Water** — every plot has a `water: float` that drains over ~30s. Below 0.2, growth pauses. Player walks to a **Water Reservoir**, fills a **Canister** (carriable), walks to a plot, clicks to top it up. Tidefern drains ~2× as fast.
3. **Pollinate** — at ~50% maturity, the plant enters a pollination window (glowing icon over the plant, ~15s window). Player runs over and presses E. Miss it → plant stalls until manually pollinated. (Visible "I missed it" friction is the *whole point* — bees fix this.)
4. **Harvest** — at bloom, E with empty hands → spawn a **HarvestCrate** in the player's hand.
5. **Deliver** — walk crate to one of three color-coded chutes on the **Terraforming Hub**.

This makes the early game *deliberately busy*. A first cycle is ~2 minutes of constant motion between O2 retreats. That density is the setup for the payoff.

### Resource Economy — Deliver or Invest

Harvest crates are the universal currency. When the player picks up a crate, they choose what to do with it:

- **Deliver** it to the Terraforming Hub → advances terraform progress toward the win condition.
- **Spend** it at a station → builds things (bees, solar panels, plots, O2 upgrades, bee upgrades).

This is the central tension of every run. Delivering speeds up the win; investing speeds up automation. A greedy early-deliver strategy gets you milestones fast but leaves you doing everything manually. A heavy-invest strategy means a slow start but a satisfying late-game swarm. The optimal path is somewhere in between, and it'll be different each time.

### Build System

Buildable structures (solar panels, plot tiles, wind turbines, geothermal vents) use a **place-and-construct** flow:

1. **Open build menu** (key TBD, probably B or Tab) — shows available blueprints with resource costs. Only unlocked blueprints appear.
2. **Place ghost** — a translucent preview mesh follows the cursor in the world. Placement constraints: no mesh overlap with existing structures, must be within the **hub influence radius** (visible ring on the ground around the habitat).
3. **Contribute resources** — walk up to the ghost with a harvest crate, interact to deposit it. Ghost shows a fill indicator (e.g., 0/3 crates). Can deposit over multiple trips.
4. **Assemble** — once fully funded, hold E on the ghost to fill an assembly progress bar. Takes a few seconds of held interaction. Ghost solidifies into the real structure on completion.

This flow is fully automatable: **Assembly bees** (a 5th bee role) can carry resources to funded ghosts and perform the hold-to-build step. Late-game, the player just places blueprints and the bees handle the rest.

### Power System

**Power is the operational bottleneck.** The hub runs on solar panels that produce a limited watt budget. Every machine and every active bee draws from this pool.

- **Starting state:** 1 solar panel, enough to run the seed dispenser + water reservoir + a couple of bees. Not everything at once.
- **Expansion:** Build more solar panels (cost: harvested resources). Later, wind turbines (unlocked after atmosphere milestone — there's now wind to catch) and geothermal (unlocked after soil milestone — ground is cracked open).
- **Machines draw power:** Seed dispenser, water reservoir pump, bee hive (per active bee). If power is over-allocated, machines brown out (visual flicker, reduced throughput) rather than hard-failing.
- **Player decisions:** "Do I power 3 more bees or build another solar panel first?" Power is what keeps automation from being free.

### The Automation Arc — Bees

Bees are NOT available at start. They unlock as a **capability** at a terraforming sub-threshold, then must be **built** (resource cost), **assigned** to tasks, and **powered** (ongoing watt draw from the hive).

**Bee roles** (assignable — player chooses where each bee works):

| Role | What it does | Visual |
|---|---|---|
| **Pollinator** | Flies to plots in pollination window, auto-pollinates | Bee flies hive → plot → hive, pollen sparkle on arrival |
| **Hydrator** | Flies to reservoir, fills up, waters plots | Bee flies hive → reservoir → plot → hive, water droplet trail |
| **Harvester** | Picks bloomed crops, carries crate to hub intake | Bee flies hive → plot → hub → hive, crate dangling below |
| **Planter** | Grabs seed from dispenser, plants in empty plot | Bee flies hive → dispenser → plot → hive, seed pod glow |
| **Assembler** | Carries resources to build ghosts, assembles structures | Bee flies hive → resource → ghost → hive, construction sparkle |

Each bee physically flies its route — hive to source to destination and back. The air fills with purposeful glowing motes as the swarm grows. This is the "I built this" feeling: look up and see dozens of bioluminescent paths crisscrossing the base.

**Bee upgrades** (one-time resource cost, not power):

| Upgrade | Effect | Design purpose |
|---|---|---|
| **Speed I / II / III** | Bees complete routes faster (shorter flight time) | Scales throughput without adding bees (power-efficient) |
| **Carry I / II** | Bees move more water per trip / harvest faster | Reduces total trips needed; fewer but chunkier runs |

This creates a real choice: spend resources on **more bees** (wider coverage, more VFX presence, more power draw) or **upgrade existing ones** (same power budget, more efficient, fewer visible motes but each one does more).

**Assignment & rebalancing:** The player interacts with the bee hive to see an assignment interface — which bees are doing what, power draw per bee, upgrade options. As the farm scales (more plots, new plant types), the player redistributes bees. "I just expanded to 12 plots — pull 2 bees off delivery and put them on watering until I build another solar array." The endgame verb is resource allocation, not manual labor.

**Power constraint on bees:** Each active bee draws power from the hive. The player can't just max out every role — they have to prioritize based on current bottleneck and available watts. Idle bees (unassigned) perch at the hive and draw nothing.

### Terraforming Progression (win condition + world transformation)

The win condition is **making the planet livable for humans** — completing all three major terraforming axes. Each axis has multiple thresholds that fire visible world changes, unlock new capabilities, and remove survival constraints. The progression is logically ordered: atmosphere first (so you can breathe and work longer), then soil (so plants root better and the ground transforms), then hydrosphere (so water sustains itself).

| Milestone | Quota | What changes | Constraint removed |
|---|---|---|---|
| **Atmo 25%** | 3 Aerolume delivered | Dust storms lighten, sky shifts slightly | Bees unlocked (hive activates). **Loamspine unlocked.** |
| **Atmo 50%** | 6 Aerolume delivered | Skybox lerps rust → violet, dust particles fade | Extended O2 tank purchasable |
| **Atmo 100% — Breathable** | 12 Aerolume delivered | Sky clears, ambient hum, wind audible | **O2 tank retired — free breathing.** Wind turbines unlockable. |
| **Soil 33%** | 2 Loamspine delivered | Ground cracks show green edges | **Tidefern unlocked.** |
| **Soil 66%** | 4 Loamspine delivered | Regolith → dark mossy material in patches | Geothermal power unlockable |
| **Soil 100% — Fertile** | 6 Loamspine delivered | `MultiMeshInstance3D` grass spreads, fog halves | Plots self-fertilize (growth speed +25%) |
| **Hydro 33%** | 1 Tidefern delivered | Mist particles appear at ground level | — |
| **Hydro 66%** | 2 Tidefern delivered | Clouds form in skybox, occasional rain VFX | Rain auto-waters outdoor plots (reduces hydrator bee need) |
| **Hydro 100% — Water Cycle** | 3 Tidefern delivered | Lake fades in, rain is steady, dome lights up | **Win cinematic**: camera pans, "Settlement Viable," end card with run stats |

All three at 100% = the planet is livable. The game shows the transformation from barren rock to living world across the full session.

**Post-win: sandbox mode.** After the "Settlement Viable" cinematic and end card, the player can continue in sandbox mode — keep building, expanding, optimizing the swarm. No new objectives, just the satisfaction of watching a fully automated planet hum along. The sandbox flag disables the win check so milestones don't re-fire.

---

## B. Map Layout

A single ~40m × 40m playable area with skybox-far visuals out beyond:

- **Center:** **Habitat Hub** — pressurized dome (asset pack). Player spawns inside. Safe zone (O2 refills, autosave triggers on entry). Contains the bee hive interface terminal inside or attached.
- **South** (~8m): **Plot Grid** — 3×3 array of 9 plots on a raised metal platform. Expandable (second 3×3 patch unlocks at a soil milestone).
- **East:** **Seed Dispenser** terminal with holographic plant icon overhead. Draws power.
- **West:** **Bee Hive** — hexagonal pod with docking perches; idle bees visibly rest here. Player interacts to assign bees, view power draw, purchase upgrades. Attached to or near the habitat.
- **North** (~12m): **Terraforming Hub** — tall tower with three glowing color-coded chutes (cyan/amber/blue) at carriable height. This is where deliveries go.
- **Adjacent to hub:** **Water Reservoir** — tank with a fill nozzle. Draws power to pump.
- **Near habitat:** **Solar Panel Array** — starting power source. Visible panel count grows as player builds more. Later: wind turbine pad (post-atmosphere), geothermal vent (post-soil).
- **Beyond:** alien horizon with rocks, distant arches, `WorldEnvironment` tinted by `world_progressor.gd`.

Walking distance between any two stations is 5–10s at the player's move speed. Tight enough that the loop is rhythmic; long enough that the chore-removal automations feel like real time savers. Early game, the O2 constraint means the player can't visit every station in one trip — they must plan routes.

---

## C. Scene & Script Architecture

```
worldseed/
  project.godot
  CLAUDE.md
  README.md
  icon.svg
  export_presets.cfg

  scenes/
    main.tscn                       # Entry; loads world + spawns player
    world/
      planet_base.tscn              # The map (habitat, plots, hub, hive, reservoir, solar, terrain)
    player/
      player.tscn                   # CharacterBody3D + Camera3D + InteractRay + HoldPoint + HUD
                                    #   HUD includes: O2 gauge, power meter, terraform progress bars,
                                    #   bee assignment summary, milestone toasts
    stations/
      seed_dispenser.tscn           # Cycle plant type, dispense SeedPod
      plot.tscn                     # Plot tile (planted/growing/pollinating/bloomed)
      water_reservoir.tscn          # Refill the canister
      bee_hive.tscn                 # Idle bee perches + assignment/upgrade UI
      terraform_hub.tscn            # 3 intakes + info screen
      solar_panel.tscn              # Power generator; buildable, each adds to watt budget
      bee.tscn                      # Drone instance (spawned by BeeManager); tween-flies routes
    items/
      seed_pod.tscn                 # Carriable, type-colored
      water_canister.tscn           # Carriable; has water_level field
      harvest_crate.tscn            # Carriable, type-colored
      o2_tank.tscn                  # Equipped item; tier determines max O2 duration

  scripts/
    autoload/
      event_bus.gd                  # Signals: seed_planted, water_applied, pollination_window_opened,
                                    #   plant_pollinated, plant_bloomed, plant_harvested,
                                    #   delivery_received, resource_spent, bee_assigned, bee_upgraded,
                                    #   power_changed, o2_depleted, player_died, ghost_placed,
                                    #   ghost_funded, ghost_assembled, milestone_reached,
                                    #   game_won, tick_fired, autosave_triggered
      game_state.gd                 # Elapsed time, milestone bookkeeping, restart hook, autosave/load,
                                    #   resource inventory (crates held/banked), sandbox mode flag
      tick_engine.gd                # 0.25s tick → emits tick_fired (copy from life-magic)
      plot_manager.gd               # Registry of plots; per-tick growth, water drain, pollination windows
      bee_manager.gd                # Bee fleet: assignment map (bee → role), upgrade levels,
                                    #   power draw calc, spawns visible drones, routes them on tasks
      terraform_manager.gd          # On delivery: increments axis meter, fires milestone checks
      milestone_manager.gd          # Loads MilestoneData .tres; condition eval; reward dispatch
                                    #   (covers terraforming milestones, bee unlock, O2 upgrades,
                                    #    power source unlocks, plot expansions)
      power_manager.gd              # Tracks watt budget (supply from generators - demand from machines/bees)
                                    #   Fires power_changed; handles brownout when over-allocated
      build_manager.gd              # Build menu state, ghost placement (with overlap + radius checks),
                                    #   resource deposit tracking, assembly progress, blueprint registry
      world_progressor.gd           # Applies visible world changes per terraforming milestone
      o2_manager.gd                 # Tracks player O2 level; drain rate outside safe zones;
                                    #   tank tier; triggers autosave on safe zone entry, death on depletion
      sound_manager.gd              # Copy from green-bean
      station_utils.gd              # Copy from green-bean (label, collision toggle, place, pickup)

    stations/
      seed_dispenser.gd             # E to cycle plant; E again to spawn SeedPod. Draws power.
      plot.gd                       # State machine: EMPTY → PLANTED → GROWING → POLLINATING → BLOOMED
                                    #   accepts SeedPod and water; bees can operate on it when assigned
      water_reservoir.gd            # Receives canister, fills water_level. Draws power to pump.
      bee_hive.gd                   # E opens assignment UI (screen mode): see all bees, drag to roles,
                                    #   purchase upgrades with resources. Visual perches for idle bees.
      terraform_hub.gd              # Three child intakes; E (empty hands) opens info screen
      solar_panel.gd                # Adds watts to power_manager when built. Buildable via resource cost.
      bee.gd                        # Single drone: state machine (IDLE → FLYING_TO_SOURCE → WORKING →
                                    #   FLYING_TO_TARGET → RETURNING). Tween-driven flight along
                                    #   visible paths. Glowing bioluminescent mote with trail VFX.

    items/
      seed_pod.gd                   # Carriable; plant_type field
      water_canister.gd             # Carriable; water_level (0..1) with visual fill
      harvest_crate.gd              # Carriable; plant_type field

    build/
      build_ghost.gd                # Placed translucent preview; tracks resource deposits + assembly bar
      blueprint_data.gd             # Resource: id, name, scene_to_spawn, resource_cost, unlock_condition

    data/
      plant_data.gd                 # Resource: id, name, color, growth_seconds, water_drain_rate,
                                    #   pollination_window, terraform_axis, seed_dispense_cooldown
      milestone_data.gd             # Copy from life-magic; condition_type/value, reward_target/type
      bee_upgrade_data.gd           # Resource: upgrade_id, tier, resource_cost, effect (speed/carry mult)

    data_instances/
      plants/
        aerolume.tres
        loamspine.tres
        tidefern.tres
      milestones/                   # All milestones live here; reward_type distinguishes them
        atmo_25.tres                # 3 Aerolume → bees unlocked (hive activates)
        atmo_50.tres                # 6 Aerolume → extended O2 tank craftable
        atmo_100.tres               # 12 Aerolume → free breathing, wind turbines
        soil_33.tres                # 2 Loamspine → ground cracks show green
        soil_66.tres                # 4 Loamspine → mossy patches, geothermal unlocked
        soil_100.tres               # 6 Loamspine → grass spreads, plots self-fertilize
        hydro_33.tres               # 1 Tidefern → mist particles
        hydro_66.tres               # 2 Tidefern → clouds, rain VFX, rain auto-waters
        hydro_100.tres              # 3 Tidefern → lake, steady rain, win
      bee_upgrades/
        speed_1.tres
        speed_2.tres
        speed_3.tres
        carry_1.tres
        carry_2.tres
```

---

## D. Reuse Map

| Source | Target | Mode |
|---|---|---|
| `green-bean/scripts/player/player.gd` (FPS controller, hold_point, InteractMode FREE/SCREEN, EXIT_COOLDOWN_FRAMES) | `worldseed/scripts/player/player.gd` | Copy and trim. Drop MINI_GAME/INFO modes; replace recipe HUD with three terraform meter bars + a bee-tier indicator + milestone toast. |
| `green-bean/scenes/player/player.tscn` | `worldseed/scenes/player/player.tscn` | Copy verbatim, then strip recipe HUD children. |
| `green-bean/scripts/autoload/station_utils.gd` | `worldseed/scripts/autoload/station_utils.gd` | Copy verbatim; drop kettle pour helpers. |
| `green-bean/scripts/autoload/event_bus.gd` | `worldseed/scripts/autoload/event_bus.gd` | Pattern only; rewrite signal list. |
| `green-bean/scripts/autoload/sound_manager.gd` | `worldseed/scripts/autoload/sound_manager.gd` | Copy verbatim; load new clips later. |
| `green-bean/scripts/items/cup.gd` (carriable RigidBody3D pattern) | `seed_pod.gd`, `water_canister.gd`, `harvest_crate.gd` | Pattern. Same group convention, same freeze/collision dance. |
| `green-bean/scripts/stations/cup_stack.gd` (E spawns carriable into hand) | `seed_dispenser.gd` | Pattern. |
| `green-bean/scripts/stations/hand_off.gd` (receive item, fire event, consume) | `terraform_hub.gd` (per-intake) | Pattern. |
| `green-bean/scripts/stations/grinder_station.gd` (state machine + slot + label + tick growth) | `plot.gd` | Pattern; the closest analog for a state-machine station. |
| `green-bean/scripts/autoload/game_manager.gd` (day timer + tip scoring) | **Discard.** Use `game_state.gd` instead — just elapsed time + milestone state. | n/a |
| `life-magic/scripts/data/milestone_data.gd` | `worldseed/scripts/data/milestone_data.gd` | Copy verbatim. |
| `life-magic/scripts/autoload/milestone_manager.gd` | `worldseed/scripts/autoload/milestone_manager.gd` | Copy and adapt. Replace condition checks with the three delivery counts; reward dispatch routes to `bee_manager.unlock_tier()` or `world_progressor.apply_milestone()` based on `reward_type`. |
| `life-magic/scripts/autoload/plot_manager.gd` (slot state, growth float, bloom detection) | `worldseed/scripts/autoload/plot_manager.gd` | Pattern. Different domain, same per-tick advance + emit shape. Add water drain and pollination window. |
| `life-magic/scripts/autoload/tick_engine.gd` | `worldseed/scripts/autoload/tick_engine.gd` | Copy verbatim. |
| `life-magic/scripts/data_instances/milestones/*.tres` | `worldseed/scripts/data_instances/milestones/*.tres` | Pattern. Six new `.tres` files (3 bee tiers + 3 terraforming milestones). |

**Written from scratch:** `bee.gd`, `bee_manager.gd`, `terraform_manager.gd`, `world_progressor.gd`, `power_manager.gd`, `o2_manager.gd`, `build_manager.gd`, `build_ghost.gd`, `blueprint_data.gd`, `plant_data.gd`, `bee_upgrade_data.gd`, `seed_dispenser.gd`, `plot.gd`, `water_reservoir.gd`, `terraform_hub.gd`, `bee_hive.gd`, `solar_panel.gd`, plus all carriable items. The world scene `planet_base.tscn` is hand-built with the asset pack.

---

## E. Build/Deploy Integration

**`.github/workflows/build-all.yml`:** add `worldseed` to the matrix:
```yaml
matrix:
  game: [coinshot, life-magic, worldseed]
```
The existing `cd ${{ matrix.game }}` + `godot --headless --export-release "Web"` step handles it as long as `worldseed/export_presets.cfg` defines a `Web` preset (clone from `coinshot/export_presets.cfg`).

**Root `index.html`:** add a third card following the existing pattern — title "Worldseed", description like *"Terraform an alien planet by farming three exotic crops. Start manual, automate everything with a fleet of nanobot bees."*

**Root `README.md`:** add a row to the Games table:
```
| [worldseed](worldseed/) | Solo first-person sci-fi farming. Terraform an alien planet by growing three exotic crops; unlock bees to automate every chore. | [Play in browser](https://fenyn.github.io/Gamestorming/worldseed/) |
```

CI's `Add cross-origin isolation` and `Arrange site` steps already use `${{ matrix.game }}` — no other edits needed.

---

## F. Implementation Phases

**P0 — Scaffold.** `project.godot` (Forward Plus, GDScript), autoload list (EventBus, GameState, TickEngine, PlotManager, BeeManager, TerraformManager, MilestoneManager, PowerManager, O2Manager, WorldProgressor, SoundManager, StationUtils). Copy player controller from green-bean and strip coffee logic. Empty `plant_data.gd` / `milestone_data.gd` / `bee_upgrade_data.gd` Resource classes. Verify F5 launches and headless export works.

**P1 — Walking around + O2.** Hand-build `planet_base.tscn` with asset-pack props: habitat dome (safe zone), dispenser, hub, hive, reservoir, solar panel, 9 plot tiles. Skybox tinted rust-red, dense fog, dust particles. Implement `o2_manager.gd`: O2 drains outside hub, refills inside, death triggers reload. Add O2 gauge to HUD. Autosave on entering hub. Player can walk around, feel the O2 pressure, and die if they stay out too long.

**P2 — Plant + water + harvest (manual).** Implement `seed_pod.gd`, `seed_dispenser.gd`, `plot.gd` (state EMPTY → PLANTED → GROWING → BLOOMED), `tick_engine.gd`, `plot_manager.gd` (growth advance, water drain). Implement `water_canister.gd` and `water_reservoir.gd`. Implement `harvest_crate.gd` and the BLOOMED → harvested transition. Player can grab a seed, plant it, water it, watch it grow, harvest, drop the crate on the ground. All within O2 limits.

**P3 — Pollination + delivery + resource choice + power.** Add the POLLINATING substate to plot (glowing icon, ~15s window, plant stalls if missed). Implement `terraform_hub.gd` with three intakes that consume crates and route to `terraform_manager.deliver(plant_type)`. Implement the resource economy: crates can be delivered (terraform progress) OR spent (upgrades/building). Implement `power_manager.gd`: solar panel provides watts, seed dispenser and reservoir draw from the budget, brownout on over-allocation. Implement `build_manager.gd`: build menu, ghost placement with overlap/radius checks, resource deposit step, hold-E assembly bar. Player can now build additional solar panels. Hub's empty-hands E opens a screen-mode panel showing 3 terraform meters + power status. Full manual loop is now playable end-to-end, with the deliver-vs-invest tension active.

**P4 — Bees (core).** Implement `bee.tscn` (glowing bioluminescent mote + tween flight along route paths + trail VFX) and `bee_manager.gd` (fleet registry, role assignment, power draw per active bee). Wire the first milestone (Atmo 25%) to activate the hive. Implement bee hive UI (screen mode): see fleet, assign roles, see power draw. Start with Pollinator and Hydrator roles. Bees physically fly their routes — hive → source → target → hive. Verify the visual swarm reads well with 3–5 bees active.

**P5 — Bees (full) + upgrades + assembler.** Add Harvester, Planter, and Assembler bee roles. Assembler bees carry resources to funded build ghosts and perform the assembly step automatically. Implement `bee_upgrade_data.gd` and the upgrade purchase flow at the hive (spend harvested resources → speed/carry upgrades apply to all bees). Test rebalancing: player should feel the tension of "I need more bees but I'm power-starved" and "do I upgrade or expand?"

**P6 — Terraforming milestones + world progression + win + sandbox.** Author all 9 `.tres` milestone files. Implement `world_progressor.gd` with tweens per milestone (skybox lerp, fog reduction, dust fade, grass MultiMesh, cloud formation, rain VFX, lake plane). Plant unlocks: Loamspine at Atmo 25%, Tidefern at Soil 33%. O2 tank tier upgrades purchasable at Atmo 50%/75%, free breathing at Atmo 100%. Wind turbine unlock at Atmo 100%, geothermal at Soil 66%. Rain auto-watering at Hydro 66%. Win cinematic at Hydro 100% (all axes complete) → end card with stats → "Continue in Sandbox" button. Milestone toast UI.

**P7 — Polish.** SFX (ambient hum, plant bloom, harvest pop, delivery thunk, bee buzz, milestone fanfare, O2 warning beep, win sting), VFX (dust storms, bee bioluminescent trails, pollen sparkle, plot bloom pulse, hub light pillar on delivery, brownout flicker), end-card stats (time, deliveries, bees deployed, deaths), web export verification.

---

## G. Open Questions (prototype)

1. **Starting bee count.** How many bees does the player get when the hive activates? 2–3 feels right. More are built by spending harvest crates at the hive.
2. **Bee + building costs.** How many crates per bee? Per solar panel? Per plot tile? Needs tuning, but starting guess: 1 crate per bee, 2 per solar panel, 2 per plot tile.
3. **Power numbers tuning.** Starting solar panel = ? watts. Bee draw = ? watts each. Machine draw = ? watts. Starting ratio: 1 panel = 10W, 1 bee = 2W, dispenser = 3W, reservoir pump = 3W. Budget supports ~2 bees + machines before needing a 2nd panel.
4. **Hub influence radius.** How far from the habitat can you build? Visual indicator on the ground? Does the radius expand with milestones or stay fixed?
5. **Build ghost resource source for assembler bees.** Where do assembler bees pick up crates to deliver to ghosts? A stockpile near the hive where the player drops off crates? Or do they grab from a harvested-crate buffer?
6. **Soundtrack.** Single ambient track that gains layers per milestone (moodier) vs. distinct cue per phase (more legible)?
7. **Tutorial.** Any first-time guidance (floating text, waypoints) or pure discovery?
8. **Session length.** With O2 + power + bee management + building, sessions may run 10–15 min. Needs playtesting.

---

## H. Verification

End-to-end smoke test:
1. F5 in Godot 4.6: player spawns inside habitat dome, O2 is full, power meter shows starting budget.
2. Step outside: O2 gauge starts draining. Return to hub before depletion: O2 refills, autosave triggers.
3. Stay out too long: black out, reload at last autosave inside hub. Carried items lost.
4. Manual cycle: grab Aerolume seed → plant → water → wait 25s → pollinate when window opens → harvest → deliver. Atmosphere meter ticks +1. All within O2 budget.
5. Deliver 3 Aerolume → Atmo 25% milestone: hive activates, bees become available. Dust lightens.
6. At hive: assign first bee to Pollinator role. Bee flies route (hive → plot → hive). Power draw visible. Next pollination window auto-completes.
7. Assign a Hydrator bee. Power budget tightens. Build a 2nd solar panel (resource cost) to compensate.
8. Deliver 6 Aerolume → Atmo 50%: extended O2 tank available. Skybox shifting.
9. Deliver 12 Aerolume → Atmo 100%: **free breathing** — O2 gauge disappears. Wind turbines unlockable.
10. Progress Loamspine and Tidefern deliveries. Reassign bees as bottlenecks shift. Purchase speed/carry upgrades at hive (resource cost).
11. Open build menu, place a solar panel ghost within hub radius. Deposit 2 crates. Hold E to assemble. Panel powers on, watt budget increases.
12. Assign an Assembler bee. Place another ghost — bee carries resources and assembles it automatically.
13. Hit all three axes at 100% (12 / 6 / 3) → world fully transformed → win cinematic plays.
14. End card shows: run time, deliveries by type, bees deployed, upgrades purchased, structures built, deaths.
15. "Continue in Sandbox" → player keeps building with no new objectives.
16. Total run time to win: 10–15 minutes.
17. `godot --headless --export-release "Web" out/index.html` from `worldseed/` produces a working web build.

---

## I. Critical Files

To open before implementation:

- `/home/user/Gamestorming/green-bean/scripts/player/player.gd`
- `/home/user/Gamestorming/green-bean/scenes/player/player.tscn`
- `/home/user/Gamestorming/green-bean/scripts/autoload/station_utils.gd`
- `/home/user/Gamestorming/green-bean/scripts/stations/cup_stack.gd`
- `/home/user/Gamestorming/green-bean/scripts/stations/grinder_station.gd`
- `/home/user/Gamestorming/green-bean/scripts/stations/hand_off.gd`
- `/home/user/Gamestorming/green-bean/scripts/items/cup.gd`
- `/home/user/Gamestorming/life-magic/scripts/data/milestone_data.gd`
- `/home/user/Gamestorming/life-magic/scripts/autoload/milestone_manager.gd`
- `/home/user/Gamestorming/life-magic/scripts/autoload/plot_manager.gd`
- `/home/user/Gamestorming/life-magic/scripts/autoload/tick_engine.gd`
- `/home/user/Gamestorming/.github/workflows/build-all.yml`
- `/home/user/Gamestorming/index.html`
- `/home/user/Gamestorming/README.md`
