# Asset Guide -- Spaceship & Cyberpunk Sprite Packs

How to use the Spaceship, Cyberpunk Interior, and Cyberpunk Exterior sprite packs in the Godot editor. All assets are LimeZu RPG Maker format, 48x48 tile grid.

## Generated Files

Everything below is built by `tools/asset_prep.gd`:

    godot --headless --path . --script tools/asset_prep.gd

### TileSet Resources

| Resource | Sources | Contents |
|---|---|---|
| `resources/spaceship_tileset.tres` | 8 atlas sources | Space station interiors -- floors, walls, panels, grating |
| `resources/cyberpunk_interior_tileset.tres` | 9 atlas sources | Cyberpunk apartment/building interiors |
| `resources/cyberpunk_exterior_tileset.tres` | 11 atlas sources | Cyberpunk city streets, rooftops, wasteland |

### Prop Scenes

| Directory | Count | Key props |
|---|---|---|
| `scenes/props/spaceship/` | 137 | Reactors, consoles, gates, medbay, elevators, doors, chests, servers, lights, decorations |
| `scenes/props/cyberpunk_interior/` | 90 | Doors, lights, candles, TVs, kitchen devices, robots, gates, decorations |
| `scenes/props/cyberpunk_exterior/` | 87 | Cars, trains, streetlights, signs, gates, statues, trees, ventilation, drones |

---

## Setting Up the Editor

### Grid Snap

Set the editor grid to 48px so tiles and props snap cleanly:

1. In the 2D viewport toolbar, click the three-dot snapping menu
2. **Configure Snap** > set Grid Step to `48 x 48`
3. Enable **Use Grid Snap** (or press `Ctrl+Shift+G`)

### Texture Filtering

These are pixel art assets. If sprites look blurry, check **Project > Project Settings > Rendering > Textures > Default Texture Filter** is set to `Nearest`.

---

## Building a Scene with Tiles

### 1. Create the TileMap structure

Start with a Node2D scene root, then add layers:

| Layer Node | Purpose | Z-Index |
|---|---|---|
| `FloorLayer` (TileMapLayer) | Floor tiles | 0 |
| `WallLayer` (TileMapLayer) | Walls, structural elements | 1 |
| `DetailLayer` (TileMapLayer) | Surface details, trim, overlays | 2 |

Assign the same tileset to all layers (e.g. `spaceship_tileset.tres`).

### 2. Pick tiles from the right source

When you select a TileMapLayer, the TileMap panel opens at the bottom. The left sidebar shows atlas sources by ID. Here's what's in each:

**Spaceship Tileset:**

| Source | Sheet | Use for |
|---|---|---|
| 0 | A1 (animated autotiles) | Animated floors, machinery -- use individual cells manually |
| 1 | A2 (ground autotiles) | Ground/terrain patterns -- use individual cells manually |
| 2 | A4 (wall autotiles) | Wall pattern cells -- use individual cells manually |
| 3 | **A5 (regular tiles)** | Simple 8x16 tile grid -- floors, panels, grating |
| 4 | **B (regular tiles)** | 16x16 grid -- furniture, equipment, large objects |
| 5 | **C (regular tiles)** | 16x16 grid -- more furniture, shelving, tech |
| 6 | **D (regular tiles)** | 16x16 grid -- decorative elements, small objects |
| 7 | **E (regular tiles)** | 16x16 grid -- additional decor, signage |

**Start with sources 3-7** (A5, B, C, D, E). These are straightforward tile grids where every cell is a usable tile. Sources 0-2 are RPG Maker autotile layouts -- individual cells work but won't auto-connect.

The Cyberpunk packs follow the same pattern. Interior has B and Bv2 variants (sources 5-6). Exterior has the full A1-E range including A3 wall tiles.

### 3. Paint

- **Single tile**: Click a tile in the atlas panel, click on the viewport
- **Line**: Hold `Shift` and drag
- **Rectangle fill**: Hold `Ctrl+Shift` and drag
- **Erase**: Right-click paints empty
- **Pick tile from viewport**: Hold `Ctrl` and click an existing tile to select it

### 4. Add wall collision

Walls need physics collision. Do this in the **TileSet editor** (not the TileMap editor):

1. Select the TileMapLayer, then in the Inspector click the TileSet resource to open the TileSet editor
2. Select a wall tile in the atlas
3. Switch to the **Physics** tab (in the tile properties panel on the right)
4. Click **Add Polygon** and draw a collision shape (or use the full-tile rectangle tool)
5. The physics layer is already created -- collision layer 1

Every instance of that tile will now collide. Paint wall collision once per tile, not per placement.

---

## Placing Props

### 1. Drag and drop

In the FileSystem dock, navigate to one of the prop directories:

    scenes/props/spaceship/
    scenes/props/cyberpunk_interior/
    scenes/props/cyberpunk_exterior/

Drag a `.tscn` file into the 2D viewport. It instances as a Sprite2D at the drop location.

### 2. Prop naming convention

**Single-character props** (one scene per sheet) -- large, unique objects:

| Scene | Size (tiles) | What it shows |
|---|---|---|
| `spaceship_reactor.tscn` | 3x4 | Reactor with blue indicators |
| `spaceship_medbay.tscn` | 3x4 | Medical bay equipment |
| `spaceship_elevator_big.tscn` | 3x4 | Large elevator |
| `spaceship_navigator.tscn` | 3x3 | Navigation console |
| `consoles_main.tscn` | 3x2 | Main console bank (blue) |
| `cyberpunk_streetlight.tscn` | 3x5 | Tall street lamp |
| `cyberpunk_train.tscn` | 9x3 | Horizontal train car |
| `big_trees_cyberpunk.tscn` | 5x6 | Large cyberpunk tree |
| `car1.tscn` | 3x3 | Standard car (white) |

**Multi-character props** (8 scenes per sheet, suffixed `_0` through `_7`) -- smaller objects with color/type variants:

| Scene pattern | Size (tiles) | Variants across 0-7 |
|---|---|---|
| `spaceship_computer_N.tscn` | 1x2 | 8 computer colors (blue, cyan, gold, pink, teal, etc.) |
| `spaceship_door_N.tscn` | 1x2 | 8 door styles |
| `spaceship_switches_N.tscn` | 1x2 | 8 switch panel types |
| `spaceship_decoration_N.tscn` | 1x2 | 8 small decorative objects |
| `lights_remaster_N.tscn` | 1x2 | 8 ceiling light variants |
| `obj_door1_remaster_N.tscn` | 1x2 | 8 interior door styles |

Slots 0-3 are the top row of the sprite sheet, 4-7 the bottom row. Browse a few to find the variant you want.

### 3. Swap variants and animation frames

Each prop shows one frame from a larger sprite sheet. To access other frames:

1. Select the prop Sprite2D in the scene
2. In the Inspector, find **Region > Rect**
3. The rect is `(x, y, width, height)` in pixels

**To change variant** (different row): add `height` to the Y value. For a 3x4-tile prop (144x192), the four row offsets are Y = `0`, `192`, `384`, `576`.

**To change animation frame** (different column): the three column offsets are X = `0`, `width`, `width * 2`. The default shows the center frame (column 1).

### 4. Add collision to props

Props are bare Sprite2D nodes. To make them solid:

1. Select the prop in the scene tree
2. **Change its type** to `StaticBody2D` (right-click > Change Type), or reparent the Sprite2D under a new StaticBody2D
3. Add a `CollisionShape2D` child with a `RectangleShape2D` sized to match the prop

For interactive props (chests, doors), use `Area2D` instead of `StaticBody2D` and connect its `body_entered` signal.

---

## Prop Catalog

### Spaceship -- Single Props

| Scene | Description |
|---|---|
| `consoles_diagonal.tscn` | Angled console bank |
| `consoles_main.tscn` | Main console (blue screens) |
| `consoles_main2.tscn` | Main console (red screens) |
| `consoles_main3.tscn` | Main console (cyan screens) |
| `light_1.tscn` | Ceiling light type 1 |
| `light_2.tscn` | Ceiling light type 2 |
| `light_sidewall.tscn` | Wall-mounted light |
| `spaceship_elevator_big.tscn` | Large cargo elevator |
| `spaceship_gate1.tscn` | Airlock gate type 1 |
| `spaceship_gate2.tscn` | Airlock gate type 2 |
| `spaceship_glowing_light.tscn` | Glowing accent light |
| `spaceship_medbay.tscn` | Medical bay station |
| `spaceship_navigator.tscn` | Ship navigation display |
| `spaceship_reactor.tscn` | Reactor (blue, normal) |
| `spaceship_reactor2.tscn` | Reactor variant 2 |
| `spaceship_reactor_critical.tscn` | Reactor (red, critical state) |
| `spaceship_reactor_offline.tscn` | Reactor (dark, offline) |

### Spaceship -- Multi-Variant Props (8 each)

`consoles_N`, `spaceship_chest_N`, `spaceship_chest2_N`, `spaceship_chest3_N`, `spaceship_computer_N`, `spaceship_cpu_server_N`, `spaceship_decoration_N`, `spaceship_decoration2_N`, `spaceship_decoration_signs_N`, `spaceship_decoration_static_N`, `spaceship_door_N`, `spaceship_door2_N`, `spaceship_door_diagonal_N`, `spaceship_ladder_N`, `spaceship_switches_N`

### Cyberpunk Interior -- Single Props

| Scene | Description |
|---|---|
| `gate1_remaster.tscn` | Interior security gate |
| `lights_glowing.tscn` | Neon glow light panel |

### Cyberpunk Interior -- Multi-Variant Props (8 each)

`candles_remaster_N`, `cleanrobot_remaster_N`, `cyberpunk_decoration_N`, `cyberpunk_toilet_door_N`, `decoration_cp_static_N`, `kitchen_devices_remaster_N`, `lights_1_2_N`, `lights_remaster_N`, `obj_door1_remaster_N`, `obj_door1_2_remaster_N`, `tv_screens_remaster_N`

### Cyberpunk Exterior -- Single Props

| Scene | Description |
|---|---|
| `big_decoration_cyberpunk.tscn` | Large decorative structure |
| `big_misc.tscn` | Large miscellaneous object |
| `big_trees_cyberpunk.tscn` | Tall neon-lit tree |
| `big_ventilation.tscn` | Ventilation shaft unit |
| `car1.tscn` | Car (white) |
| `car1_green.tscn` | Car (green) |
| `car1_grey.tscn` | Car (grey) |
| `car1_red.tscn` | Car (red) |
| `car1_police_stand_blue.tscn` | Police car, parked, lights on |
| `car1_police_stand_off.tscn` | Police car, parked, lights off |
| `car1_police_drive_blue.tscn` | Police car, driving, lights on |
| `car1_police_drive_off.tscn` | Police car, driving, lights off |
| `cyberlove.tscn` | Decorative love sign/structure |
| `cyberpunk_statues.tscn` | Cyberpunk statue |
| `cyberpunk_streelight_wall.tscn` | Wall-mounted street light |
| `cyberpunk_streetlight.tscn` | Tall street lamp |
| `cyberpunk_train.tscn` | Horizontal train car |
| `cyberpunk_train_2.tscn` | Vertical train car |
| `gate2_remaster.tscn` | Exterior gate type 2 |
| `gate3_remaster.tscn` | Exterior gate type 3 |
| `gate4_remaster.tscn` | Exterior gate type 4 |
| `gate5.tscn` | Exterior gate type 5 |
| `lights_glowing.tscn` | Exterior glow light panel |
| `manhole_cover.tscn` | Manhole cover |
| `sign1_remaster.tscn` | Street sign type 1 |
| `signs2_remaster.tscn` | Neon sign type 2 |
| `signs2_remaster_shadow.tscn` | Neon sign type 2 (with shadow) |
| `signs3_remaster.tscn` | Neon sign type 3 |
| `signs4.tscn` | Sign type 4 |
| `traffic_signal_module.tscn` | Traffic signal module |
| `traffic_signal_remaster.tscn` | Traffic signal pole |

### Cyberpunk Exterior -- Multi-Variant Props (8 each)

`cyberpunk_chest_N`, `cyberpunk_smoke_N`, `misc_remaster_N`, `obj_door2_remaster_N`, `obj_door3_N`, `policedrone_N`, `signs2_N`

---

## Limitations

- **No auto-tiling**: The A1-A4 sheets are registered as simple atlas grids. RPG Maker's autotile connections are not mapped to Godot's terrain system. Use B/C/D/E/A5 sheets for painting; use A-series cells manually when needed.
- **No animation**: Props show a single static frame. For animated props (blinking lights, opening doors, spinning reactors), replace the Sprite2D with an AnimatedSprite2D and build a SpriteFrames resource from the sheet's frame columns.
- **No collision on tiles or props by default**: Add physics polygons to wall tiles in the TileSet editor. Add CollisionShape2D to props that need collision.
- **Multi-variant props may have empty slots**: Some sprite sheets don't use all 8 character positions. Unused `_N.tscn` scenes will show a blank or partial sprite -- just delete them.