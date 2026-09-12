# Sprite credits & licensing

## Heroes — Mana Seed Character Base
- Source: Seliel the Shaper's Mana Seed Character Base (https://seliel-the-shaper.itch.io/character-base),
  plus the Peasant Farmer, Forester, Blacksmith, Alchemist and Hairstyle add-ons.
  Local pack: `F:\UnityNVME\Art\Sprites\Mana Seed`.
- License (from the packs' readmes): usable commercially or non-commercially; do not redistribute or
  resell the source layers. Only baked composites are vendored here, never the pack's layer files.
- The `heroes/<name>/*.png` sheets are baked paper-doll composites (body + outfit + hair), one set per
  preset character, produced by `G:\crocotile-mcp\examples\build_delve_hero_sheets.py`. That script
  carries the per-character layer recipe (re-dressed 2026-08-24 to match the bulwark character
  bios: Aldric farmhand, Tharr stonemason, Elara merchant, Fenwick gastronomancer) and bakes every
  page from it, so a character cannot change hair or clothes between one animation and another.
- Every page is 512x512, an 8x8 grid of 64x64 cells, with the same S/N/E/W facing-row order:
  - `p1.png` — movement. Rows 0-3 stand frame at column 0 (columns 1-2 push, 3-4 pull, 5-7 jump —
    art present, unwired); rows 4-7 the 6-frame walk cycle (columns 0-5; 6-7 are run alternates).
  - `p2.png` — work actions, hoe. Four 4-frame clips: rows 0-3 cols 0-3 swing, cols 4-7 seed;
    rows 4-7 cols 0-3 water, cols 4-7 pull up / harvest.
  - `p2_mine.png` / `p2_wood.png` — identical to `p2.png` except the swing quadrant, where the pack's
    tool layer draws a pickaxe / an axe instead of a hoe.
- Current Delve recipes (body + outfit + hair/hat), verified against the shipped sheets:
  cleric `humn_v06 + bksm_v03 + flat_v00`; recruit `humn_v02 + pfpn_v01 + bob1_v03`;
  rogue `humn_v02 + fstr_v03 + pon1_v07`; veteran `humn_v04 + pfpn_v02 + dap1_v11`;
  wizard `humn_v03 + alch_v04 + pnty_v01` (hat, no hair layer).
  Editable starter masters and identity proposals: [Mana Seed identities](../../design/manaseed-identities/README.md).
- Not yet baked, available in the pack: `p3` (fishing), `p4` (smithing, climbing, sit/lie/cheer
  emotes), and the sword-and-shield / bow / spear combat pages (`char_a_pONE1..3`, `pBOW1..3`,
  `pPOL1..3`) for attack and hit animations.

## Enemies — Rat pixel sprites
- Source: Rat sprite pack (variants v1/v2/v3), side-view pixel art (idle frames 62x44).
  Contact: bladeliger12@naver.com — https://ggoolmool.itch.io
- License (from the pack's License.txt):
  "You can use this asset for personal and commercial purpose. You can modify this object to
  your needs. You can NOT redistribute or resell it."
- Only the Idle frames are vendored here (`rat_vN/idle_1..8.png`). Default art faces right.

## Terrain decor — Winlu Fantasy Exterior
- Source: Winlu's Fantasy Exterior tileset (https://winlu.itch.io/), local pack:
  `F:\UnityNVME\Art\Sprites\Winlu\Winlu Fantasy Exterior`.
- The `decor/forest/*.png` sprites are individual crops from `!Decoration_vegetation.png`,
  `!$Big_Trees_NoShadow.png`, `!$Cliff_decoration.png`, and `Fantasy_Outside_C.png` — grass tufts,
  stones, flowers, mushroom, bush, stump, log, and edge trees. Semi-transparent baked drop shadows
  are stripped (alpha < 200 cleared) so the billboards sit cleanly on 3D terrain; the flat flower
  patches keep their native pixels.
- The `decor/trees/tree_*.png` sprites are individual crops from `!$Big_Trees_NoShadow.png`,
  `!$Big_Trees_3.png` (dead snags) and `!$Giant_tree_No_Glowing.png`, produced by
  `G:\crocotile-mcp\examples\build_delve_trees.py` (2026-08-26). That script records the crop boxes
  and strips the baked semi-transparent drop shadows (alpha < 200 cleared); the autumn/red
  recolours are vendored alongside the teal forest set for future biomes. They dress the
  `scenes/props/tree_*.tscn` HD-2D billboard props and the terrain halo's tree scatter.
- License (Winlu's standard terms): usable in commercial and non-commercial projects; do not
  redistribute or resell the assets themselves.

## Fringe creature additions

Giant Viper, Giant Monitor Lizard, Dire Wolf, Grizzly Bear and Giant Stag Beetle use
built-in imagegen construction references followed by native Aseprite reconstruction and
animation. Each `design/<creature>-base` directory records the exact prompt/provenance,
layered masters and visual revisions. The existing rat, goblin, wolf and other enemy bases
served as rendering references. Runtime PNGs live in `enemies/<creature>_base`.

These assets are used under their respective licenses for this prototype. Do not redistribute or
resell the rat sprites.
