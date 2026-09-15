The main game now hosts this crawl through `scenes/run/dungeon_run.tscn`.
F5 starts party selection and the three-floor campaign run. The host owns combat rewards,
recruitment, boss ward refill, and campaign persistence. Each descent keeps the party and
resources while generating a fresh dungeon from the run's floor seed.
The standalone test below still builds a temporary party and ends after one floor.
The original node-map run is preserved at `scenes/run/run.tscn`.

# Ward-station dungeon experiment

Open `dungeon_test.tscn` and press F6. This isolated twelve-room floor does not write campaign progress. Resolve the receiving-hall event, then click the world-space doorways. Hover an exit for its status and crossing cost. Each crossing, including backtracking, consumes five ward. The refuge offers one long rest before the terminal ward chamber. Defeat its guardian and use Descend stairs.

## Facility and encounters

The floor is an abandoned underground ward station. `StationPlan` describes physical functions independently of `RoomFamily`, which retains the encounter assignment. A barracks can therefore host combat or a discovery. Events describe the current room's purpose; the entrance introduces the floor's history once.

The functional backbone connects receiving to the checkpoint, barracks to the mess hall, mess hall to kitchen, kitchen to cistern, and maintenance to refuge and ward chamber. Two randomized maintenance connections add loops. The whole plan rotates, room sizes and furnishings vary, and encounter assignments shuffle. Elite encounters are placed at the greatest available depth, away from public access. This first facility has a fixed set of twelve functions; optional room selection and nonrectangular exterior shells remain future work.

One seeded abandonment history applies throughout the floor: flooding, evacuation, or ward failure. Related rooms receive muddy service floors and leaks, packed belongings, or discarded components. Scavenger sleeping places mark reuse of the living and storage areas. Enemy rosters follow room purpose, while encounter difficulty and rewards follow the assigned encounter. These environmental details currently have no additional interaction or reward mechanics.

## Room construction

The purpose prefabs in `rooms/` own size ranges, palette references, and generation settings. `StationRooms` constructs complete furnishing groups rather than random cover bumps:

- Receiving: inspection desk, notices, waiting bench, and luggage; a screened office arrangement is available.
- Checkpoint: duty desk and screen, weapon cabinet, resting bench, and stove.
- Barracks: wall-aligned beds or bunks, footlockers, washstand, stove, and sleeping-bay partitions.
- Mess hall: long tables with benches, dishes and cups, hearth, and pantry shelving. Door requirements can split a long table into smaller groups.
- Cistern: a substantial reservoir, stone coping, maintenance crossings, pumps, pipes, and a repair bench.
- Ward chamber: a large ward installation, operating desks, service bench, and stairs. Its approach faces the installation when the room has one entrance.

Stores, kitchen, workshop, maintenance, shrine, and refuge use supporting recipes. `DungeonProp.Station` builds the furniture meshes using the existing texture palettes. Recipe variations include orientation, furnishing arrangements, and single/bunk sleeping spaces.

The builder reserves actual door approaches and the party arrival area. Furniture occupies matching wall tiles, and every solid group is checked for connectivity before placement. Main furnishings have alternate positions rather than silently disappearing. Reservoir area leaves maintenance space. Walkable floors remain flat; there are no generic tactical plateaus in station rooms. Encounter deployment still uses the existing entry-side deployment planner.

`LayoutVariant` selects an arrangement (-1 for seeded selection, or 0/1/2). The old tactical generator remains available through `RoomVariation(StationRooms: false)`. The separate combat comparison scene offers a furnished checkpoint or an open diagnostic board at 12/14/16 tiles.

## Placement and validation

`DungeonPlacement` packs generated room bounds without overlap and keeps doorway sockets aligned. Touching rooms share a short threshold connection; remaining gaps receive stone passages. Only active-room exits are pickable. Interior meshes persist across revisits, and combat borrows their height map.

Build with `dotnet build Delve.csproj -c Debug -p:BuildProjectReferences=false --no-restore` when the referenced engine is already built.

- `dungeon_spike`: 3,240 station purpose/history/arrangement/door combinations, defining-furnishing checks, functional adjacency, deterministic generation, compact placement, all supported sizes, and live travel/revisit/restart/depletion checks.
- `dungeon_combat_spike`: 48 engine battles and large-creature deployment checks.
- `dungeon_flow_spike`: live scene encounters, results, travel, refuge, guardian, and stairs.
- `dungeon_shot_spike`: rendered checks and all twelve purpose-prefab captures at `.godot/station_room_*.png`.

Use the README's Godot invocation with a workspace log path. Captures require a rendered run. These checks establish generation and integration; player testing is still needed to judge the pacing and room feel.
