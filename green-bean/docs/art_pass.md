# Art Pass — Kenney Base + Blender Gaps

First art pass on the espresso stand. Kenney CC0 models replace the room, counters, fridge and milk jug. Every bench-top station and most carriable items are still grey-boxed and are listed below as specs for custom Blender models.

## What changed

| Area | Before | Now |
|---|---|---|
| Floor inside the stand | `Platform` CSG box | Kenney `floorFull` (StaticBody3D collision unchanged) |
| Back wall | CSG box | Kenney `wall`, recoloured cream |
| Side walls | CSG boxes | Kenney `wallWindow`, recoloured cream |
| Front counter | CSG box | 4× Kenney `kitchenBar`, squashed to 0.2 m deep |
| Back counter | Floating CSG slab | Same slab (recoloured to match), with 3 Kenney base cabinets under it |
| Fridge station | CSG box | Kenney `kitchenFridgeSmall` (mini fridge), node `Model` |
| Milk jug item | CSG cylinder + handle | Kenney `carton` |
| Decor (new) | none | 2 upper cabinets, 2 ceiling lamps with warm OmniLights, backstock box, pastry plates, 2 outdoor tables with chairs, 2 potted plants, trash can |

Collision shapes and station positions did not move. Gameplay geometry is the same as the grey-box build.

Decor sits under the `Decor` node in `espresso_stand.tscn` and has no collision. Outdoor seating is on the left (x ≈ -3) so it stays out of the customer walk path from (3, 0, 5) to the register and pickup spots.

## Customers

Customers are Kenney Animated Characters (CC0): one rigged model with idle and run animations, in `assets/models/characters/`.

- `customer.gd` picks one of 10 skins at random, plays idle while standing and the run animation at 55% speed while walking.
- The 10 skins in `assets/models/characters/skins/` are made by `tools/make_customer_skins.py` from three Kenney skins (`skaterMaleA`, `skaterFemaleA`, `criminalMaleA`). It changes skin tone, hair, shirt and trouser colours by atlas region. The other Kenney skins are zombies, a cyborg, or have dirt and blood stains, so they are left out.
- Customers now enter and leave 8 m to the right along the sidewalk (`customer_spawner.gd`), so they walk into view instead of appearing next to the stand. This adds about 4 s of walking each way.

## Street

The 8 m grey ground is now a 60 m grass field with a sidewalk, curbs and a two-lane road in front of the stand. All of it is under the `Street` node in `espresso_stand.tscn` and has no collision.

- Kenney Car Kit: parked sedan and taxi on the near side, van and delivery truck on the far side.
- Kenney Nature Kit: a tree line behind the stand, trees at the sides, bushes around the stand, flower planters.
- Kenney Fantasy Town Kit: street lamps along the curb, two market stalls and a bench.
- Light fog in the Environment so distant trees fade.

## Files

- `assets/models/kenney/*.glb` — baked models. 1 unit = 1 m, origin at bottom centre, front faces +Z.
- `assets/models/kenney/LICENSE_*.txt` — Kenney CC0 licences. Credit is optional.
- `tools/kenney_manifest.json` — the list of imported models with scale and colour overrides.
- `tools/kenney_import.py` — rebuilds every model in the manifest. Usage is in the file header.

The importer exists because Kenney's glTF files have three problems in Godot:
1. They use `KHR_materials_unlit`, so Godot would render them flat with no shading or shadows.
2. Their colours are stored as sRGB where glTF expects linear, so Godot would wash them out.
3. Furniture Kit is at half scale and has its origin at a back corner.

## Convention for station models

`StationUtils.create_status_label()` now also measures a child node named `Model`. Name the visual node `Model` when you swap a station's grey box, and the status label will sit in front of it like it does for grey boxes.

Station origin is the centre of the grey box (bottom at `-height/2`). The player faces stations from +Z.

## Custom models (built in Godot)

Blender can't be installed in the cloud session, so custom props are generated once from primitive meshes by scripts in `model_src/` and saved as normal Godot scenes in `scenes/props/`. Nothing is generated at runtime. Open the scene in the editor to move, resize or recolour any part: every piece is a MeshInstance3D with its mesh and material stored in the scene. Materials of the same colour are shared, so changing one recolours all parts that use it.

- `model_src/model_kit.gd`: helpers (box, cylinder/cone, sphere, torus, group) and Kenney-matched colours.
- `model_src/<model>.gd`: one script per model with a static `build()`.
- `model_src/build_models.gd`: writes any missing scenes. It never overwrites an existing scene unless you pass `-- --force <name>` (or `all`), so editor changes are safe. Run from the green-bean folder: `godot --headless --path . --script res://model_src/build_models.gd`.

| Scene | Used by | Notes |
|---|---|---|
| `scenes/props/hand_grinder.tscn` | `grinder.tscn` (instance named `Model`) | Grouped as Base, Body, Spout, Hopper, CrankMount, plus `Crank` (the station rotates it about X while grinding), `DevicePad` (Marker3D where the dripper or aeropress is set down) and `SpoutTip` (Marker3D where grind dust falls). Move those three in the editor and the station follows. Devices are lifted by half their height so they sit on the pad. |

| `scenes/props/steam_station.tscn` | `steam.tscn` (instance named `Model`) | Compact standalone milk steamer modelled on real units like the Morning Dream (about 10 cm wide, 37 cm deep, 24 cm tall): narrow tower at the back, a head that overhangs the pitcher with a control panel on top and a steam lever on the side, a wand angled down into the pitcher, an IR temperature sensor under the head, a small drip tray, and a mat for the spare pitcher. Depth is squeezed to fit the 0.2 m collision box. Markers: `PitcherPad`, `PitcherRest`, `SteamVent`, `CameraView`. The wand is one node, `Wand`. |

Station scripts read markers with `StationUtils.model_marker(station, "Name", fallback)` and stand items on them with `StationUtils.item_half_height(item)`.

Any of these can be replaced by a Blender model later: keep the instance name `Model`, the origin at the centre of the collision box, +Z as the front, and the marker nodes listed above.

## Still grey-boxed: Blender specs

Sizes are the current grey box and collision. Slot positions are local to the station origin and are set in the station scripts, so a model must leave those spots clear or the scripts need new numbers.

### Stations

| Station (scene) | Box W×H×D (m) | Slots and spawned items (local) | Notes |
|---|---|---|---|
| Aeropress (`aeropress.tscn`) | 0.2×0.3×0.2 | cup (0, 0.15, 0), device (0, 0.25, 0), shelf device (0.15, 0.18, 0) | Cup sits on top. Device sits above the cup. |
| Pour Over (`pour_over.tscn`) | 0.25×0.25×0.25 | cup (0, 0.12, 0), dripper (0, 0.22, 0), shelf dripper (0.15, 0.15, 0) | Brew stand. Camera looks almost straight down. |
| Hot Water (`hot_water.tscn`) | 0.2×0.4×0.2 | shelf kettle (0.12, 0.2, 0) | Kenney `kitchenCoffeeMachine` is imported but not used, because the kettle spot overlaps it. |
| Register (`register.tscn`) | base 0.3×0.2×0.25, collision 0.45×0.45×0.3 | screen quad at (0, 0.36, 0), tilted, facing -Z | The SubViewport screen is built in `register.gd`. A model needs a screen bezel around that quad. |
| Cash Drawer (`cash_drawer.tscn`) | 0.25×0.1×0.2 | screen (0, 0.08, -0.10) | Faces the customer side. |
| Cup Stack (`cup_stack.tscn`) | 0.4×0.3×0.2 | cup spawn (0, 0.3, 0) | One stack per size is planned. |
| Hand-off (`hand_off.tscn`) | 0.4×0.1×0.2 | drink (0, 0.15, 0) | |
| Lid Dispenser (`lid_dispenser.tscn`) | 0.15×0.2×0.15 | none | Rotated 180° in the shop. |
| Counter Pad (`counter_pad.tscn`) | 0.38×0.02×0.38 tray | 4 slots at (±0.08, 0.04, ±0.05) | A rubber bar mat would work. |
| Syrup (`syrup.tscn`) | 0.2×0.3×0.15 | cup (0, 0.05, 0) | Pump bottle, cup sits in front at the base. |
| Sauce (`sauce.tscn`) | 0.2×0.25×0.15 | cup (0, 0.05, 0.05), bottle (0.12, 0.1, 0) | |
| Sauce Prep (`sauce_prep.tscn`) | 0.25×0.2×0.2 | bottle (0, 0.12, 0) | |
| Mocha Prep (`mocha_prep.tscn`) | 0.3×0.2×0.25 | bottle (0.15, 0.12, 0); jug, bag and stir bar visuals built in `mocha_prep_station.gd` | Jug and powder bag are scripted CSG and would need code changes. |
| Bottle Rack (`bottle_rack.tscn`) | 0.22×0.08×0.08 | 3 bottles at (-0.06/0/0.06, 0.06, 0) | |

### Carriable items (built in code, `scripts/items/`)

These are made with CSG in `_ready()`. Swapping one needs a small script change like the one in `milk_jug.gd`: preload the `.glb`, instantiate it, scale and offset it to match the collider.

| Item | Collider | Animated parts that the model must keep or replace |
|---|---|---|
| Cup | cylinder r 0.035–0.046, h 0.10–0.16 by size | `_fill_visual` liquid cylinder, lid state |
| Aeropress device | cylinder r 0.035, h 0.15 | `_plunger` moves, `_liquid` fills |
| Dripper | cylinder r 0.05, h 0.08 | `_fill_visual` |
| Kettle | cylinder r 0.035, h 0.12 + spout | tilted by the pour tween in `StationUtils` |
| Pitcher | cylinder r 0.04, h 0.12 | none |
| Sauce bottle | cylinder r 0.025, h 0.12 + cap | `_fill_mesh` |

### Other placeholders

- `Roof` is still a CSG box. None of the imported packs has a roof that fits the stand.
- Customers walk with the run animation slowed to 55%, because the pack has no walk animation.
- No textures anywhere. All Kenney models are flat-coloured.

## Not verified in Godot

This pass was done in a cloud session with no Godot install and no Blender. Layouts were checked with a software render of the `.tscn` files, not in the engine. On first open, Godot needs to import the new `.glb` files. Things to check in the editor:

- The `.glb` files import as scenes and show shading (not flat colour).
- `milk_jug.gd` preloads `carton.glb`. If the first open reports a missing resource, it should clear after the import finishes and the project reloads.
- Window frames and the squashed front counter look right at play height.
- The fridge status label sits in front of the fridge model.
- OmniLight brightness under the roof.
