# Sprite credits & licensing

## Heroes — Mana Seed Character Base (free demo)
- Source: "FREE Mana Seed Character Base Demo 2.0" by Seliel the Shaper
  (https://seliel-the-shaper.itch.io/character-base).
- License (from the demo's readme): "You may use this demo asset commercially or non-commercially."
  The full paid asset adds many more animation pages.
- The `heroes/<name>/p1.png` sheets here are baked paper-doll composites (body + outfit + hair
  layers from the demo), one per preset character. 512x512, 8x8 grid of 64x64 cells:
  rows 0-3 = single stand frame facing S/N/E/W (column 0); rows 4-7 = 6-frame walk cycle in the
  same direction order (columns 0-5; columns 6-7 are run-cycle alternate frames, unused).
- The demo also ships 3 pages of sword-and-shield combat animations (char_a_pONE1..3) that can be
  baked the same way for attack/hit animations later.

## Enemies — Rat pixel sprites
- Source: Rat sprite pack (variants v1/v2/v3), side-view pixel art (idle frames 62x44).
  Contact: bladeliger12@naver.com — https://ggoolmool.itch.io
- License (from the pack's License.txt):
  "You can use this asset for personal and commercial purpose. You can modify this object to
  your needs. You can NOT redistribute or resell it."
- Only the Idle frames are vendored here (`rat_vN/idle_1..8.png`). Default art faces right.

These assets are used under their respective licenses for this prototype. Do not redistribute or
resell the rat sprites.
