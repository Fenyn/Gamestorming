# Sprite credits & licensing

## Heroes — Mana Seed Character Base
- Source: Seliel the Shaper's Mana Seed Character Base (https://seliel-the-shaper.itch.io/character-base),
  plus the "Peasant Farmer Pants & Hat" and "Forester Pointed Hat & Tunic" outfit add-ons.
  Local pack: `F:\UnityNVME\Art\Sprites\Mana Seed`.
- License (from the packs' readmes): usable commercially or non-commercially; do not redistribute or
  resell the source layers. Only baked composites are vendored here, never the pack's layer files.
- The `heroes/<name>/*.png` sheets are baked paper-doll composites (body + outfit + hair), one set per
  preset character, produced by `G:\crocotile-mcp\examples\build_mana_seed_sheets.py`. That script
  carries the per-character layer recipe and its `--verify` mode re-derives `p1.png` and proves it
  pixel-identical to what is vendored — run it before baking any new page so a character cannot
  change hair or clothes between one animation and another.
- Every page is 512x512, an 8x8 grid of 64x64 cells, with the same S/N/E/W facing-row order:
  - `p1.png` — movement. Rows 0-3 stand frame at column 0 (columns 1-2 push, 3-4 pull, 5-7 jump —
    art present, unwired); rows 4-7 the 6-frame walk cycle (columns 0-5; 6-7 are run alternates).
  - `p2.png` — work actions, hoe. Four 4-frame clips: rows 0-3 cols 0-3 swing, cols 4-7 seed;
    rows 4-7 cols 0-3 water, cols 4-7 pull up / harvest.
  - `p2_mine.png` / `p2_wood.png` — identical to `p2.png` except the swing quadrant, where the pack's
    tool layer draws a pickaxe / an axe instead of a hoe.
- Per-character recipe (base + outfit + hair), recovered by pixel-matching the shipped sheets:
  cleric `humn_v04 + pfpn_v05 + bob1_v10`; recruit `humn_v02 + pfpn_v01 + bob1_v03`;
  rogue `humn_v03 + fstr_v02 + bob1_v07`; veteran `humn_v01 + fstr_v01 + dap1_v02`;
  wizard `humn_v05 + fstr_v04 + dap1_v09`. None wears a hat.
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
- License (Winlu's standard terms): usable in commercial and non-commercial projects; do not
  redistribute or resell the assets themselves.

These assets are used under their respective licenses for this prototype. Do not redistribute or
resell the rat sprites.
