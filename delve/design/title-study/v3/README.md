# Delve title v3

Direction: Final Fantasy Tactics / Tactics Ogre era readability, deliberate pixel clusters, compact character silhouettes, and restrained HD-2D atmosphere.

Open `delve-title-v3.aseprite` for the editable master. Native canvas: **640 x 360**, one frame, 18 paint layers in six groups. `delve-title-v3-1080p.png` is an exact nearest-neighbor 3x export. V1 and V2 remain beside this folder.

## Artwork changes and provenance

The environment was repainted with the built-in image generation tool to simplify materials and remove the old characters and banner. A second generated plate supplies a complete empty valley behind the scenery. A separately generated transparent sprite sheet replaces the travelers, using the project character profiles: Aldric the human, Elara the elf, Tharr the dwarf, and Fenwick the halfling.

Aseprite scripts resample onto the native grid, remap the environment to 64 authored colors and the travelers to 30, then consolidate weak isolated interior pixels and small texture clusters. No dithering or smooth interpolation is applied. Character silhouettes retain transparency. Native character dimensions are Aldric 26 x 52, Elara 26 x 49, Tharr 33 x 38, Fenwick 28 x 34. These are title-screen interpretations, not gameplay sprite replacements.

The title, banner cloth, watchlight emblem, contact shadows, fog overlays, and lantern-core overlays are drawn with Aseprite Lua primitives. The environment and character bases are generated art with scripted cleanup; they are **not entirely hand-pixeled originals**. Further manual form-by-form refinement remains possible in the master.

## Layer structure and movement

| Group | Contents | Animation use |
| --- | --- | --- |
| 01 BACKDROP | Complete valley plate, sky, distant forest, far mist | Mist drifts independently; plate fills holes behind extracted scenery |
| 02 OUTPOST | Chapel/tower/bridge, lantern cores | Core opacity flicker; static illumination on masonry remains baked |
| 03 FOREGROUND | Empty approach and banks, framing trees/support, separate banner | Banner can bend below the fixed attachment |
| 04 PARTY | Contact shadows and one transparent layer per traveler | Small idle motion with stationary feet; no old characters underneath |
| 05 ATMOSPHERE | Near-valley mist | Independent slow drift |
| 06 TITLE | Shadow, lettering, ornament | Fixed screen space |

The wide structural scenery cuts are an editing scaffold. **Keep the architecture, ground, sky and forest registered together for now.** Their cutout boundaries and occluded structural surfaces still need detailed matte work and underpainting before broad independent parallax or camera travel. The full valley plate supplies background coverage, but does not reconstruct hidden bridge and paving geometry. The separate mist overlays do not replace all fog already painted into the scenery. The torch overlay flickers the hot cores; it does not relight the environment.

`delve-title-v3-motion-study.gif` demonstrates a 16-frame, 2.56-second loop: 1-3 px mist drift, 1-2 px banner flex, lantern-core opacity variation, and 1 px upper-body idle compression with fixed feet. `delve-title-v3-motion-study.aseprite` contains that prototype separately from the one-frame master. It is a motion/coverage study, not a finished character animation set.

## Exports and review

- `layers/` contains aligned transparent PNG exports and `manifest.tsv`. **Every exported layer PNG is full-canvas 640 x 360 and belongs at (0, 0).** Manifest x/y values describe cropped cels inside the Aseprite document, not an extra PNG placement offset.
- `parts/` contains the cleaned environment/valley and cropped individual travelers.
- `travelers-review-4x.png` shows the four native sprites enlarged without interpolation.
- `clean-path-check.png` hides the party, shadows and banner to inspect coverage.
- `motion-frame-check.png` is a frame from the motion study.
- `prompts.md` records the three built-in image generation prompts.

The saved master was reopened and checked for its dimensions, frame count, six groups, 18 nonempty paint layers, an opaque full-size valley plate, and four transparent character sprites. Static, cutaway and motion-frame exports were visually inspected. No Godot scenes or game code were changed.

## Rebuild

Run from the `delve` directory with the installed Aseprite executable. Scripts write the generated V3 outputs in this folder, so copy the master before rebuilding after manual edits.

```powershell
$asepriteExe = 'E:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe'
& $asepriteExe --batch --script tools/prepare_title_v3.lua
& $asepriteExe --batch --script tools/assemble_title_v3.lua
& $asepriteExe --batch --script tools/check_title_v3.lua
```

Shared palette and clustering helpers are in `tools/title_pixels.lua`; coarse scenery masks are in `tools/title_v3_masks.lua`.
