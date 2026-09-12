# Outpost camp assets

`camp_stage.tscn` is a live 3D diorama. Residents are pixel sprites on selectable controls projected onto authored camp positions. The fixed camera keeps their visual and input positions together across the project's viewport scaling.

The character layer PNGs are unchanged Mana Seed page 4 paper-doll sources by Seliel the Shaper. Recipes match the existing hero folders: veteran (Aldric), rogue (Elara and current Raven fallback), cleric (Tharr), wizard (Fenwick), recruit (current Thistle fallback). Each `appearance.tres` names the original body, outfit, and hair/hat textures. `CampAppearance` composites and caches them in memory. The seated pose is page 4, column 5, row 4. Preparation uses movement-page steps followed by the current hero's standing frame; all frame coordinates are zero-based. No source combat sheet is overwritten.

The original layers come from `F:/UnityNVME/Art/Sprites/Mana Seed/`, using the character base and the matching outfit packs already used by Delve. Keep their original asset license with any source distribution.

`campfire.png` is the unchanged four-frame 32-pixel campfire sheet from the installed `Serene_Village_revamped_v1.9/SERENE_VILLAGE_REVAMPED/Animated stuff` pack. `outpost_props.png` is the unchanged `Fantasy_Outside_C.png` from the installed Winlu Fantasy Exterior pack; authored atlas regions supply fallen logs, supplies, shared tools, a table, and herb pots. Trees and grass reuse Delve's existing Winlu decor.

To add another catalog character, author its camp appearance and a stable position in `camp_stage.tscn`, keyed by its entry in `SeatIds` (the position and appearance arrays use that same seat index, independently of catalog order). Unlock refreshes append residents without rebuilding existing animations or selection. Raven and Thistle retain the same provisional sprite identities used by combat until they receive their own art.
