# Card art process notes

What moved Tide Torrent from "very amateur" (draft 1) to a card that reads (draft 5), 2026-09-25. The rules these produced are in `card_art_guide.md`. This file records why they work, so later changes to the method keep them.

## What made the difference

1. **Studying real references before drawing a new effect.** Water failed three times while I invented its shapes, reading in turn as a leg, a club and a mace. I then downloaded two or three good pixel-art examples (saint11's water tutorial and itch.io water-spell GIFs) and wrote down what made them read. The answer was edges: a flat mid body, uneven streaks, light at the top edge, ragged outlines, and spray peeling off. The first jet built on those notes read as water.
2. **Small parts reviewed alone, then composited.** Each object (hood, cape, arm, rival, wave) is its own grid file, checked at 8x on neutral grey before it goes into a scene. A bad read then gets fixed in one small file instead of being tangled into a 226x160 picture. Parts also carry their lessons forward in a `note` header.
3. **Hand-refined grids over formula shading.** Draft 1 shaded every pixel with a formula (polygon fill plus lighting math), and it looked like clip art. Blocking a shape with a quick script and then editing the printed grid by hand gave designed clusters, varied fold spacing and deliberate highlights.
4. **Drawing at half size and doubling with Scale2x.** Parts are authored at 113x80 scale and each layer is doubled. Every object comes out at one pixel size, diagonals come out smooth, and loose pixels dropped from 63 to 2 or 3. It is also a quarter of the cells to hand-author.
5. **Material ramps instead of colours in the parts.** A grid says "hood step 3", not a hex value, so the same hood serves any house and any school light. The palettes split by what they describe (environment, skin, school magic, house costume), so they recombine per card.
6. **An adversarial critic panel, four lenses, several rounds.** Pixel technique, composition, lore and art direction, and pipeline. Each round they named the object a shape was reading as (fish, eye, mace, numeral 2, UFO, shed, hazard sign), and naming the misread is what made each fix obvious. Cross-attack rounds stopped any one lens from winning by default.
7. **Measuring instead of eyeballing.** `check.py` counts colours, loose pixels and checker dither, gives value shares in four bands, and saves a hand-size thumbnail and a value map. Several defects, like the torrent matching the sky's value or 61% of the frame sitting in the darkest band, were only visible in the numbers or the value map.
8. **A scene file and a fixed layer stack.** Once `build.lua` owned the sky, ground, gate, layer order and export, a card became about 70 lines of placement and spell hooks. Iterating on the art stopped breaking the plumbing.
9. **The user's taste calls asked, not guessed.** House colours, sea-glass use and the rival's house were put to the user as questions. Everything else the panel settled with reasons.

## Second round: figures and environment (user rated them 2/10, water 5/10)

- **The same move worked again.** Two reference studies ran in parallel as agents (figures: saint11 Fabric/Metal/Outlines, Slynyrd's knight and action poses, a Mana Seed cloak; environment: Slynyrd skies, ruin backgrounds, grass fields). Each returned ten numbered rules with numbers, and the rebuild followed them. Notes kept in `F:\UnityNVME\Art\_Zenith\Kit\refs\` (`figures_study.md`, `environment_study.md`).
- **What the figure study changed:** a 1 px outline at full size after doubling; wide ramps with a hard terminator and a specular; fanned folds; a peaked hood with a capelet; a rival with anatomy.
- **What the environment study changed:** sky strata instead of bands, ground and stones receding in perspective, and a ruined, asymmetric seal gate with a dark mouth.
- **Placement is part of the drawing.** The new hood was right but covered the arm until the arm was moved past the capelet and stamped on top.

## Third round: figures from posed 3D models (user rated people 3/10 after two hand-drawn rounds)

- Hand-drawn grids plateaued because anatomy, pose and perspective are what blind grid drawing gets wrong. Rendering posed rigged models (the Dead Cells approach) fixed that in one step: the first test's rival reads as an armoured person reacting to a hit.
- Pipeline: `Kit/blockout/pose_render.py` (headless Blender 5.0, glTF, an action frame plus bone tweaks, a camera set in a JSON scene) writes an unlit albedo pass and a light pass lit by the spell. `Kit/blockout/to_grid.py` maps albedo colours to kit materials and the light to ramp steps by percentile, per material, with teal light becoming the rim step. The result is a kit grid at full size, placed by `figures_1x` in the scene file.
- Percentile steps matter. Fixed thresholds collapsed a back-lit figure into one flat value.
- Full size keeps noticeably more figure detail than half size. So figures are 1x while the environment stays half size and doubled.
- The first test used the RPG Characters pack already on disk, which has chibi proportions and so a bucket-sized hood. The user's plan is to use realistic base characters with modular outfits, one fixed identity per cast member, reused in every card.

## Fourth round: character identities and animation snapshots

- **The card formula (user's direction):** personality identities, posed from animation snapshots, with spell effects drawn between them over the shared environment. Alder Rooke is the face of Tide.
- **Identity** = one JSON in `Kit/identities/`: a Universal Base Characters body (only head, neck and hands kept, by bone weight, so it never pokes through the outfit), Modular Character Outfits parts and hair, all rebound to one skeleton, plus an object-to-kit-material table and a character palette (`palettes/char_<name>.lua`).
- **Poses** come from the Universal Animation Library 1 and 2 on the same skeleton (`Spell_Simple_Shoot`, `Idle_Shield_Loop`, `Hit_Chest`, `Sword_Block` and others), at one frame, with small bone tweaks on top. Posing from raw bone angles gave figures that looked like they were walking or shrugging. The user called the result "bizarre".
- **Props** such as a shield are parented to a bone. They have to be offset along their own facing axis, or they cut into the arm. Test the offset from above.
- **ID colours** must be converted from sRGB to linear before rendering, or the saved IDs shift and materials swap.
- **Layer stack** gained "Spell behind" under the rival, so a burst breaks on a shield with the rim in front of it.

## Fifth round: adversarial pass on pose, framing, effects and conversion

- **Poses start from a library clip, with at most a few tweaks.** Alder uses UAL1 `Spell_Simple_Shoot` frame 5, then raises her far arm above her head, stands her up 8 degrees, opens the near hand, and lifts the near arm. My earlier hand-set angles read as a surrender, a hand to the ear or sleepwalking.
- **Two streams need two hands apart across the line of flight** (10 px or more at card size). Put one hand high and far, the other low and near. Hands at the same height give parallel rails that merge into one band. Join them in a Y on the far stream's line to the target, with the near stream wider and drawn on top.
- **Camera and pose must be picked together.** A pose that works under one camera turned to profile under another. Check for profile after every camera or rotation change. A camera roll tilts the figures against the flat painted horizon, so the roll stays at 0.
- **Rival:** `Hit_Knockback` frame 4 turned to about -60 reads as flung on a diagonal. Frame 3 reads as a man sitting in a chair.
- **Key light:** `key.dir` points toward the light. Getting it backwards lit Alder from below.
- **Spell light energy about 40:** at 120-250 it flooded the rival teal.
- **Conversion:**
  - Render with 96 samples, the denoiser on and dither off, or the hair comes out as static.
  - Keep albedo detail off for plate.
  - The loose-pixel clean-up needs only one figure neighbour.
  - Share one rim colour across all figures to save colours.

## What did not work, and why

- **Formula shading of whole shapes** (lambert on ellipsoids, neighbour-offset bands) gave pillow shading and banding.
- **Growing effects by count**, such as parallel bands on a tube or diagonal braids, read as a leek, a net or a caterpillar.
- **Checker dither for gradients** made screen-door stripes.
- **Fixing the scene when the part was wrong.** A bad part stays bad in every scene that uses it.
- **Patching files with throwaway scripts.** The user's rule is direct edits. Scripts only print grids to copy into a part file.

## Open (draft 5, superseded)

- The caster's cape is a large flat dark area, and the splash is small for "no end to it".
- The kit has one caster pose and one rival pose. A second school's card will show what carries over.
- The critics have not reviewed draft 5.

## After draft 5: the 3D pipeline

The hand-drawn kit was replaced by 3D identities, 3D spell geometry and a converter; `card_art_guide.md` describes the method. The turning points, in order:

- Quaternius base characters plus modular outfits as character identities, posed from an animation library. Figures jumped from "2/10" to usable.
- Rotoscoped look (smooth light cut by percentile) fixed with flat shading and no cast shadows, then the user asked for richer art: long hue-shifted ramps, smooth shading, a fill light, double resolution.
- Water drawn by generators plateaued for nine review cycles (hose, cloth, crystal, slime, a teal figure). Building it in Blender as metaballs with a foam material and flow-stretched noise was the first version reviewers called water.
- The user called out the beam through the rival; the spell now engulfs him.
- Pack backgrounds recoloured by brightness into a quiet ramp replaced the generated sky and gate.
- Judges stayed between 5.8 and 6.4 for fourteen cycles; parameter changes traded one flaw for another. Structural changes moved the card; tuning did not.
