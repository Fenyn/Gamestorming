# Art Pass — Kenney Base + Blender Gaps

First art pass on the espresso stand. Kenney CC0 models replace the room, counters, fridge and milk jug. Custom props for the starter stations and items are built in Godot (see Custom models). Upgrade stations are still grey-boxed and are listed below as specs.

## What changed

| Area | Before | Now |
|---|---|---|
| Floor inside the stand | `Platform` CSG box | Kenney `floorFull` (StaticBody3D collision unchanged) |
| Back wall | CSG box | Kenney `wall`, recoloured cream |
| Side walls | CSG boxes | Custom `side_wall_left/right.tscn` with the window sill above the back counter |
| Front counter | CSG box | 4× Kenney `kitchenBar`, 0.45 m deep (deepened toward the barista) |
| Back counter | Floating CSG slab | Custom stone top with tiled backsplash (`back_counter.tscn`) on 3 Kenney base cabinets |
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
- Kenney Fantasy Town Kit: street lamps along the curb and a bench. (The two market stalls were removed in the environment pass.)
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

## Site and street (environment pass)

Custom models under the `Site` and `AcrossStreet` nodes in `espresso_stand.tscn`. None has a collider, so customer navigation is unchanged.

| Scene | Placed at | Notes |
|---|---|---|
| `site_paving.tscn` | `Site/Paving` (shop origin) | Paver patio in front of the service window (customers queue and pick up here), paver seating area along the stand's left side, darker edging, and a 2.8 m sidewalk with control joints. Replaces the old 6.2 m concrete slab. |
| `roof_sign.tscn` | `Site/RoofSign` on the roof's front edge | Name board: coffee bean, GREEN BEAN, and a line of what is served. |
| `sign_order_here.tscn`, `sign_pick_up.tscn` | Hung from the header beam over the register and the hand-off | Lettered both sides, so they read from the street and from behind the counter. |
| `menu_board.tscn` | `Site/MenuBoard` on the right wall facing the queue | `scripts/world/menu_board.gd` writes the active menu and small-size prices onto it at prep and day start. |
| `a_frame_sign.tscn` | `Site/AFrameSign` at the patio's street corner | Chalkboard sidewalk sign facing customers coming from the right. |
| `side_wall_left.tscn` (door variant) | `LeftWall` | Staff door between the two counters, with a glass lite, levers, kick plate and a step outside (the stand floor is 10 cm up). |
| `stand_utilities.tscn` | `Site/Utilities` (shop origin) | Electric meter, panel and conduit on the back wall, a hose bib, a back gutter and two downspouts onto splash blocks. |
| `string_lights.tscn`, `light_pole.tscn` | Over the seating area | Three festoon strands from two wood poles to the stand's left corners, warm emissive bulbs. |
| `patio_umbrella.tscn`, `bike_rack_street.tscn`, `fire_hydrant.tscn`, `parking_meter.tscn` | `Site/...` | Umbrella over the back table, bike rack on the sidewalk past the seating, hydrant at the curb, a meter between each parked car. |
| `storefront_*.tscn` | `AcrossStreet/*`, fronts at z 16.85 facing the road | Two-storey shops (bakery, books, laundry, florist, hardware) from one parametric model: shop glass with a dim interior, door, sign band, striped awning, upper windows, cornice. Generic shop names only. |

## Custom models (built in Godot)

Blender can't be installed in the cloud session, so custom props are generated once from primitive meshes by scripts in `model_src/` and saved as normal Godot scenes in `scenes/props/`. Nothing is generated at runtime. Open the scene in the editor to move, resize or recolour any part: every piece is a MeshInstance3D with its mesh and material stored in the scene. Materials of the same colour are shared, so changing one recolours all parts that use it.

- `model_src/model_kit.gd`: helpers (box, cylinder/cone, sphere, torus, group) and Kenney-matched colours.
- `model_src/<model>.gd`: one script per model with a static `build()`.
- `model_src/build_models.gd`: writes any missing scenes. It never overwrites an existing scene unless you pass `-- --force <name>` (or `all`), so editor changes are safe. Run from the green-bean folder: `godot --headless --path . --script res://model_src/build_models.gd`.

| Scene | Used by | Notes |
|---|---|---|
| `scenes/props/hand_grinder.tscn` | `grinder.tscn` (instance named `Model`) | Modern hand burr grinder (steel, 5 cm × 17 cm, 13 cm crank, grip band, grind ring, screw-on catch cup) clamped in a wooden holder, with the device pad beside it. Grounds collect in the catch cup; when the grind finishes the station unscrews the cup, tips it into the device at `DumpPoint` and puts it back. `Crank` turns about the root's `crank_axis` (up), once per mouse circle. Markers: `DevicePad`, `DumpPoint`, `GaugeAnchor`, `CameraView`. The electric grinder upgrade can drop grounds straight into the device. |
| `scenes/props/steam_station.tscn` | `steam.tscn` (instance named `Model`) | Compact standalone milk steamer modelled on real compact standalone steamers (about 10 cm wide, 37 cm deep, 24 cm tall): narrow tower at the back, a head that overhangs the pitcher with a control panel on top and a steam lever on the side, a wand angled down into the pitcher, an IR temperature sensor under the head, a small drip tray, and a mat for the spare pitcher. Depth is squeezed to fit the station footprint. The collision box in `steam.tscn` covers the tower, head and tray (0.12 x 0.245 x 0.195 m). The spare-pitcher mat has its own thin `MatArea` body (`scripts/stations/station_proxy.gd`), so a held pitcher can be clicked onto the mat. If the pad is taken, clicking the steamer parks the pitcher on the mat. Scalded milk is dumped onto the mat only when it is free; otherwise the empty pitcher stays on the pad. The mini-game gauges sit above the head, with the depth gauge on the right, away from the window. Markers: `PitcherPad`, `PitcherRest`, `SteamVent`, `CameraView`. The wand is one node, `Wand`. |
| `scenes/props/milk_pitcher.tscn` | `Pitcher` item (`scripts/items/pitcher.gd` instances it as `Model`) | 12 oz stainless steaming pitcher at real size (about 7.5 cm across, 9.5 cm tall): belly that narrows toward the top, pointed spout toward -Z, C handle toward +Z, built from a lathed body (`ModelKit.lathe`) and a swept handle (`ModelKit.sweep`). Its `Collision` node is moved onto the Pitcher body at runtime, so the collider is edited in the prop scene with the model. `MilkFloor` marker and the root's `inner_profile` metadata place the milk, which narrows with the wall as it rises. The body and handle are ArrayMeshes, so reshape them by editing `model_src/milk_pitcher.gd` and rebuilding with `--force milk_pitcher`; the editor can still move, recolour or swap parts. |
| `scenes/props/hot_water_dispenser.tscn` | `hot_water.tscn` (instance named `Model`) | Slim commercial hot water tower at real size, modelled on slim commercial hot water towers (about 19 cm wide, 43 cm deep, 56 cm tall here): stainless tower, a head overhanging about 21 cm of cup clearance, a black control panel with an LED readout and buttons, a faucet with a red lever, and a drip tray. No branding. Origin is the base, so the shop places it on the counter top (y 0.89), back against the wall. During a kettle fill or americano pour the station stands the cup or kettle on `FillPoint` under the spout and hands it back after. The `Faucet/Lever` node swings down while water runs. The kettle can be clicked back onto `KettleRest`. |
| `scenes/props/gooseneck_kettle.tscn` | `Kettle` item (`scripts/items/kettle.gd` instances it as `Model`) | Gooseneck pour-over kettle at real size, modelled on a typical 1 litre stovetop gooseneck kettle (14.4 cm across, 13 cm tall, about 30 cm spout to handle): domed steel body, small lid with a black knob, S-curved gooseneck leaving low on the body, black handle opposite. Spout points -X, handle +X. `Collision` (body cylinder) is moved onto the item at runtime. `SpoutTip` drives pours: `StationUtils.start_kettle_pour` places the kettle so the tip sits above the target and sways the tilt about the tip; callers pick which side the body sits on (pour-over uses the left, away from the wall). `Lid` lifts off and hangs on the `LidClip` on the front of the body (`LidParked` marker) while the dispenser fills the kettle, then goes back. At the dispenser the kettle waits with its spout toward the wall. |
| `scenes/props/shot_press.tscn` | `ShotPress` item (`scripts/items/shot_press.gd` instances it as `Model`) | Shot press at real size, like a typical single-cup plunger press (chamber 12.1 cm tall, plunger 13.4 cm with an 8.3 cm top): smoky translucent chamber, round flange with two grip tabs at the bottom, black filter cap with lugs, plain graduation ticks on the front, and a plunger (hidden until pressing). `RimRest` is the flange underside, which sits on the cup rim. `LiquidFloor` and the `liquid_max_height` metadata place the coffee; `PlungerTop`/`PlungerBottom` set the press travel, and the coffee level drops as the plunger reaches it. |
| `scenes/props/shot_press_station.tscn` | `shot_press.tscn` (instance named `Model`) | Brew spot rather than a machine: a silicone brew mat with drip rings where the cup stands, a wooden stand with a cradle for the shot press, and a dish of paper filters. The shot press sits on the cup by its flange, so its height follows the cup size. A loaded shot press set down with no cup waits in the stand and goes onto the cup when one is placed. The press gauges sit at `GaugeAnchor`, right of the cup above the stand. |
| `scenes/props/cone_dripper.tscn` | `Dripper` item (`scripts/items/dripper.gd` instances it as `Model`) | Ceramic cone dripper at the size of a typical "02" cone (10.5 cm base plate, 11.7 cm rim, 10 cm tall): 60 degree cone ending in one large hole you can see through the base, a collar down to a flat base plate, and a flat loop handle from the upper cone to the plate. A paper filter lines it and stands 1.4 cm above the rim, with an uneven top edge and a crimped seam. The grounds bed (from `GroundsFloor` and the root metadata) darkens from dry to wet, and a layer of standing water rises while pouring, sinks during the bloom wait and drains during the draw-down. `base_y` is the base plate's underside, which rests on the stand's ring or the saucer. |
| `scenes/props/pour_over_stand.tscn` | `pour_over.tscn` (instance named `Model`) | Wooden brew stand: base, post and a steel ring the dripper's base plate rests on, a brew scale with a lit readout under the cup, a saucer for the spare dripper, and a wooden slot holding folded paper filters. The ring is high enough for the extra large cup, so the dripper always sits in the same place. The saturation grid lies on the grounds, and the pour camera looks down into the dripper from the front. |
| `scenes/props/paper_cup_<size>.tscn` | `Cup` item (`scripts/items/cup.gd` picks the scene by size) | Hot paper cups at common sizes (top / bottom diameter x height): small 8 oz 80/56 x 92 mm, medium 12 oz 90/60 x 112, large 16 oz 90/60 x 136, extra large 20 oz 90/60 x 155. Rolled rim, kraft sleeve, and a domed sip lid (`Lid`, hidden until lidded). The drink widens with the wall using the `inner_profile` metadata. The order sticker sits at `StickerSpot` and has captioned SIZE and DRINK rows (`scripts/items/order_label.gd`, also used for printed tickets). |
| `scenes/props/cup_dispenser.tscn` | `cup_stack.tscn` | Four clear gravity tubes (S, M, L, XL from the barista's left) on a steel bracket under the front counter lip. Cups stack mouth-down and the bottom cup shows below a gripper ring. A grabbed cup appears at `Dispense_<size>`. |
| `scenes/props/lid_caddy.tscn` | `lid_dispenser.tscn` | Two stacks of sip lids in a black caddy, origin at the base, on the front counter. |
| `scenes/props/pos_terminal.tscn` | `register.tscn` | Tablet POS on a post, with a bezel sized to the SubViewport screen quad (tilted 15°) and a ticket printer beside it. |
| `scenes/props/cash_drawer.tscn` | `cash_drawer.tscn` | Cash drawer (34 x 9 x 30 cm) built into the front counter under the top, beside the POS, with a trim frame on the cabinet face. `Drawer` slides 24 cm out to `DrawerOpen`. Back row: $20 $10 $5 $1 under hinged spring clips (`Clip_<key>`). Front row: 25¢ 10¢ 5¢ 1¢ cups. `Slot_<key>` markers carry each compartment's hit size. |
| `scenes/props/cash_pieces.tscn` | `cash_drawer.gd` (templates it duplicates) | One generic note per value (pale paper, printed frame, colour band, numerals, no real currency art) and one coin per value at real diameter and thickness. |
| `scenes/props/change_mat.tscn` | `cash_drawer.tscn` (node `ChangeMat`, on the counter top behind the drawer) | Rubber change mat. The customer's bill lands on `TenderSpot`; counted change fans out from `BillSpot` and stacks on `Coin_<key>`. |
| `scenes/props/pickup_shelf.tscn` | `hand_off.tscn` | Wooden pickup riser (36 x 13 cm, 5.3 cm tall) with a tented "PICK UP" chalkboard readable from both sides. Origin at the base. The finished drink stands on `DrinkSpot`. |
| `scenes/props/bar_mat.tscn` | `counter_pad.tscn` | Black rubber bar mat (38 x 38 cm) with a rim and a nub grid. Items stand on the `Slot0`-`Slot3` markers. |
| `scenes/props/back_counter.tscn` | `BackCounter` in `espresso_stand.tscn` (collider in the shop scene) | Wall-to-wall stone top (3.40 x 0.78 m, 4 cm) with a rounded front edge 2.5 cm past the cabinets, a dark apron that hides the cabinets' own tops, and three rows of running-bond tiles on the back wall. Back-row stations must stay in front of the tiles (z > -1.188). |
| `scenes/props/stand_roof.tscn` | `Roof` in `espresso_stand.tscn` (collider in the shop scene) | Flat roof: membrane deck, green fascia with a drip edge, wood plank soffits under the overhangs (1 m at the front), cream ceiling inside, and a green header beam over the service window. Origin at the wall tops so x and z match the shop. |
| `scenes/props/stand_frame.tscn` | `Frame` in `espresso_stand.tscn` | Green corner boards where the back wall meets the side walls, green posts at the side walls' front ends carrying the header beam, and wood knee braces under the front overhang. Origin at the ground, shop x and z. |
| `scenes/props/side_wall_left.tscn`, `side_wall_right.tscn` | `LeftWall`, `RightWall` in `espresso_stand.tscn` | 0.1 m walls, cream inside (face at x +-1.70) and dark grey-green outside, running from the back wall's outer face to the service window. One window each, sill casing at 0.96 m so the back counter runs underneath it (the stock Kenney window came down to 0.67 m and the counter cut through its trim). Wood casing on both faces, jambs, sash, sill and a glass pane. |
| `scenes/props/syrup_pump_station.tscn` | `syrup.tscn` | 750 ml round glass syrup bottle with a dosing pump; the spout reaches 9.5 cm forward over a steel drip tray where the cup stands (`CupSpot`). The station tints `Syrup` and names `NameLabel` per flavour, and the pump mini-game pushes `PumpHead` down 2.5 cm per stroke. |
| `scenes/props/squeeze_bottle.tscn` | `SauceBottle` item (`scripts/items/sauce_bottle.gd` instances it as `Model`) | 12 oz squeeze bottle, 20 cm tall. The sauce level shows through the body from `FillFloor`, and the cap takes the sauce colour. While a prep station fills it, `preview_level()` shows the rising level without changing the contents. |
| `scenes/props/drizzle_station.tscn` | `sauce.tscn` (mocha and caramel) | Rubber mat with a printed cup ring (`CupSpot`), a wire holder that keeps the bottle upright (`BottleSpot`) and a tent card named per sauce. The drizzle grid is centred over the cup. |
| `scenes/props/bottle_rack.tscn` | `bottle_rack.tscn` | Wire rack, three rings (`Slot0`-`Slot2`). |
| `scenes/props/sauce_prep_station.tscn` | `sauce_prep.tscn` (caramel) | Prep board with a 1.9 L sauce pouch and a spot for the empty bottle. While filling, the pouch tips to `PouchPour` over the bottle and the bottle level rises. |
| `scenes/props/mocha_prep_station.tscn` | `mocha_prep.tscn` | Prep board with a 2 L clear jug (the batch level rises inside it), a cocoa bag (`PowderBag`, hidden while its powder is in the jug; the cut line starts at `BagCut`), a whisk, and a spot for the empty bottle. |

Station scripts read markers with `StationUtils.model_marker(station, "Name", fallback)` and stand items on them with `StationUtils.item_half_height(item)`.

Any of these can be replaced by a Blender model later: keep the instance name `Model`, the origin at the centre of the collision box, +Z as the front, and the marker nodes listed above.

## Still grey-boxed

Every station and item now uses a custom model. Mini-game progress bars, drizzle grids and cut lines are still drawn with CSG; they are on-screen aids, not props.

### Other placeholders

- Customers walk with the run animation slowed to 55%, because the pack has no walk animation.
- No textures anywhere. All Kenney models are flat-coloured.

## Checking

Models and layout are checked with renders from `_probe/` scenes (not committed) and by the station test scenes. Nothing here has been hand-played since the custom models went in. Things to look at in the editor:

- The cash drawer's housing sits inside the front counter cabinet; check no camera angle shows the two overlapping.
- Station status text only shows on the station you look at, or for 3 s after it changes. Check that alerts you need from across the shop (shot ready, milk scalding) are still noticeable; sound will carry most of that once there are audio files.
