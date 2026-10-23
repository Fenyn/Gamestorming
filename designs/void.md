# VOID - Godot rebuild

Source: Unity project `F:\UnityNVME\Projects\PSXBunker` (design doc `docs/GAME_DESIGN_DOCUMENT.md` v2.0, 2026-01-20; last commit 2026-02-02 "Starting smelting room"). The Unity build stopped at phase 5 of its roadmap: FPS player, tetris grid inventory, station resource pool, power routing UI and quests 1 and 2 worked; smelting room was being built; the ship and asteroid field were never started.

This document is the Godot version. Where it differs from the Unity design, the change is listed in section 7.

---

## 1. Concept

A PSX-style station game. You wake alone on a dead mining station. In first person you explore dark rooms, fix the generator, route power, run furnaces and buy upgrades. From the ship bay you fly a small ship into an asteroid field, laser asteroids for ore, and bring the ore back to the station pool. Ore becomes ingots, ingots become upgrades, upgrades open rooms and speed up mining, and drones eventually mine while you work inside. No enemies in the first slice.

Tone references: Alien Isolation corridors, Dead Space industrial interiors, Freelancer-style peaceful ship flight.

## 2. Core loop

Station (first person): locker gives tools, wrench repairs the generator, terminal routes power, furnaces turn ore into ingots, terminal spends ingots on upgrades, upgrades unlock rooms.

Field (ship): fly to asteroid, hold laser, pick up ore chunks into ship cargo, fly back to the bay, unload into the station pool.

## 3. Systems

### Station pool
One dictionary of resource id to count, station wide, no cap. Iron Ore, Copper Ore, Titanium Ore, Iron Ingot, Copper Ingot, Titanium Ingot, Fuel. Shown as a HUD block of label and value pairs. Mining unload, furnace output, storage bins and drones add to it. Furnaces and the upgrade terminal take from it.

### Toolbar
Wrench, Flashlight, Keycard, Fuse, Wires, Battery, Exoskeleton. Picked up into a toolbar of slots (number keys), one held at a time. The held tool shows as a first-person mesh. Exoskeleton: slower walk, can lift debris, blocks the other tools while worn. Decided 2026-10-21, replaces the Unity tetris grid.

### Furnaces
Two in the smelting room. Each runs one recipe at a time. Recipes pull from the pool at start and push to the pool at finish.

| Recipe | In | Out | Time |
|---|---|---|---|
| Iron | Iron Ore 2 | Iron Ingot 1 | 10 s |
| Copper | Copper Ore 3 | Copper Ingot 1 | 15 s |
| Titanium | Titanium Ore 3 | Titanium Ingot 1 | 20 s |
| Fuel | Copper Ore 5 | Fuel 10 | 5 s |

### Power
Total 100, generator repair raises it to 200. Engineering 20 (always on), Smelting 30, Ship Bay 15, Equipment Bay 10, Fuel Processing 25. A slider per room on the engineering terminal. A room under its need goes dark and its machines stop.

### Rooms and unlocks
Bunk, Locker hub, T-junction hallway, Engineering, Smelting, Ship Bay (opens after quest 4), Generator Room (debris, needs exoskeleton), Equipment Bay (needs the Manufacturing Device from the derelict event, mid game), Fuel Processing (bought with ingots, mid game).

### Ship
RigidBody3D, thrust W/S, yaw A/D, pitch Q/E, boost Shift (fuel), laser on left mouse. Camera behind the ship at 10 m. Cargo is a count with a cap (50, upgrade to 100). Unload at the bay marker sends cargo to the pool and returns to the station scene.

### Asteroids
50 to 100 per field, spawned in a sphere. Small 5 ore, medium 15, large 50. Iron 70 %, Copper 25 %, Titanium 5 % (rare fields only). Laser extracts 1 ore/s (upgrade to 3), chunks float off and are picked up by a ship-side Area3D.

### Upgrades
Exoskeleton (Iron Ingot 10), Generator repair (Iron Ingot 20, +100 power), Thrusters (Iron 15, Copper 10), Cargo (Iron 10), Laser (Copper 20), Fast Smelting (Titanium 10), Drone MK1 (Iron 50, Copper 30, 5 ore/min), Drone MK2 (Iron 100, Titanium 20, 15 ore/min), Equipment Bay install (Iron 25), Fuel Processing (Iron 30, Copper 20), Navigation (Iron 50, Copper 50, Fuel 100). Slice win: buy Navigation and reach the Titanium field.

### Tutorial quests
1. Repair the generator: locker, wrench, engineering panel.
2. Check the furnaces: smelting room is dark.
3. Route power: terminal slider to 30 for Smelting, pull the furnace lever.
4. Process ore: bins give Iron Ore 10 and Copper Ore 15, run both furnaces.
5. Find more ore: ship bay opens, fly, mine 20 iron and 10 copper, unload.

Prompts follow the repo rule: step text and button text only, reasons go in hovers.

## 4. Assets

The look is not tied to the Unity project's PSX packs (user, 2026-10-21). Three directions are on the table, preview sheets in hand:

A. Clean low-poly station: Ozea Studio Ultimate SciFi Asset Library, `F:\UnityNVME\Art\Models\Ozea_Studio_Ultimate_SciFi_Asset_Library\` (5 packs, 398 fbx, white panels with orange and cyan trim, walls, doors, floors, terminals, railings; licence allows commercial use, no resale).
B. PSX grime: the packs in the table below.
C. Colourful low-poly base: Low Poly SciFi Planet, `G:\Godot\asset packs\SciFi Base\Sci-Fi_Planet_GLB\` (259 glb: modules, 20 buildings, laboratory, medical, agro and device props, 5 vehicles, crystals, alien plants).

Characters and animation for any direction: Quaternius Universal Animation Library (CC0, Godot glb in `F:\UnityNVME\Art\Models\Quaternion\Universal Animation Library\...\Unreal-Godot\`) and the Ultimate Animated Character Pack (gltf). Effects: PolyBlocks EffectBlocks in `F:\UnityNVME\Art\GodotVFX\`. Skyboxes: `F:\UnityNVME\Art\Skybox\Cubemap\` (20 cubemaps). Audio for any direction: Echoes kit below.

The table below is direction B. Every PSX pack ships `.glb`, which Godot imports directly.

| Need | Pack | Path under `F:\UnityNVME\Art\PSX\` |
|---|---|---|
| Walls, floors, doorways, stairs, tunnels, lamps | Modular Retro FPS Kit v1.5 | `Modular Retro FPS Kit v1.5\` (44 glb) |
| Bunker walls, blast door, generator_1, machinery_1-3, metal shelves, pipes, crates, computers | PSX Bunkers v1.8.8 | `PSX Bunkers v1.8.8\` (83 glb) |
| Terminal, control panel, fuse box, levers, gauges, buttons, screens | PSX Tech v1.2.3 | `PSX Tech v1.2.3\` (63 glb) |
| Furnace | furnace-door-dyad-arkana | `furnace-door-dyad-arkana\` |
| Ship | Free Battle Spaceship 3D Models (Corvette_01 to 05) | `Free Battle Spaceship 3D Models\` (fbx, craftpix licence) |
| Extra props | PSX Mega Pack 3.1.2 / II | 489 glb |
| Textures (metal, rock for asteroids, dither UI) | PSX Textures v3.0, II | 419 png |
| Audio (hum, footsteps, hiss, beeps, laser) | Echoes - Audio Super Kit v1.9.9 | 465 ogg |
| Skybox | `F:\UnityNVME\Art\Skybox` | |

Asteroids have no pack. They are a Godot SphereMesh with noise displacement and a PSX rock texture, built once as a scene per size.

Characters_psx (79 rigged fbx) is not needed for the first slice (first person, no NPCs). It is the source for crew or intruders later.

Licences to check before shipping: PSX Tech and PSX Textures carry a "Game Asset License Agreement.pdf", the spaceship pack is craftpix.net, the rest have no licence file in the folder.

## 5. Look

Low resolution, nearest filtering, hard shadows, no AA, vertex snap and affine texture mapping on world meshes, dither and vignette on top. Flickering bulb in the bunk, green emergency light in engineering, red floor strips in hallways, orange furnace glow when running, one cold blue sun in the field.

Done with built-in pieces: a SubViewport at 320 by 240 stretched to the window, an Environment resource, one spatial shader applied as the material override on imported meshes, one CanvasItem shader for the dither pass.

## 6. Build

Project `G:\Godot\Gamestorming\void\`, Godot 4.6.2, GDScript, clean slate (no code carried from Unity or other repo prototypes). Implementation is done by Opus agents briefed from this document; Claude orchestrates and reviews. Any design change gets the user's sign-off first.

Scenes: `station.tscn` (rooms as child scenes assembled from pack glb in the editor), `asteroid_field.tscn`, `ship.tscn`, `player.tscn`, `asteroid_small/medium/large.tscn`, `furnace.tscn`, `terminal.tscn`. Autoloads: `Pool` (station resources), `Quests`, `Upgrades`, `SaveGame`. Data: recipes, upgrades and quests as `.tres` resources.

Order of work, each step runnable before the next:

1. Spike the look: one room from the FPS kit, PSX shaders, player walking. Stop if the pack pieces do not snap or the shader looks wrong.
2. Spike the ship: field scene, flight, laser, chunk pickup, cargo count.
3. Station rooms, doors, lighting, interaction prompts.
4. Pool, bins, furnaces, HUD.
5. Terminal: power sliders, upgrade list.
6. Scene hand-off bay to field and back, unload.
7. Quests 1 to 5.
8. Exoskeleton, debris, generator repair.
9. Drones, Fuel Processing, Navigation, Titanium field.
10. Save and load.

## 7. Changes from the Unity design

- Tetris grid inventory dropped for tool slots. The grid held seven non-stacking items with no weight limit, so it cost a lot of UI for little play. Lockers become plain pickup points. The grid can return later as its own slice if wanted.
- Ship cargo, pool and recipes are unchanged.
- Asteroids are generated meshes, not pack models, because no pack has them.
- Scene list and script list from the Unity doc are replaced by section 6.

## 8. Decisions

Settled 2026-10-21: name `void` (folder `void/`, no script or class uses the word since it is a GDScript keyword), toolbar inventory, new project icon, Opus agents implement.

Open:
- Art direction A, B or C (section 4).
- Ship view: the Unity doc has the ship in third person. First-person cockpit is the other option.
- Nothing from the Unity C# is ported. If any of its data (quest steps, recipe numbers) should be read back, it is in `Assets/ScriptableObjects` and `Assets/Scripts`.

## 9. Risks

- Pack pieces may not share a grid size across the FPS kit and the Bunkers pack. Step 1 checks this before any room is built.
- The Corvette models are fbx, not glb. Godot imports fbx through its FBX2glTF path, which needs the converter set in editor settings.
- Vertex snap on skinned or animated meshes looks wrong. The first slice has none.
- Scene hand-off between station and field must keep the pool, quests and upgrades alive. Autoloads cover it, but the ship scene must not hold any state of its own past unload.
