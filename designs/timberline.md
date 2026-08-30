# Timberline

A first-person lumberjack game that is part simulation, part incremental. You start with an axe, a cabin, and a forest plot. Fell a tree with repeated chops, knock the branches off, buck the trunk into logs, split them into firewood, and carry the chunks to the roadside bin to sell. Every stage of that chain is physical — wood is real objects you carry in your arms — and every stage can eventually be upgraded and automated, culminating in rolling whole logs into the river and letting a waterside sawmill do the rest. The forest itself is the progress bar: the clearing you carve out of it is the save file you can see.

**Engine:** Godot 4.6 (3D, Forward Plus, greybox primitives)
**Genre:** First-person sim + incremental
**Setting:** A forested plot on a hillside — cabin and road below, river along the far edge
**Inspirations:** Green Bean (diegetic, tactile first-person), incremental staples (automate the verb you're tired of), A Short Hike (small handcrafted scope), Lumberjack's Dynasty (fantasy, minus the bloat)

---

## Design Pillars

1. **The pipeline is the game.** Standing tree → felled trunk → delimbed log → bucked segments → processed product → hauled → sold. Each stage is a distinct verb with its own upgrade/automation path. The incremental arc is the player automating stages one at a time.
2. **An incremental played through your hands.** Numbers go up, but until you automate a stage you physically do it. Chunks, logs, and planks are RigidBody3D objects — carried, dropped, stacked, rolled, floated. No abstract inventory.
3. **The map is the progress bar.** Cleared land, stumps, buildings, and paths make progress visible from anywhere. No forest = you win (v1).
4. **Zen sandbox.** No stamina, no day/night, no timers, no failure states. The only limiter is your own throughput — which is exactly what upgrades sell you.
5. **Each product tier makes the previous tier's labor feel automatable.** Planks make manual bucking feel slow; furniture makes manual sawing feel slow. Demand for the next tier funds automating the last one.

---

## Core Loop

```
Fell tree → delimb → buck into logs → process (split/saw/craft) → haul → sell at bin
   ↓                                                                        ↓
cleared land (visible progress)                                      money → upgrades
                                                                            ↓
                                     better tools / stations / hauling / automation
                                                                            ↓
                                        clear faster, reach higher product tiers
```

**Primary resource:** Money (from wood sold at the delivery bin)
**Physical resources:** Chunks, logs, planks, goods — real objects in the world, never counters (until sold)

---

## The Five Verbs

Every interaction in the game is one of five verbs. Each has a fully manual v1 form and an automation arc. Chopping is **simple repeated clicks** — no timing minigames; skill expression is spatial (where you stand, where things fall, how you route your hauling), not dexterity.

### 1. Fell

**Manual:** Walk to a standing tree, click the trunk repeatedly. Each hit thunks, chips fly, and a wedge-shaped notch visibly grows. On the final hit the tree tips **away from the player** and falls under physics — where you stand decides where it lands. Dropping a tree toward the river, downhill, or onto open ground is free emergent strategy.

**Automation arc:**

| Tier | Tool | Effect |
|---|---|---|
| 1 | Rusty axe | ~10 chops per tree |
| 2 | Steel axe | ~6 chops |
| 3 | Felling saw | ~3 chops, wider trees unlocked |
| 4 | Chainsaw (late) | hold-to-cut, seconds per tree |

### 2. Delimb

**Manual:** A fallen tree has 4–6 branch nubs along the trunk. Click each to pop it off. Branches drop as small physics sticks — sellable as kindling for pocket change, or left to despawn.

**Automation arc:** better axes delimb in one hit; the sawmill (endgame) accepts un-delimbed trunks and strips them itself.

### 3. Buck

**Manual:** A bare trunk shows cut markers every couple of meters. Click a marker repeatedly to saw through; the trunk splits into separate log RigidBodies that thud onto the ground and can roll downhill.

**Automation arc:** saw tiers reduce clicks per cut → a sawbuck station (drop trunk on it, it bucks automatically over a few seconds) → the sawmill takes whole trunks.

### 4. Process

Processing stations convert wood between product tiers. Each is a physical station in the world: place input on it, click (or wait, once powered), take output.

| Station | Input → Output | Unlock | Manual form | Powered form (later) |
|---|---|---|---|---|
| Chopping block | log → 4 firewood chunks | start | place log, click to split | mechanical splitter: feed logs, chunks pile up |
| Sawpit | log → 2 planks | first major purchase | place log, click to saw | water-powered sawmill (endgame) |
| Workbench | planks → furniture/goods | plank-era purchase | place planks, click to craft | powered workshop (post-v1) |

### 5. Haul

The hidden star of the game. Wood must physically travel from where it fell to stations and to the bin.

**Manual:** Click a chunk/plank to add it to your visible armload (stacked in front of the camera, Green Bean style but multi-item). Carry capacity starts at 2 chunks or 1 log-end drag. Click to drop or toss.

**Automation arc:**

| Tier | Method | Effect |
|---|---|---|
| 1 | Arms | 2–3 items; logs must be carried one at a time on the shoulder |
| 2 | Wheelbarrow | push a physics wheelbarrow, holds ~8 chunks / 4 planks |
| 3 | Hand cart | bigger, holds logs |
| 4 | Log chute | build downhill chute segments; logs slide themselves |
| 5 | The river | roll logs in anywhere upstream; they float to the mill |

---

## Product Tiers & Economy

Money enters the game only through the **delivery bin** — a big crate by the road at the cabin. Toss wood in; it despawns with a cha-ching and pays out per item. (Flavor: a buyer's truck collects it; no truck is simulated in v1.)

| Product | Made from | Steps from tree | Value | Role |
|---|---|---|---|---|
| Kindling (branch) | delimbing | 2 | $1 | pocket change, tutorial money |
| Firewood chunk | log @ chopping block | 4 | $5 | early-game workhorse |
| Log (raw) | bucking | 3 | $8 | sellable whole, but processing pays more |
| Plank | log @ sawpit | 4 | $25/ea (2 per log) | mid-game; makes hauling volume the bottleneck |
| Furniture/goods | planks @ workbench | 5+ | $150+ | late-game; makes plank throughput the bottleneck |

Tuning intent (not final numbers): each tier should be roughly **3–5× value per log** over the previous, at the cost of one more processing step and more hauling. The moment a player unlocks a tier, the previous tier's manual step becomes the obvious tedium to automate — that pull is the whole economy.

Buildings and stations are bought with money but **delivered as kits to the bin** — flavor that keeps the loop physical without requiring a construction system in v1.

---

## Upgrade Axes

Four independent tracks, purchased at a catalog posted inside the cabin (diegetic — a paper catalog on the wall, crosshair-click to browse/order):

1. **Tools** — axe tiers (fewer chops to fell/delimb), saw tiers (fewer clicks to buck/saw)
2. **Body** — carry capacity (+1 armload slot each), walk speed while loaded
3. **Stations** — chopping block → splitter; sawpit → sawmill; workbench → workshop; per-station speed upgrades between forms
4. **Logistics** — wheelbarrow → cart → chute segments → river access (clear the brush along the bank)

A satisfying buy should arrive every few minutes early on, stretching to ~10 minutes by plank era.

---

## World Layout

One handcrafted map, small enough to sprint across in ~30 seconds:

```
        [ dense forest — uphill ]
   ~~~~~~~~~~ river ~~~~~~~~~~~~   ← far edge, flows left→right
        [ mill site (locked) ]  ↓ downstream
  [ forest plot: ~40–60 trees ]
[ cabin ] [ chopping block ]
[ delivery bin ]
======== road ========
```

- **Cabin:** spawn point, upgrade catalog on the wall. No interior needed in v1.
- **Forest plot:** 40–60 trees in loose bands — nearest trees are a 5-second walk from the block, farthest a 30-second walk. Distance is the natural difficulty curve: the forest recedes from you as you clear it, making hauling upgrades progressively necessary.
- **Slope:** the plot tilts gently toward the river/road, so felled logs and dropped chunks tend to roll the right way — physics as an ally.
- **River:** visible from the start (the endgame is always on the horizon), unusable until Logistics unlocks clear the bank.
- **Mill site:** a flat riverside pad downstream with a "SAWMILL — COMING SOON" flavor from day one.

---

## Endgame: The River

The full-automation fantasy that the whole game points at:

1. **River access** (logistics unlock): clear brush along the bank — rolling a log into the water now floats it downstream.
2. **Log boom** (mill prerequisite): a floating barrier at the mill site that catches drifting logs.
3. **Water-powered sawmill** (capstone purchase): pulls caught logs in, delimbs, bucks, and saws them into planks automatically, stacking output beside the bin.

Final state of the loop: fell a tree so it drops toward the water, shove the trunk in, walk back to the next tree. Everything between splash and sale is automated. "Done" (v1) = the plot is clear; a simple end screen tallies trees felled, money earned, and time played over a view of the clearing.

---

## Physics & Object Budget

- All wood items are `RigidBody3D` with simple collision (cylinders for logs, boxes for chunks/planks). Bodies sleep aggressively; distant sleeping wood swaps physics off entirely.
- Sold wood **despawns at the bin** — the primary population valve. Piles left lying around are the player's own clutter to manage (and a soft nudge to sell).
- Standing trees are `StaticBody3D` + script; a tree becomes a rigid trunk only during its fall, then the trunk settles to sleep. Bucking swaps one body for N log bodies at the cut positions.
- Target budget: < 150 live wood bodies; the fun (big log piles, chunk avalanches, river drives) lives comfortably inside that.
- River flotation is faked: buoyancy + a constant downstream force in a water `Area3D`. No fluid sim.

---

## Deferred / Future

Recorded so v1 doesn't design against them, specced later:

- **Prestige — regrowth:** replant/regrow the cleared plot as the reset mechanism (design open: what carries over, what multiplies). Explicitly deferred.
- **New plots:** adjacent land with denser/bigger/exotic trees after clearing the first.
- **Hired workers:** NPC lumberjacks as post-machine automation. Machines first; workers are far-future.
- **Vehicles:** a drivable truck or tractor between cart and chute tiers.
- **Ambience:** day/night, weather, seasons — atmosphere only, never pressure.

---

## Phasing

### Phase 1a — Manual loop through planks (v1 build target)
- FPS controller (Green Bean pattern: WASD + mouse look, E interact, click primary)
- Fell / delimb / buck on physics trees; chopping block; multi-item armload carry
- Delivery bin selling, money HUD, cabin catalog with Tool/Body tiers 1–2
- Sawpit + planks; wheelbarrow (first physics hauler)
- 40–60 tree plot, slope, river visible but locked

### Phase 1b — The river
- River access, log flotation, log boom, water-powered sawmill
- Log chute segments; end screen when the plot is clear

### Phase 1c — Goods era & powered stations
- Workbench → furniture tier; mechanical splitter; sawbuck; cart
- Balancing pass on the full economy

### Phase 2 — Prestige & plots
- Regrowth prestige design, adjacent plots, long-game structure
