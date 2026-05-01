# Worldseed — Implementation Plan

## Context

A new sci-fi farming prototype to live alongside `coinshot/`, `life-magic/`, and `green-bean/` in the Gamestorming monorepo. The player is a solo settler terraforming a barren alien planet. They grow three exotic crops and deliver harvests to a Terraforming Hub that fills three planet meters; reaching all three wins the run.

The **central design pillar is incremental automation**. The player starts doing every chore manually — planting, watering, pollinating, harvesting, delivering. As terraforming progress accumulates, **bees** (sci-fi nanobot drones) unlock in tiers, each removing one specific manual annoyance. The dopamine isn't "I made another pod" — it's "I no longer have to do that thing." Visual world progression (skybox, fog, ground, lake) reinforces the same arc: the planet wakes up as the player's workload winds down.

Built in Godot 4.6, GDScript, first-person 3D, web-exportable. Targets a 7–12 minute play session. Heavily reuses green-bean's FPS interaction patterns and life-magic's milestone/data patterns.

Art uses [Low Poly Sci-Fi Planet Base](https://justcreate3d.itch.io/low-poly-sci-fi-planet-base) (modular base/dome aesthetic). The asset pack's full inventory couldn't be auto-fetched (403); the plan assumes general low-poly sci-fi habitat props (domes, antennas, terminals, walkways).

---

## A. Game Loop

### The Three Plants

| Plant | Terraform Axis | Growth Time | Quirk |
|---|---|---|---|
| **Aerolume** (fast, plentiful) | Atmosphere | ~25s | The "wheat" — you grow many. |
| **Loamspine** (medium) | Soil | ~50s | Roots crack rock; mid-tier. |
| **Tidefern** (slow, scarce) | Hydrosphere | ~100s | The "boss crop." Seed dispenser only emits one every ~40s; needs more water than the others. |

Ratios (4:2:1 in growth time, 4:2:1 in milestone quotas) make all three roughly co-bottlenecked.

### Manual Chores (start state — player does all of this)

Per plot, per cycle:

1. **Plant** — grab seed from dispenser → walk to plot → click to plant.
2. **Water** — every plot has a `water: float` that drains over ~30s. Below 0.2, growth pauses. Player walks to a **Water Reservoir**, fills a **Canister** (carriable), walks to a plot, clicks to top it up. Tidefern drains ~2× as fast.
3. **Pollinate** — at ~50% maturity, the plant enters a pollination window (glowing icon over the plant, ~15s window). Player runs over and presses E. Miss it → plant stalls until manually pollinated. (Visible "I missed it" friction is the *whole point* — Tier 1 bees fix this.)
4. **Harvest** — at bloom, E with empty hands → spawn a **HarvestCrate** in the player's hand.
5. **Deliver** — walk crate to one of three color-coded chutes on the **Terraforming Hub**.

This makes the early game *deliberately busy*. A first cycle is ~2 minutes of constant motion. That density is the setup for the payoff.

### The Automation Arc — Bee Tier Unlocks

Bees are NOT available at start. They unlock at sub-thresholds of terraforming progress, in a fixed order. Each unlock instantly removes a specific chore from every plot. The hive (a low-poly hexagonal pod near the habitat) visibly populates with new drones as tiers come online.

| Tier | Unlock Trigger | Automates | Annoyance Removed |
|---|---|---|---|
| **Tier 1 — Pollinator swarm** | First 3 Aerolume delivered (~atm 25%) | Auto-pollinates any plot when its window opens | "I keep missing the pollination window" |
| **Tier 2 — Hydrator swarm** | First 2 Loamspine delivered (~soil 33%) | Auto-tops-up water on all plots in range; canister becomes obsolete | "I'm always running back to the reservoir" |
| **Tier 3 — Harvester swarm** | First 2 Tidefern delivered (~hydro 66%) | Bloomed plots auto-load HarvestCrates onto a pickup pad next to the hub; player just walks them the last few meters (or stretch: auto-deliver entirely) | "I'm constantly running back to the hub" |

Workload arc:
- **Phase 0** (manual): plant + water + pollinate + harvest + deliver → 5 verbs per cycle.
- **Phase 1** (Pollinator unlocked): plant + water + harvest + deliver → 4 verbs.
- **Phase 2** (Hydrator unlocked): plant + harvest + deliver → 3 verbs.
- **Phase 3** (Harvester unlocked): plant only → 1 verb. Endgame is "scale up the farm" rather than "do every chore."

This is the incremental shape: the loop *feels different* every few minutes.

### Terraforming Milestones (win condition + world transformation)

The three meters fill on delivery. Hitting each fires a visible world transformation. All three = win.

| Milestone | Quota | World Change |
|---|---|---|
| **M1: Atmosphere Stable** | 12 Aerolume delivered | Skybox lerps rust → violet. Dust storm particles fade. New ambient hum layer fades in. |
| **M2: Soil Bound** | 6 Loamspine delivered | Ground material shifts from cracked regolith to mossy dark. `MultiMeshInstance3D` of grass tufts populates around the base. Fog density halves. |
| **M3: Hydrosphere Active** | 3 Tidefern delivered | Skybox shifts to blue. Lake plane fades in beyond the play area. Habitat dome lights up. **Win cinematic**: camera pans, "Settlement Viable." end card with run stats. |

Bee unlocks are sub-milestones; terraforming milestones are the win-state axes. They share the same delivery events, evaluated in `MilestoneManager`.

---

## B. Map Layout

A single ~40m × 40m playable area with skybox-far visuals out beyond:

- **Center:** modular sci-fi habitat dome (asset pack) — purely scenic.
- **South** (~8m): **Plot Grid** — 3×3 array of 9 plots on a raised metal platform.
- **East:** **Seed Dispenser** terminal with holographic plant icon overhead.
- **West:** **Bee Hive** — hexagonal pod with 4 docking slots; idle bees visibly perched there as tiers unlock.
- **North** (~12m): **Terraforming Hub** — tall tower with three glowing color-coded chutes (cyan/amber/blue) at carriable height.
- **Adjacent to hub:** **Water Reservoir** — short tank with a fill nozzle.
- **Beyond:** alien horizon with rocks, distant arches, `WorldEnvironment` tinted by `world_progressor.gd`.

Walking distance between any two stations is 5–10s at the player's move speed. Tight enough that the loop is rhythmic; long enough that the chore-removal automations feel like real time savers.

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
      planet_base.tscn              # The map (habitat, plots, hub, hive, reservoir, terrain)
    player/
      player.tscn                   # CharacterBody3D + Camera3D + InteractRay + HoldPoint + HUD
    stations/
      seed_dispenser.tscn           # Cycle plant type, dispense SeedPod
      plot.tscn                     # Plot tile (planted/growing/pollinating/bloomed)
      water_reservoir.tscn          # Refill the canister
      bee_hive.tscn                 # Idle bees + tier display
      terraform_hub.tscn            # 3 intakes + info screen
      bee.tscn                      # Drone instance (spawned by BeeManager)
    items/
      seed_pod.tscn                 # Carriable, type-colored
      water_canister.tscn           # Carriable; has water_level field
      harvest_crate.tscn            # Carriable, type-colored

  scripts/
    autoload/
      event_bus.gd                  # Signals: seed_planted, water_applied, pollination_window_opened,
                                    #   plant_pollinated, plant_bloomed, plant_harvested,
                                    #   delivery_received, bee_tier_unlocked, milestone_reached,
                                    #   game_won, tick_fired
      game_state.gd                 # Elapsed time, milestone bookkeeping, restart hook
      tick_engine.gd                # 0.25s tick → emits tick_fired (copy from life-magic)
      plot_manager.gd               # Registry of plots; per-tick growth, water drain, pollination windows
      bee_manager.gd                # Tier state (which tiers unlocked); spawns visible drones at hive;
                                    #   applies tier effects (auto-pollinate, auto-water, auto-harvest)
      terraform_manager.gd          # On delivery: increments meter, fires milestone + bee-tier checks
      milestone_manager.gd          # Loads MilestoneData .tres; condition eval; reward dispatch
                                    #   (covers BOTH terraforming milestones and bee-tier sub-milestones)
      world_progressor.gd           # Applies visible world changes per terraforming milestone
      sound_manager.gd              # Copy from green-bean
      station_utils.gd              # Copy from green-bean (label, collision toggle, place, pickup)

    stations/
      seed_dispenser.gd             # E to cycle plant; E again to spawn SeedPod
      plot.gd                       # State machine: EMPTY → PLANTED → GROWING → POLLINATING → BLOOMED
                                    #   accepts SeedPod and water; bee_manager pings auto-pollinate/water
      water_reservoir.gd            # Receives canister, fills water_level over a few seconds
      bee_hive.gd                   # Visual perch; subscribes to bee_tier_unlocked to spawn drones
      terraform_hub.gd              # Three child intakes; E (empty hands) opens info screen
      bee.gd                        # Single drone visual; tween-driven hover/flight

    items/
      seed_pod.gd                   # Carriable; plant_type field
      water_canister.gd             # Carriable; water_level (0..1) with visual fill
      harvest_crate.gd              # Carriable; plant_type field

    data/
      plant_data.gd                 # Resource: id, name, color, growth_seconds, water_drain_rate,
                                    #   pollination_window, terraform_axis, seed_dispense_cooldown
      milestone_data.gd             # Copy from life-magic; condition_type/value, reward_target

    data_instances/
      plants/
        aerolume.tres
        loamspine.tres
        tidefern.tres
      milestones/                   # All milestones live here; reward_type distinguishes them
        bee_tier_pollinator.tres    # condition: atmosphere_delivered >= 3 → reward: unlock bee tier 1
        bee_tier_hydrator.tres      # condition: soil_delivered >= 2 → reward: unlock bee tier 2
        bee_tier_harvester.tres     # condition: hydro_delivered >= 2 → reward: unlock bee tier 3
        atmosphere_stable.tres      # condition: atmosphere_delivered >= 12 → reward: world transform
        soil_bound.tres             # condition: soil_delivered >= 6 → reward: world transform
        hydrosphere_active.tres     # condition: hydro_delivered >= 3 → reward: world transform + win
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

**Written from scratch:** `bee.gd`, `bee_manager.gd`, `terraform_manager.gd`, `world_progressor.gd`, `plant_data.gd`, `seed_dispenser.gd`, `plot.gd`, `water_reservoir.gd`, `terraform_hub.gd`, `bee_hive.gd`, plus all carriable items. The world scene `planet_base.tscn` is hand-built with the asset pack.

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

**P0 — Scaffold.** `project.godot` (Forward Plus, GDScript), autoload list (EventBus, GameState, TickEngine, PlotManager, BeeManager, TerraformManager, MilestoneManager, WorldProgressor, SoundManager, StationUtils). Copy player controller from green-bean and strip coffee logic. Empty `plant_data.gd` / `milestone_data.gd` Resource classes. Verify F5 launches and headless export works.

**P1 — Walking around.** Hand-build `planet_base.tscn` with asset-pack props: habitat, dispenser, hub, hive, reservoir, 9 plot tiles. Skybox tinted rust-red, dense fog, dust particles. Confirm collision and FOV feel right. No interactivity yet.

**P2 — Plant + water + harvest (manual).** Implement `seed_pod.gd`, `seed_dispenser.gd`, `plot.gd` (state EMPTY → PLANTED → GROWING → BLOOMED), `tick_engine.gd`, `plot_manager.gd` (growth advance, water drain). Implement `water_canister.gd` and `water_reservoir.gd`. Implement `harvest_crate.gd` and the BLOOMED → harvested transition. Player can grab a seed, plant it, water it, watch it grow, harvest, drop the crate on the ground.

**P3 — Pollination + delivery + meters.** Add the POLLINATING substate to plot (glowing icon, ~15s window, plant stalls if missed). Implement `terraform_hub.gd` with three intakes that consume crates and route to `terraform_manager.deliver(plant_type)`. Hub's empty-hands E opens a screen-mode panel showing 3 numeric meters. Full manual loop is now playable end-to-end.

**P4 — Bee tier unlocks.** Implement `bee.tscn` (glowing capsule + tween hover) and `bee_manager.gd` (tier state, drone spawn at hive). Wire `milestone_manager.gd` to evaluate the 3 bee-tier sub-milestones and route their rewards to `bee_manager.unlock_tier(N)`:
- Tier 1 → register a callback on `pollination_window_opened` that auto-pollinates after 1s.
- Tier 2 → on tick, top up water on all plots within hive range; canister becomes optional.
- Tier 3 → on `plant_bloomed`, auto-spawn HarvestCrate onto a pickup pad next to the hub (player still walks the last few meters in v1; full auto-deliver is a stretch).

Visual: each tier unlock spawns N drones at the hive (animated landing). Toast: "POLLINATOR SWARM ONLINE." Verify the chore-removal arc actually feels good in playtest.

**P5 — Terraforming milestones + world progression + win.** Author all 6 `.tres` files. Implement `world_progressor.gd` with a tween per milestone (skybox lerp, fog reduction, MultiMesh grass spawn, lake plane fade). Add the milestone toast UI and the win-state cinematic (camera lock, end card, run stats). Add tutorial first-frame text that fades after first delivery.

**P6 — Polish.** SFX (ambient hum, plant bloom, harvest pop, delivery thunk, milestone fanfare, win sting), VFX (dust storms, bee pollen sparkle, plot bloom pulse, hub light pillar on delivery), end-card stats, web export verification.

---

## G. Open Questions

1. **Bee count per tier.** Visually how many drones spawn at each tier — 1, 2, or 4? More drones = more visual presence but also more particle/light cost.
2. **Tier 3 auto-deliver.** Should Tier 3 fully auto-deliver crates to the hub (zero player friction past planting), or just deposit them on a pad near the hub (player still does the last walk)? The first feels more "endgame Factorio"; the second keeps the player physically present in the loop.
3. **Failure / setbacks.** Any wilting / sandstorms / bee-disabling hazards? Default recommendation: none in v1 — the cozy/satisfying arc is the point. Hazards are easy to add in v2.
4. **Plot count and scale.** 9 plots feels right for a solo manual phase but might feel cramped once Tier 3 lands. Should the plot grid expand at a milestone (unlock a second 3×3 patch) so post-automation play has scale?
5. **Soundtrack and pacing.** Single ambient track that gains layers per milestone, or a distinct cue per phase? The first is moodier, the second is more legible.

---

## H. Verification

End-to-end smoke test:
1. F5 in Godot 4.6: player spawns at habitat, can walk to all five station types.
2. Manual cycle: grab Aerolume seed → plant → water → wait 25s → pollinate when window opens → harvest → deliver. Atmosphere meter ticks +1.
3. Deliver 3 Aerolume → Tier 1 toast fires, drones visibly spawn at hive, next pollination window auto-completes.
4. Continue to Loamspine; deliver 2 → Tier 2 toast, plots auto-water (canister becomes optional).
5. Continue to Tidefern; deliver 2 → Tier 3 toast, bloomed plots auto-load crates near hub.
6. Hit all three terraforming quotas (12 / 6 / 3) → world transforms (skybox, ground, lake) → win cinematic plays.
7. Total run time: 7–12 minutes.
8. `godot --headless --export-release "Web" out/index.html` from `worldseed/` produces a working web build (matches CI expectations).

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
