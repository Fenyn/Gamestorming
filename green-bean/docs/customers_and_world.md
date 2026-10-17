# Customers, Navigation and Ambient Life

## Customer generation

Every customer gets a `CustomerProfile` (`scripts/customers/customer_profile.gd`), generated when they spawn.

| Archetype | Chance | Walk speed | Patience | Other |
|---|---|---|---|---|
| Regular | 30% | 1.6–1.9 m/s | ×1.3 | Often a beanie or glasses |
| Commuter | 30% | 2.2–2.6 m/s | ×0.7 | Headphones, phone out while waiting |
| Student | 25% | 1.8–2.2 m/s | ×1.0 | Usually a backpack, sometimes a cap |
| Picky | 15% | 1.7–2.0 m/s | ×1.0 | ×2.5 chance of syrup or sauce |

Patience multipliers and the Picky modifier chance change gameplay. They follow the Phase 2 archetype plan in CLAUDE.md. Tune them in `CustomerProfile.generate()`.

Each profile also has:
- A first name. It shows in the order bubble ("Maya: Medium Latte"), on the printed ticket and on the cup sticker.
- One of 10 skins and a height between 0.92× and 1.06×.
- Accessories: beanie, cap, glasses, headphones, backpack. They are built from CSG in `character_visual.gd` and attached to the Head and Chest bones.
- Barks: a greeting on arrival, small talk while waiting, a complaint when patience drops below 25%, and a reaction to the review. Lines are the arrays at the top of `customer_profile.gd`.

Reactions:
- 4.5 stars or more: a happy jump (Kenney `jump.fbx`), then they leave.
- Every served customer leaves carrying a takeaway cup.
- Customers who give up leave with an angry bark.

## Character visuals

`CharacterVisual` (`scripts/customers/character_visual.gd`) builds the Kenney character, skin, animations and accessories. Customers and pedestrians both use it.

- Animations come from `idle.fbx`, `run.fbx` and `jump.fbx`. They are copied into one shared `AnimationLibrary` the first time a character is made.
- Walking is the run animation played at a speed matched to the walk speed (`WALK_ANIM_SPEED_PER_MPS`).
- `hold_in_hand(node)` puts a phone or cup in the right hand.

## Collision and navigation

- Street props, seating, planters, stalls, lamps and parked cars have collision under the `Colliders` StaticBody3D in `espresso_stand.tscn`. Shapes are simple boxes and cylinders sized to each prop.
- `NavRegion` bakes a navmesh at startup from every StaticBody3D in the `nav_geometry` group: `Colliders` and the stand's walls, platform and front counter. It takes a few milliseconds.
- The navmesh uses 0.1 m height cells. The shop script sets the navigation map to the same cell size and height before baking.
- Customers use a NavigationAgent3D with avoidance, so they route around props and each other. If no navmesh is ready, they walk in a straight line as before.
- If a walking customer makes no progress for 4 s, they are placed on their target spot, so one stuck customer can't stall the day.
- Pedestrians and cars do not use navigation. They follow fixed lanes that are kept clear of props.

## Register line and pickup spots

`customer_spawner.gd` manages where customers stand.

- **Register line:** five Marker3D spots under `RegisterQueue` in `espresso_stand.tscn`, 0.85 m apart and trailing back toward the street. Spot0 is the register. You can move the markers in the editor and add more.
- New customers join the back of the line. Only the front customer orders. When they pay, or someone in line gives up, everyone behind moves up a spot.
- People in line face the person ahead, make small talk and lose order patience while they wait. That matches the order-patience rule in CLAUDE.md.
- **Pickup:** four Marker3D spots under `PickupSpots`, each held by one customer until they get their drink. If more people are waiting than there are spots, the extras stand loosely behind the pickup point.
- **Matching:** a handed-off drink goes to the customer who ordered it, matched by order. If that fails it goes to anyone waiting for the same drink, then to anyone waiting.
- Two customers on screen at once never share a first name.
- `MAX_CUSTOMERS` is still 1 for testing. For real days, raise it in `customer_spawner.gd` (up to the number of line spots) and lower the 999 s spawn intervals. Tests can set `max_customers` and `spawn_interval_*` on the spawner instance.

Tested headless with 4 customers at once: 7 served, 1 forced to give up from line spot 2, and the line moved up behind them. Standing customers kept at least 0.86 m apart.

## Ambient life

`AmbientLife` (`scripts/world/ambient_life.gd`) is added by the shop script.

- **Pedestrians:** they walk the far sidewalk both ways (z 14.6 and 16.4, either side of the planters), and sometimes the near sidewalk (z 4.4, between the seating and the customer entry point). Up to 8 at a time, a new one every 2.5–6 s. Some carry a takeaway cup or look at a phone. Now and then one stops in front of the stand for a moment.
- **Traffic:** one car lane each way, a car every 4–11 s per lane at 6–10 m/s, with a slight suspension bob. The parked cars are all on the near side, so the lanes stay clear.

None of this has collision or takes part in orders.
