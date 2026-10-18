# Outpost camp assets

The outpost is the village in `scenes/run/village/`. This folder keeps the residents' seated art and two pack sheets the village still draws.

The character layer PNGs are unchanged Mana Seed page 4 paper-doll sources by Seliel the Shaper. Recipes match the existing hero folders: veteran (Aldric), rogue (Elara and current Raven fallback), cleric (Tharr), wizard (Fenwick), recruit (current Thistle fallback). Each `appearance.tres` names the original body, outfit, and hair/hat textures. `CampAppearance` composites and caches them in memory. The seated pose is page 4, column 5, row 4. The rise into a stand uses movement-page steps followed by the current hero's standing frame; all frame coordinates are zero-based. No source combat sheet is overwritten.

The original layers come from `F:/UnityNVME/Art/Sprites/Mana Seed/`, using the character base and the matching outfit packs already used by Delve. Keep their original asset license with any source distribution.

`campfire.png` is the unchanged four-frame 32-pixel campfire sheet from the installed `Serene_Village_revamped_v1.9/SERENE_VILLAGE_REVAMPED/Animated stuff` pack. `outpost_props.png` is the unchanged `Fantasy_Outside_C.png` from the installed Winlu Fantasy Exterior pack; the village keeps a few of its atlas regions as cards (training targets, the washing line, the shrine stones).

To give another catalog character seated art, author its `appearance.tres` and add its id and appearance to `SeatedIds` and `SeatedLooks` on the `Residents` node of `village.tscn`. Give it a day in `VillageSchedule`; without one it wanders the commons. Raven and Thistle retain the same provisional sprite identities used by combat until they receive their own art.
