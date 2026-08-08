# Bulwark — Building Scene Authoring Guide

Step-by-step for building the staged 3D building scenes. Worked examples: the Command Post
(planning table, one tier today) and the Trading Post (broken → repaired → upgraded). Template:
`scenes/buildings/farmhouse.tscn` — the widest ladder, Stage0–Stage4.
System contract: `design/building_visuals.md`.

Almost every shipped stage is still a GREYBOX shell: box bodies, prism roofs, a `Label3D` name,
flat `StandardMaterial3D` colours. That is deliberate — each stage is its own `Node3D` subtree, so
finished art replaces one stage (or one whole building scene) at a time without touching anything
else. The Trading Post has already made that jump for all three of its stages: they instance
`assets/models/buildings/trading_post_stage{0,1,2}.glb`, PSX-kit models built by
`G:\crocotile-mcp\examples\build_psx_buildings.py` — flat-shaded low-poly on 64×64 Winlu-derived
tiles, matching the a_winlu kit the walls, terrain and props already use. Loose dressing is NOT
baked into those .glbs: each stage node carries `assets/models/psx_kit/a_winlu/*.glb` prop
instances, so a stage's clutter moves without a model rebuild.

## The rules that matter (read once)

- **Child ORDER under `%Stages` is the stage index.** Names (`Stage0`, `Stage1`…) are for
  humans; the code counts children. Never reorder after authoring.
- **Stage index ↔ tier** comes from data (`Buildings.cs` → each tier's `StageIndex`), not the
  scene. Trading Post tiers 1–2 map to stages 1–2; the Farmhouse's four tiers map to stages 1–4.
  Stage 0 is always the ruined/pre-commission look.
- **One origin for everything.** The building scene's own origin is its "feet": on the ground
  plane (y = 0), centred in X/Z. Author every stage relative to that — geometry grows upward in
  +Y and outward in ±X/±Z. Placing the building in the outpost is then just moving that origin.
- **One cell is one metre.** A modest cottage is roughly 4×3 m with a 2.5 m wall; the biggest
  shipped shell (Farmhouse tier 4) is 7×5 m.
- **Placement: instance-and-position is the primary workflow, a marker is the fallback.** Per
  CLAUDE.md's "objects placed in .tscn via editor" convention, drag the building scene directly
  into outpost.tscn as a child of the root and move it into place — no marker needed.
  `BuildingLoader` finds it by matching the instance's scene path against `Buildings.cs`'s
  `ScenePath` (never by node name — rename it freely, e.g. "Tavern" not "Building_tavern") and
  ADOPTS it: drives its stage/scaffold/overlays exactly like a spawned building, but never moves
  it. Only when NO pre-placed instance exists does the loader fall back to instancing the scene
  at a hand-placed `%Building_<id>` Marker3D.
- **Exactly one stage is visible at runtime** — toggle visibility freely in the editor to
  compare stages; the loader overrides it on placement.
- **Collision:** the shared `%Footprint` StaticBody3D blocks the building's cells at every stage,
  and it is also what makes those cells untillable (`OutpostScene.IsTillable` reads the footprint
  box). If a stage CHANGES the outline, give that stage its own StaticBody3D + shape inside the
  stage node — the system auto-disables colliders under hidden stages. Every shape is its own
  resource — never share a sub_resource between differently sized shapes.
- A stage/overlay child can be a whole Node3D subtree: meshes, imported models, `Label3D`,
  `OmniLight3D`, particles. Anything Node3D-rooted works.

## Part 1 — Command Post (`scenes/buildings/command_post.tscn`)

The one start-state building: its purpose is the planning table, and upgrade tiers are deferred
(`Buildings.cs` ships tier 1 only). Stages authored today: Stage0 (the ruin) + Stage1 (the hall),
both finished PSX-kit art — `assets/models/buildings/command_post_stage0.glb` / `_stage1.glb`,
built by `G:\crocotile-mcp\examples\build_psx_command_post.py` (both stages from one run). Loose
dressing is NOT baked in: each stage instances seven `assets/models/psx_kit/a_winlu/*.glb` props
in the .tscn, so clutter moves without a rebuild.

1. **Duplicate the template.** FileSystem dock → right-click `scenes/buildings/farmhouse.tscn`
   → Duplicate → `command_post.tscn`. Open it, rename the root node `CommandPost` (keep the
   BuildingInstance script attached).
2. **Match the stage count to the data.** `%Stages` needs `maxStageIndex + 1` children; extra
   authored stages are allowed (they simply never show until data uses them). Delete or add
   children at the END so the existing indices never shift.
3. **Build each stage.** Done for both: Stage0 is the collapsed HQ — the west third still standing
   two storeys, its roof holed with the rafters left spanning the gap, its wall ends stopping at a
   stepped course line, the rest stubs over its own fallen stone with one tattered banner still
   up — and Stage1 the restored hall: stone plinth, half-timbered ground storey, a storey band,
   a boarded upper storey, a 35-degree gable to a 6.4 m ridge (the tallest silhouette inside the
   walls, over a 3.6 m palisade), a wall dormer and chimney, and a porch with a hood, notice board
   and planning table on the +Z frontage under the `%Interact` marker. Stage1 carries its own
   `Porch` StaticBody3D because the porch reaches past the shared `%Footprint` (same pattern as
   the Trading Post's `LeanToBlock`). If upgrade tiers are ever designed, the arc continues: a
   war-room wing, an expedition annex, a resurrection dais.
4. **Footprint.** Size the `%Footprint` BoxShape3D to the walkable-blocking outline (a little
   larger than the tallest stage's body). If a later stage physically widens the building, put a
   StaticBody3D + uniquely-sized shape inside that stage node instead.
5. **Scaffold (optional but recommended).** A `Scaffold` Node3D sibling of `%Stages`, unique
   named (right-click → % Access as Unique Name): posts and beams around the footprint.
   NOTE: Command Post upgrades would be INSTANT (only trading_post/farmhouse/smithy/infirmary
   have construction days wired). To make them take Tharr-time, add `{ "command_post", 2 }` to
   the SetConstructionDays dictionary in GameState._Ready.
6. **Place it.** Preferred: in outpost.tscn, instance `command_post.tscn` as a child of the
   scene root (drag from the FileSystem dock) and position its origin on the ground where the
   building should stand — `BuildingLoader` finds it by scene path and adopts it, no marker
   needed. Fallback: a Marker3D named `Building_command_post`, right-click → % Access as Unique
   Name — the loader only instances the scene there when no pre-placed instance exists.
7. **Verify.** F6 the building scene (standalone-safe), then F5 the outpost.

## Part 2 — Trading Post (`scenes/buildings/trading_post.tscn`)

The broken → repaired → upgraded arc. Data: T1 general store (StageIndex 1), T2 expanded
store (StageIndex 2). Commission = 90 wood + 60 stone + 30 hardwood + 60g; 2 build days.

1. **Duplicate the template** → `trading_post.tscn`, root `TradingPost`.
2. **Three stages** (trim the template's extras from the END):
   - `Stage0` — THE BROKEN LOOK. Instances `trading_post_stage0.glb` at the origin (the model is
     authored centred on the footprint, base at y=0). The shop's west half still stands with a
     hole torn through its roof and bare rafters east of it; the east half is a stepped stub over
     its own fallen stone; the goods lean-to is down and reaches past the shared `%Footprint`, so
     Stage0 carries its own `LeanToBlock` StaticBody3D. The sign is still half-hung over the
     door — one link left, the board swung round and dangling (intro Scene 2). Visible in the
     world from day one, before any commission.
   - `Stage1` — repaired general store: stone plinth, half-timbered daub body, shingled gable,
     a porch on the frontage (its own `Porch` StaticBody3D) and the sign rehung straight.
   - `Stage2` — expanded store: a half-storey with loft windows, a wall dormer over the door, a
     framed canopy on both flanks of the frontage (`CanopyWest`/`CanopyEast` StaticBody3Ds), a
     stone chimney, and display goods under the canopies.
3. **Scaffold.** Add the unique-named `Scaffold` node — shown automatically during the 2-day
   commission build AND the 2-day tier-2 upgrade window (the store keeps trading during the
   upgrade; only the new tier's perks wait).
4. **Overlays (optional).** Add an `Overlays` container (unique name) with a `Winter` child —
   snow on the roofline, automatic every winter, zero data edits. Festival dressing or a
   permanent story change later = build the child + one `VisualRule` line in Buildings.cs.
5. **Footprint + placement.** Instance `trading_post.tscn` in outpost.tscn and position it
   (preferred), or add the fallback `%Building_trading_post` marker — same as Part 1.
6. **Verify the full arc in-game (F5):** day one shows the Stage0 ruin → commission at the
   planning table → scaffold rises, Tharr's busy line + build-panel countdown + calendar
   completion mark → completion toast → Stage1, Elara opens the store → (later) fund the
   tier-2 bundle, Upgrade → scaffold again for 2 days, store still open → Stage2.

## Quick reference

| Building | Scene | Placement (preferred) | Placement (fallback) | Stages needed | Notes |
|---|---|---|---|---|---|
| Command Post | scenes/buildings/command_post.tscn | pre-placed instance in outpost.tscn | %Building_command_post marker | Stage0–Stage1 | Tier 1 only in data; upgrade tiers deferred. Both stages are finished PSX-kit art |
| Trading Post | scenes/buildings/trading_post.tscn | pre-placed instance in outpost.tscn | %Building_trading_post marker | Stage0–Stage2 | Stage0 ruin visible pre-commission; scaffold on commission + upgrade |
| Tavern | scenes/buildings/tavern.tscn | pre-placed instance in outpost.tscn | %Building_tavern marker | Stage0–Stage3 | `lodging_repaired` forces Stage1 early (the repair payoff) |
| Farmhouse | scenes/buildings/farmhouse.tscn | pre-placed instance in outpost.tscn | %Building_farmhouse marker | Stage0–Stage4 | The widest ladder — use it as the template |
| (any other) | scenes/buildings/<id>.tscn | pre-placed instance in outpost.tscn | %Building_<id> marker | Stage0..max StageIndex in its tier data | Same recipe |

`BuildingLoader` tries the pre-placed instance FIRST (matched by scene path, never node name;
its position is never touched), then falls back to the marker. Neither a pre-placed instance
nor a marker/scene = skipped with a log line; state still works, art arrives whenever you get
to it.
