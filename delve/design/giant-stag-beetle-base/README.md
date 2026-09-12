# Giant Stag Beetle

Rebuild with Aseprite `--batch --script tools/build_giant_stag_beetle.lua` from the Delve workspace. The Lua source owns all native pixels and regenerates layered base, idle and attack masters, PNG frames, GIF reviews, comparisons, and runtime files. Generated construction art is recorded separately in `provenance.md`.

Canvas: 88x64. Base visible bounds: x10..81, y17..59. Nine opaque colors, binary alpha. Right-facing, 0.025 world units per pixel, four-pixel bottom margin. Six separate editable leg layers attach beneath the pronotum, with darker far limbs behind the body. Shell, pronotum, head, each mandible and antennae remain independently editable.

Idle: five frames at 8 FPS with holds [5,3,2,3,5], a 2.25-second loop. One-pixel upper-body lift and subtle pincer motion; feet remain planted and eyes stay open. Attack: six frames at 10 FPS with holds [0.8,1,0.8,1,1.2,1], 0.58 seconds total; zero-based contact frame 2 at 0.18 seconds. Anticipation opens the mandibles, contact closes their inner prongs, recovery returns exactly to base.

Review corrections:

- Bent the near middle leg rather than keeping its upper/lower chain nearly vertical.
- Rebuilt the circular pincer silhouette as asymmetric open stag mandibles with a clear inner prong on each jaw.
- User identified misplaced shadows. Removed the internal dark shell stripe entirely. The lit dome is now one broad plane. Shell shadow follows the lower-right turning surface, and a narrow deeper lower edge explains the shell overhang.
- Pronotum occlusion occurs at the shell junction; its lower shadow follows the underside. Head shadow wraps beneath the mouth/cheek volume. These replace the earlier high diagonal bands.
- After individual review, restored a broad curved shell side plane and separate pronotum/head side planes. A narrow dark head/pronotum junction separates these segments. Added an intermediate shadow value for continuous tapered leg side planes and more visible far legs, avoiding the earlier alternating light/dark shin pixels.
- `shading-before-after-8x.png` shows the shading correction with identical silhouette; the final depth revision adds one intermediate leg/body shadow value. `reference-lineup-4x.png` keeps every creature at the same pixel scale and aligns lowest opaque pixels at y63. Earlier revisions are preserved in named subfolders.

Checks: every saved master was reopened and its rendered frame compared pixel-for-pixel to export; expected 12 anatomical layers and 1/5/6 frames. All base and animation PNGs use only alpha 0/255. Attack recovery and first/final idle frame equal base. Runtime art mirrors source exports. The runtime definition references the existing bite accent; actual combat placement/playback review belongs to the integration pass.


Runtime placement review: `sprite.tres` uses PixelSize=.025 and GroundAnchorX=42.5 pixels, with four pixels of bottom padding. This centers the planted support under the token in both facings. Native PNGs and layered masters are unchanged. See `../fringe-sprite-review/footprint-combat/` for the in-world captures.
