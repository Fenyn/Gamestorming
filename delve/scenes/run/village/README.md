# The outpost village

`village.tscn` is the outpost screen's 3D world: `VillageStage` (a Control holding a SubViewport) with the sun, the environment, the camera, the town, the resident spots, the line-up and the clickable stations. `hero_select.tscn` instances it full screen.

## Town (`town.tscn`)

Baked once on 2026-09-30 from the approved village mock; edit it by hand from here on.

- `Terrain` is a `CampTerrain` with the village banks, smooth normals and a 60 u extent. `Ground` (`VillageGround`) hands `village_ground.gdshader` the worn yards, roads and stream for the current tier.
- `Props`, `Buildings`, `Forest` and `Lamps` hold the pieces. A piece at every tier sits directly under its category; any other piece sits under a `TierGate` named for its range (`Tier2to3`, `Tier1to1`, `Tier3to3Day`). A tree in `Tier1to2` is cleared when the Hamlet is built. `DayOnly` gates go in at dusk.
- Buildings, props and trees are instances of `assets/models/village/*.glb`. Their materials are the shared `.tres` files in `assets/models/village/materials/`; change a colour there, not in code.
- Lamps and door lights are `EveningLight`s: dark by day, lit and flickering in the evening.
- `Stops` holds the `CameraStop`s. Stops with `Order` 0 and up are the ones Q and E step through, west to east; `delve` frames party assembly and `overview` the whole town.

## Residents

- `spots.tscn`: `ResidentSpot` markers. Spots sharing an `Area` make one work area; `From` and `To` are the tiers at which it exists; `Seated` spots are for sitting, on their log's center line.
- A spot's `Use` (block, pile, anvil, bench, bed, pot, goods, hens, dummy) says what work it is for. It stands just clear of that prop, facing it. An activity step names the use it needs (`ActivityStep.At`), so the resident walks to a spot of that use before the step starts: the woodcutter swings only at the stump and stacks only at the pile. A spot with a use goes only to an activity that works there.
- `VillageSchedule` gives each resident an area and an activity per time of day. `VillageActivities` holds the activity loops. A resident whose area is unbuilt or full takes the first fallback with room.
- `Walkable` (`VillageWalkable`, a `NavigationRegion3D`) bakes a navigation mesh from the terrain and every piece built at the tier (meshes, plus billboards in the `village_obstacle` group), once per tier, about 0.3 s. Every resident, pick and hen walk follows its route. A new prop blocks walks by itself; a new billboard that should block joins `village_obstacle`.
- `VillageStage.Crowd` (`VillageCrowd`) holds every mover: residents, line-up picks and the hens (`VillageChicken`, wandering within `Range` of home). A walker that would come within arm's length of someone in the next 1.5 s veers away (keeping right head-on), slows behind someone close ahead, and passes a route corner that someone stands on. Veers stay on the walkable mesh. A resident held up for a second re-plans; after two it squeezes past along its route.
- Spare spots go to the free spot nearest a resident's first spot, so its walks stay short (the garden has four spots per side of the beds for this).
- `resident_figure.tscn`: `ResidentFigure` runs a driver (`ResidentRoutine` at home, `MarchRoutine` at the line-up); `ResidentSprite` draws it from the Mana Seed pages.
- `Lineup` (`VillageLineup`) holds the four slot markers and the entry path from offscreen.

## Checks

- `village_life_spike` (headless): every tier and time places the full roster, nobody shares a spot, everyone changes what they do at least twice a minute, work runs only at a spot of its use, walks stay on the walkable mesh, hens stay on it near home, and no walker overlaps another mover; two crowd cases (passing someone standing, meeting head-on) run on their own. Per tier it also checks that every spot stands clear of the pieces and can be reached from the hearth, every work spot faces its prop within 0.75 m, and the line-up lanes stay on the walkable ground.
- `village_shot_spike`: tier gating, lamps, day-only pieces, camera stepping and stations headless; with a window, the overview at every tier and time, the six stops at the Hamlet and three work strips.
