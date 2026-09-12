# Goblin outfit layers

Three sets drawn in Aseprite on the approved 56 x 64 goblin base. The original anatomy, skin colors, pose, and base file remain unchanged. Clothing uses flat color planes and restrained contour highlights.

The [lineup](outfit-lineup-5x.png) shows the bare base, Warrior, Commando, and War Chanter at identical pixel scale.

| Set | Outfit direction | Optional weapon | Editable master |
| --- | --- | --- | --- |
| Warrior | Leather jerkin, shoulder pad, belt, wrist bracer | Dogslicer | [Warrior](warrior/goblin-warrior.aseprite) |
| Commando | Leather jerkin, steel shoulder guard, red sash, shin wrap | Horsechopper | [Commando](commando/goblin-commando.aseprite) |
| War Chanter | Leather jerkin, blue mantle and sash, bone pendant | Dogslicer | [War Chanter](war-chanter/goblin-war-chanter.aseprite) |

All three local Monster Core stat blocks specify leather armor and a shortbow. The Warrior and War Chanter specify a dogslicer; the Commando specifies a horsechopper. Those armor and primary weapon choices come from the data. Colors, mantle, pendant, and reinforcement details are visual role cues. A shortbow overlay is not included in these melee outfit sets.

Each folder contains:

- `goblin-<role>.aseprite`: original base layers inside a locked base group, with seven separate outfit layers above them.
- `goblin-<role>.png`: equipped composite.
- `goblin-<role>-unarmed.png`: clothing composite without a weapon.
- `clothing-overlay.png`: transparent clothing only; place directly over the approved base at (0, 0).
- `outfit-overlay.png`: complete outfit, weapon, and hand restoration; place directly over the approved base at (0, 0).
- `01-layer.png` through `07-layer.png`: separate transparent layers in their drawing order.

Layer order is jerkin, skirt/sash, shoulder armor/mantle, belt/straps, bracer/wraps, weapon, then hand restoration. The last layer restores a small region of the original hand over the weapon handle. Recolor it with the base skin when making palette variants. Clothing-only overlays contain no restored skin pixels.

All overlays retain the full 56 x 64 canvas. Do not crop or reposition them. The original loincloth remains beneath the outfit skirt. The armor clips to the torso to preserve the exposed arm's shape.

Rebuild with Aseprite `--batch --script tools/build_goblin_outfits.lua` from Delve, or supply `--script-param root=<absolute-delve-path>`. The [script](../../tools/build_goblin_outfits.lua) overwrites this set's generated files; preserve manual edits before rebuilding.

Validation: hiding each outfit group reproduces the approved base pixel for pixel, and reopened masters match the equipped PNGs. These are single-pose outfit assets, not animated or registered in the combat sprite map.
