# PolyBlocks NatureBlocks v1

Low-poly nature asset pack for Godot 4 by bukkbeek (bukkbeek.github.io). Unpacked at
`F:\UnityNVME\Art\GodotVFX\PolyBlocks-NatureBlocks-[v1]\PolyBlocks`. About 283 MB on disk:
616 `.tscn`, 108 `.tres`, 64 `.glb`, 50 `.png`, 16 baked `.mesh`, 21 `.gd`, 3 `.gdshader`.

It is two things at once. A library of pre-made scenes (rocks, trees, grass, cliffs, mountains)
and a set of editor tools that scatter those scenes, or MultiMesh copies of them, across a mesh
you supply.

## Install and path assumption

Every script hardcodes paths of the form `res://PolyBlocks/NatureBlocks/...`. Copy the whole
`PolyBlocks` folder to the project root so it lands at `res://PolyBlocks`. If you put it anywhere
else, the tools will print `could not load ...` warnings and generate nothing. Some exported path
properties can be repointed, but the tree and mountain mesh lists are plain `var`, not `@export`,
so they cannot be fixed from the inspector.

There is no `project.godot`, no addon, no autoload, no plugin registration, and no input map
requirement. Nothing needs to be enabled. There is also no licence file and no readme in the
download, so the licence terms live wherever you bought it.

## Requirements

- Godot 4.5 or newer. Scenes use `format=4` and per-node `unique_id`, the tools use
  `@export_tool_button`, and the terrain materials set `stencil_flags` / `stencil_outline_thickness`.
- Forward+ (or Mobile). The water shader reads `hint_depth_texture` and `hint_screen_texture`,
  which the Compatibility renderer does not provide.
- GLB imports have `generate_lods` and `create_shadow_meshes` on, so the first import of the pack
  takes a while.

## Folder layout

```
PolyBlocks/
  NatureBlocks/
    assets/        546 ready-to-use .tscn, grouped environments / ground / terrain / trees / vegetation
    demo/          nb_demo.tscn plus scenes/ (example builds) and showcase/ (flat line-ups)
    source_files/  glb/ materials/ shaders/ textures/ fx/
    tools/         one folder per editor tool, each with a .tscn wrapper and src/ script
  misc/
    backdrop/            a GLB curved backdrop for product shots
    camera_controller/   misc_fps_camera.tscn, misc_movie_recorder.tscn
    reference/           misc_adventurer.tscn, a humanoid for scale checks
    template/            mat_template.tres, the StandardMaterial3D preset the pack is built on
```

## Placing assets by hand

Drag any scene from `assets/` into your scene. They are shallow: a GLB instance with
`surface_material_override/0` pointing at a shared `.tres`. Rocks, boulders and pebbles carry a
`StaticBody3D` + `ConvexPolygonShape3D`. Trees, grass, flowers and other foliage have no collision
at all, which is usually what you want for scatter.

Add one of the eight `assets/environments/nb_env_*.tscn` for lighting. Each is a
`WorldEnvironment` plus a key and fill `DirectionalLight3D`, with tonemapping, glow and volumetric
fog already set. The variants are default, alien, atmospheric, cartoon, cemetery, dune, night,
sunset.

## The tools

All tools are `@tool` scripts wrapped in a one-node scene under `NatureBlocks/tools/`. Instance
the `.tscn` into your scene, fill in the exported fields, and press the inspector button. Nothing
runs at `_ready` and nothing runs at game time. The output is real nodes owned by the edited
scene, so it is saved into your `.tscn` and needs no runtime cost, but it also makes the scene
file large.

### apply_natureblocks (the entry point)

`tools/apply_natureblocks/nb_apply_natureblocks.tscn`, class name `NatureBlocks`.

- `surface_mesh: MeshInstance3D`: the ground mesh everything works on.
- `ground_material`: enum over the ten terrain biomes, applied as a surface override.
- `surface_index`: which surface of the mesh to override.
- Buttons: `Apply Material`, `Clear Override`, `Instantiate Tools`.

`Instantiate Tools` creates three child group nodes (`ProceduralGeneration`, `ScatterVegetation`,
`ScatterTrees`), fills them with every generator and scatter tool scene, and pushes your
`surface_mesh` into each one. That is the fastest way to set up. `auto_instantiate_tools` makes
`Apply Material` do it too.

### Path3D generators

Each needs a `Path3D` assigned. They build `ArrayMesh` geometry with `SurfaceTool` and add it as
`MeshInstance3D` children, with `Generate` and `Clear` buttons.

| Tool | Path needs | Produces | Notable exports |
| --- | --- | --- | --- |
| `generator_cliff` | closed curve, 3+ points | `CliffWall`, `CliffPlain`, plus 5 MultiMesh cliff variants | `cliff_amount` (1..5000), `plain_height`, `scale_min/max`, `add_collision`, cliff and plain biome |
| `generator_mountain` | open curve, 2+ points | MultiMesh mountains along the curve | `mountain_amount`, `height_scale_min/max`, `taper_ends`, `taper_fraction`, biome |
| `generator_lake` | closed curve, 3+ points | `LakeWater`, `LakeBed`, `LakeBank` | `water_level`, `water_offset`, `bed_depth`, `bank_top_width`, `bank_height`, `outer_width`, `randomize_width` + `width_variance` + `width_noise_frequency`, `uv_tile_size` |
| `generator_river` | open curve, 2+ points | `RiverWater`, `RiverBed`, `RiverBank`, `splashes` | same width/bank set plus `water_width`, `length_subdivisions`, `splash_scene`, `splash_angle_threshold_deg` |
| `generator_road` | open curve, 2+ points | `Road`, `RoadSide` | `road_width`, `road_level`, `side_top_width`, `side_height`, `outer_width` |

Cliff and mountain scatter from baked `.mesh` files in their own `src/` folders. Lake, river and
road generate geometry from scratch and take their materials as `Material` exports with defaults
preloaded, so they are easy to swap. The river spawns `nbfx_water_splash.tscn` wherever the
curve's pitch exceeds `splash_angle_threshold_deg`, which is how the waterfall demo is built.

Only the cliff tool has `add_collision`. Lake, river and road geometry is visual only.

### MultiMesh scatter tools

`scatter_grass`, `scatter_flowers`, `scatter_ferns`, `scatter_reeds`, `scatter_boardleaf`,
`scatter_shrubs`. Each takes `surface_mesh`, reads the mesh's triangles, keeps the ones whose
normal dot `Vector3.UP` is at least `top_facing_threshold` (default 0.8), samples points by
triangle area, and adds a `MultiMeshInstance3D` under the target mesh with a `material_override`.

Shared exports: `use_random_seed` / `random_seed`, `top_facing_threshold`,
`rotation_variance_degrees`, `align_to_surface_normal`, `<thing>_amount` (up to 100000),
`<thing>_scale_min/max`, `<thing>_surface_offset`, and `@export_dir` paths to the mesh and the
material folder.

Mix controls are percentage sliders rather than a picker. Flowers have `blue_flowers`,
`red_flowers`, `white_flowers`, `yellow_flowers` and toggles for shape 1 and 2. Ferns have
`forest` / `jungle` / `olive`. Shrubs have small versus large plus twelve vegetation colours.
Grass picks a single `biome` enum and a `grass_type` of TYPE_1 or TYPE_2.

### Scene-instancing scatter tools

`scatter_ground` and the five `scatter_trees` scripts (`nb_scatter_trees`, `_birch`, `_pine`,
`_palm`, `_willow`) place whole `.tscn` instances instead of MultiMesh entries.

- `scatter_ground` has separate `Add Rocks`, `Add Boulders`, `Add Pebbles` buttons with their own
  amounts, plus poisson-disc spacing (`auto_spacing`, `min_spacing`, `max_sample_attempts`,
  `density`, `max_items`) and ten per-biome weight sliders.
- The tree scatters use `density` (instances per square unit of the target AABB), `max_trees`, and
  `cluster` (0 spreads evenly, 1 pulls everything into tight groves). They raycast straight down
  onto the mesh triangles, so overhangs are ignored. Biome weights are sliders; a tool only lists
  the biomes that family actually ships.
- Every placed node gets `metadata/flat_scatter_generated = true`, which is how `Clear` finds them.

These are heavy. One rock instance is a node with its own collision body, so a few thousand of
them bloat both the scene file and the node count. The MultiMesh tools are the cheap option.

## Shaders and materials

Three shaders in `source_files/shaders/`, each driven by ShaderMaterial `.tres` files in
`source_files/materials/`.

`nbshader_grass.gdshader`: `cull_disabled, shadows_disabled, depth_prepass_alpha`. Colour comes
from `albedoGradient`, a gradient texture sampled by the vertex's local height, so you recolour
grass by editing the `Gradient` subresource in the material, not a texture. Also
`alphaMask`, `windSpeed`, `windStrength` (a sine sway on X weighted by height squared),
`hue_noise` + `hueNoiseScale` + `hueStrength` for per-position hue variation, `ambientColor`,
`ambientStrength`. It writes a constant `NORMAL`, so grass reads flat.

`nbshader_leaves.gdshader`: `world_vertex_coords`, shadows disabled. Uniforms: `albedoColor`
(one flat source colour), `alphaTexture`, `shadowIntensity`, `windNoise`, `windSpeed`,
`windStrength`, `ambientColor`, `ambientStrength`. Lighting is faked with a hardcoded light
direction inside the fragment shader. Foliage will not respond to your scene lights or to a day
cycle, which keeps the look consistent but removes a lever.

`nbshader_water.gdshader`: screen-space refraction and depth-based foam. Uniforms:
`noise_texture`, `water_color`, `ripple_color`, `wave_strength`, `wave_speed`,
`water_transparency`, `water_roughness`, `normal_strength`, `water_depth_fade`, `foam_distance`,
`surface_noise_cutoff`, `foam_scale`, `distortion_intensity`. `nbmat_water.tres` generates its own
`NoiseTexture2D`, so no external texture is needed.

Terrain and ground materials are `StandardMaterial3D`, not shaders: a 2048x2048 albedo texture
with `uv1_triplanar` and `uv1_world_triplanar` on, `uv1_scale` 0.02, `roughness` 0, backlight on,
`disable_receive_shadows` true, and a stencil outline. Triplanar means terrain UVs do not matter,
which is why the generators can emit raw geometry and still look right.

To recolour: duplicate the `.tres`, change `albedo_color` on a terrain material, `albedoColor` on
a leaves material, or the gradient on a grass material, then point the tool's materials root path
or the scene's `surface_material_override/0` at your copy. `misc/template/mat_template.tres` is
the base preset, including a black inverted-hull `next_pass` for outlines.

Material families and counts: grass 20 (2 types x 10 biomes), terrain 10, ground 10, leaves1 12,
leaves_willow 12, flowers 9, leaves2 6, tree_trunks 6, ferns 3, lava 3, water 3, leaves3 3,
boardleaf 2, ivy 2, reeds 2, other 2.

## Inventory

Two separate biome vocabularies run through the naming.

- Terrain and ground (10): canyon, cave, desert, grey, ice, moss, river, sand, swamp, verdant.
- Vegetation and trees (12): anime, autumn, blue, forest, jungle, mars, olive, sakura, savannah,
  snow, spooky, tundra.

Filenames are `nb_<family><n>_<biome>.tscn`. 546 asset scenes:

| Group | Family | Pattern | Count |
| --- | --- | --- | --- |
| environments | env | `nb_env_{alien,atmospheric,cartoon,cemetery,default,dune,night,sunset}` | 8 |
| ground | rocks | `nb_rock1..6_<10 biomes>` | 60 |
| ground | boulders | `nb_boulder1..4_<10 biomes>` | 40 |
| ground | pebbles | `nb_pebble1..3_<10 biomes>` | 30 |
| ground | patches | `nb_patch1_type1..2_<10 biomes>` | 20 |
| terrain | setpieces | `nb_setpiece1..8_<10 biomes>` | 80 |
| terrain | cliffs | `nb_cliff1..5_<10 biomes>` | 50 |
| terrain | mountains | `nb_mountain1..4_<10 biomes>` | 40 |
| trees | generic | `nb_tree1..5_<12 biomes>` in per-biome folders | 60 |
| trees | birch | `nb_birch1..3_<12 biomes>` | 36 |
| trees | pine | `nb_pine1..2_<7 biomes>` + `nb_pine3_lowpoly` | 15 |
| trees | willow | `nb_willow1_<12 biomes>` | 12 |
| trees | palm | `nb_palm1..3_{forest,jungle,olive}` | 9 |
| trees | bamboo | `nb_bamboo1` | 1 |
| vegetation | grass | `nb_grass1.1, 1.2, 2.1, 2.2_<10 biomes>` | 40 |
| vegetation | shrubs | `nb_shrub1..2_<12 biomes>` | 24 |
| vegetation | flowers | `nb_flower1..2_{blue,red,white,yellow}` + `nb_flower_lilypods` | 9 |
| vegetation | ferns | `nb_fern1_{forest,jungle,olive}` | 3 |
| vegetation | vines | `nb_vine1..3` | 3 |
| vegetation | reeds, ivy, boardleaf | `nb_reed1..2`, `nb_ivy1..2`, `nb_boardleaf1..2` | 6 |

Only 64 GLB meshes sit behind all of that. A biome variant is the same mesh with a different
material, which is good for batching and for making your own variants.

## Demo and showcase

- `demo/nb_demo.tscn` is the tour scene. `nb_demo.gd` swaps environments on keys 1 to 8. It pulls
  in every showcase and example scene at once, so it is slow to open.
- `demo/scenes/examples/` holds the hand-built reference scenes: cliff, lake, river, road,
  mountains, waterfall, lavafall, and a full `nb_demo_scene.tscn`. Read these to see what the
  generators are meant to produce.
- `demo/scenes/ground/nb_demo_ground_<biome>.tscn` is the smallest useful template: a `BoxMesh`
  ground with a terrain material and scatter output on top. Copy one of these as a starting point.
- `demo/showcase/` is flat line-ups of every variant in a family, useful as a picker.
- `misc/template/mat_template.tres` is a material preset, not a scene template.
- `misc/camera_controller/misc_fps_camera.tscn` is a free-fly `Camera3D` that captures the mouse
  and forces fullscreen at `_ready`. `misc_movie_recorder.tscn` is a `@tool` node that tweens a
  camera between recorded start and end transforms for flythroughs.

## Gotchas

- Path dependency. Everything breaks unless the folder is at `res://PolyBlocks`.
- Generated output is committed into your scene file. `demo/scenes/examples/nb_demo_cliff.tscn` is
  10 MB, `nb_demo_scene.tscn` 5.7 MB, several showcase scenes around 1 MB. Text scenes that large
  are slow to open and produce unreadable diffs. If you scatter heavily, save the result into its
  own sub-scene, or clear the tool output before committing.
- Terrain and ground textures are 2048x2048 PNGs of 10 to 16 MB each, about 230 MB of the 283 MB.
  For a small project, consider keeping only the biomes you use.
- Scatter reads the mesh's own triangles and raycasts down, so it works on a `BoxMesh` or an
  imported terrain but not on a `HeightMapShape3D` or a `GridMap`.
- Foliage shaders disable shadows and ignore scene lights. You cannot light grass or leaves
  normally, and a day cycle will not touch them.
- The water shader needs Forward+ or Mobile. On Compatibility it will fail to compile.
- Trees and foliage have no collision. Only ground props ship a convex body, and only the cliff
  generator can emit collision.
- Tool buttons only exist in the editor. Nothing here generates terrain at runtime without you
  calling the generate functions yourself, and they call `Engine.is_editor_hint()` for ownership,
  which is harmless at runtime but leaves nodes unowned.
- `use_random_seed` overwrites `random_seed` with a fresh value each run, so the seed shown in the
  inspector after a generate is the one that produced the result. Turn the flag off to reproduce.
- No licence text ships with the package.

## Fitting it to this repo

Zenith and the other prototypes here are 2D-ish card games, so the useful angle is backdrop and
mood rather than a walkable world.

- Duel backdrop. Build one small `BoxMesh` ground per biome, run the scatter tools once, park a
  fixed `Camera3D`, and render it behind the card layer with a `SubViewport`. The grass and leaves
  wind sway gives motion without any gameplay cost, and swapping `nb_env_*` changes the whole mood
  in one node. Save each backdrop as its own scene to keep the file size out of the duel scene.
- Adventure map nodes. The `assets/terrain/setpieces` family is 8 pieces per biome, already sized
  as standalone props. One setpiece per map node, with the biome picked by region, gives a map
  screen a lot of variety from a small pick list.
- Still art. `misc/backdrop` plus `misc_fps_camera` and the movie recorder are set up for renders.
  Point a camera at a scattered scene, screenshot it, and use the image as a card or screen
  background. That avoids shipping 283 MB inside the game.
- Recolouring is the cheap lever. A Vigil or Pact palette is one duplicated leaves material with a
  different `albedoColor`, or one grass material with a different gradient, applied across every
  variant that uses it.
- If you do ship the 3D assets, budget the import. 64 GLBs with LODs and shadow meshes, plus 50
  large PNGs, makes the first editor open slow and the export bigger than the rest of a card game
  put together.
