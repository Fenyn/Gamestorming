The main game now hosts this crawl through `scenes/run/dungeon_run.tscn`.
F5 starts party selection and the three-floor campaign run. The host owns combat rewards,
recruitment, boss ward refill, and campaign persistence. Each descent keeps the party and
resources while generating a fresh dungeon from the run's floor seed.
The standalone test below still builds a temporary party and ends after one floor.
The original node-map run is preserved at `scenes/run/run.tscn`.

# Forest glade crawl (floors 1 and 2)

Floors 1 and 2 use the same crawl as glades. `DungeonDirector.SceneryByFloor` picks a `CrawlScenery` per floor id (`crawls/fringe.tres`, `deepwood.tres`, `station.tres`): room prefabs, look scene, passage scene, the ground under the gaps, and the fog tiers (current glade lit, visited glades half-dim, unvisited neighbours dark). A room prefab builds through its `RoomShell`: `GladeShell` for glades, `MasonryShell` for station rooms.

`GladeGeneration` shapes a forest map generator board into a glade: a tree ring with trail mouths at ground level, relief capped near the ring, deployment boxes kept open, and in fight glades cover rocks, small 1x1 trees and broad trees that fill a 2x2 block like a Large creature. Every glade also gets undergrowth (`Run.Undergrowth`, through `GladeGeneration.Undergrowth`): trees that step in from the ring, brush (difficult plant terrain) beside them, and in glades without a fight a few small clumps in the open. Generated wilds combat boards grow the same undergrowth (`EncounterFactory.GrowUndergrowth`) with their deployment zones kept clear and no open ground cut off. Glades, trails and combat boards share one forest ground cover (`BackdropThemes.Forest`), which grows bushes only on brush. `GladeRecipes` sets the landform and landmarks per room purpose. `CrawlWordsTable` holds each floor's place names, histories, goals and exit words; `GladeScenes` holds the forest events. Open `forest_test.tscn` or `deepwood_test.tscn` and press F6 to walk a standalone forest floor.

Every floor starts with the party walking in from off the floor. The entrance gets an extra mouth on an outer side with no door (`DungeonFloor.ArrivalSide`, West first because no HUD panel covers that edge). The floor's `CrawlWords.ArrivalProp` dresses it: the Fringe's old road ends at the party's last camp, the Deep Wood's holloway runs between raised banks (`GladeShell.ArrivalBank`, `passage_holloway.tscn`), and the station's root stair comes down through the hall wall. A worn road crosses the entrance glade from the arrival mouth. The camera starts on the mouth and follows the party in; under a floor caption the walk waits until the caption clears. Choosing a doorway ends the walk early. `scenes/dev/glade_spike.tscn` checks the glade contract over 100 seeds and, rendered, photographs both floors.

# Ward-station dungeon experiment

Open `dungeon_test.tscn` and press F6. This isolated twelve-room floor does not write campaign progress. Resolve the receiving-hall event, then click the world-space doorways. Hover an exit for its status and crossing cost. Each crossing, including backtracking, consumes five ward. The refuge offers one long rest before the terminal ward chamber. Defeat its guardian and use Descend stairs.

## Facility and encounters

The floor is an abandoned underground ward station. `StationPlan` describes physical functions independently of `RoomFamily`, which retains the encounter assignment. A barracks can therefore host combat or a discovery. Events describe the current room's purpose; the entrance introduces the floor's history once.

The functional backbone connects receiving to the checkpoint, barracks to the mess hall, mess hall to kitchen, kitchen to cistern, and maintenance to refuge and ward chamber. Two randomized maintenance connections add loops. The whole plan rotates, room sizes and furnishings vary, and encounter assignments shuffle. Elite encounters are placed at the greatest available depth, away from public access. This first facility has a fixed set of twelve functions; optional room selection and nonrectangular exterior shells remain future work.

One seeded abandonment history applies throughout the floor: flooding, evacuation, or ward failure. Related rooms receive muddy service floors and leaks, packed belongings, or discarded components. Scavenger sleeping places mark reuse of the living and storage areas. Enemy rosters follow room purpose, while encounter difficulty and rewards follow the assigned encounter.

## Room scenes

Each quiet room offers one PF2e exploration scene from `StationScenes` plus Leave (Ward +5, the crossing refunded). DCs are authored at level 1 (15, hazards 17) and move with party level along GM Core DCs by level. All four degrees of success matter.

- Checkpoint: Decipher Writing (Society) reveals room kinds on the floor plan.
- Barracks, Kitchen, Cistern: a free ten-minute rest (the suggested schedule, no ward).
- Mess hall: Subsist (Survival) for a free rest and a healing potion.
- Stores: a poisoned-lock cache (Thievery, hazard DC).
- Workshop: Repair every damaged shield (Crafting, Player Core amounts).
- Maintenance: reconnect a ward conduit (Crafting) for Ward +15/+30.
- Shrine: Refocus for every caster (Religion).
- Refuge: Make camp, and once per floor Study the guardian (Recall Knowledge into the campaign journal).

Station history changes rules: a flooded Cistern becomes a dive for potions and the Kitchen rests twice; an evacuated Barracks also clears Wounded and the Shrine is haunted; a ward failure lowers the Maintenance DC and adds a live conduit in the Workshop. Healing potions are drunk on the spot, so no run inventory is needed. Hazard damage is a percentage of maximum HP until the GM Core hazard table is pulled. Outcome lines are functional placeholders until prose is approved.

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
