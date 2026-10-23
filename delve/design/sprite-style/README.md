# Delve sprite style reference

Use the enemies in the top row as the rendering reference. The humans in the bottom row are construction studies. Their presence in this sheet does not approve their style or runtime scale.

- [Native comparison](reference-sheet-1x.png)
- [4x comparison](reference-sheet-4x.png)
- [Measured pixels and source hashes](reference-profile.json)
- [Human construction and modular layer rules](../human_sprite_guidelines.md)

## Measured reference frames

The measurements below come from the PNG pixels, including every nontransparent color. Bounds exclude transparent padding. These are selected frames, not whole-animation palette audits.

| Reference | Canvas | Visible bounds size | Used colors | Role |
|---|---|---|---|---|
| Rat v1, idle 1 | 62 x 44 | 37 x 26 | 16 | Contrast, contour accents, simple body planes |
| Goblin base | 56 x 64 | 35 x 52 | 9 | Humanoid shading and near/far overlaps |
| Kobold base | 64 x 64 | 52 x 52 | 10 | Warm ramp, broad planes, sparse accents |
| Wolf base | 72 x 56 | 63 x 38 | 8 | Large flat masses and light/dark separation |
| Pack human body | 128 x 96 | 41 x 65 | 6 | Adult construction study |
| Pack human outfit | 128 x 96 | 41 x 66 | 25 | Garment registration study |

All six sampled PNGs have binary alpha. Every sprite is shown at the same pixel scale within each sheet. The lowest opaque row is aligned for comparison. This does not replace the runtime ground anchor.

## Rules taken from this comparison

The goblin's main green occupies 552 pixels; its upper contour color occupies 22. The wolf's main grey occupies 582 pixels; its light grey occupies 43. These observations support broad main planes and sparse contour accents. They are not percentage quotas for other materials or characters.

The rat uses 16 colors, including small face accents. An eight-color limit would reject this reference. Use a small named ramp for each material and an explicit per-asset palette. Do not impose one total color count on all creatures and outfits.

The pack human has six colors but many small muscle-shadow patches. Its dressed version adds repeated narrow folds and dark clothing details. A palette swap would retain that density. For the enemy style, simplify the shadow shapes and folds while preserving the useful joint placement. Review the simplified result beside the enemies before treating it as a new human reference.

The goblin's large head, ears, crouch, and short legs identify its species. Copy its rendering treatment onto human anatomy. Do not use its proportions as an adult human template. The Mana Seed identity studies use another proportion and rendering system; they are not references for this enemy-style task.

## Existing layer defect

The [goblin removal review](goblin-removal-review.png) shows frame one of `goblin-base/goblin-base.aseprite`, left to right: saved composite, near arm hidden, loincloth hidden, both hidden. Removing the near arm exposes an incomplete torso contour and detached pixels around the former shoulder/arm boundary. The loincloth has underlying skin, but that does not establish complete anatomy behind the arm.

The skill's `palette_check.lua` reports PASS on all ten layers with the nine-color goblin palette. The [log](goblin-palette-check.log) and the removal image demonstrate different checks: valid colors can coexist with unusable hidden anatomy. Use this master for rendering reference. Reconstruct the covered body surfaces before adapting its segmentation method to a modular human. The source master was not edited during this review.

This review used Aseprite 1.3.18.6 and `aseprite-sprite-studio/scripts/sheet.lua`. Its `files` parameter repeats the master four times, with these hide suffixes: none, `|09 Near arm and hand`, `|05 Plain loincloth - removable`, and `|09 Near arm and hand,05 Plain loincloth - removable`. Entries are separated with semicolons; `scale=4`. Source paths are relative to `design` in this paragraph.

## Sampled ramps

These colors are evidence from the top-row sprites. Select relevant material ramps for a task and write the full allowed hex list in its brief. A new human skin ramp needs its own render review; green skin is not a requirement for style consistency.

| Material | Deepest overlap | Deep shadow | Shadow | Main | Short highlight |
|---|---|---|---|---|---|
| Goblin skin | `#202624` | `#29362C` | `#4B593E` | `#849467` | `#B2BD8E` |
| Kobold skin | `#202624` | `#3C2E29` | `#784934` | `#B27657` | `#D49E77` |
| Wolf grey fur | `#181F21` | `#252E2E` | `#424B50` | `#747D85` | `#ADB7B7` |

The goblin also uses `#594439`, `#A77562`, `#EEE2C7`, and `#FFCD6E`. The nine-color total includes those colors. Other sprites' complete lists are in the JSON. The darkest color belongs at selected overlaps and undersides; it is not a continuous border around every shape.

## Rebuild the evidence

From the workspace root:

```powershell
python delve/tools/profile_sprite_references.py
```

This reads six existing PNGs and rewrites only this folder's two comparison sheets and JSON profile. It does not modify source sprites. After changing a reference, rebuild the evidence and review any changed measurements before updating this document. The profile records source SHA-256 hashes so a later task can detect reference drift.

The PNG sheets and Aseprite audit log remain local design artifacts under the repo's ignore rules. The guidelines, measurement JSON and profiler are versionable. The Python profiler rebuilds the two reference sheets; the removal review requires the Aseprite command described above. On Windows, wait for the GUI executable to finish with `Start-Process -WindowStyle Hidden -Wait -PassThru` before reading its exit code or checking its outputs.

These checks describe pixels and dimensions. They do not certify anatomy, clean hidden layers, garment compatibility, animation, or in-game readability.
