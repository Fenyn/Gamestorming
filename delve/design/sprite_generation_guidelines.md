# Sprite generation guidelines

Use this guide for new Delve creature sprites and revisions to existing sprites. It records the lessons from the rat-to-goblin iteration. The target is clean, readable game art that belongs beside the existing sprites. More detail does not mean a better result.

## Reference hierarchy

1. The user's latest direction determines what to change and what to preserve.
2. The existing game sprites determine rendering style, pixel scale, perspective, and visual density.
3. A generated image can help establish construction and pose. It does not replace the game's style reference.

For the current enemy style, inspect [rat_v1 idle](../assets/sprites/enemies/rat_v1/idle_1.png) and the [enlarged rat reference](goblin-base/rat-reference-8x.png). The refined [goblin master](goblin-base/goblin-base.aseprite) and [PNG](goblin-base/goblin-base.png) show the resulting humanoid treatment. [Rat, goblin, and silhouette comparison](goblin-base/rat-and-silhouette-review.png) uses the same pixel scale and aligns the feet.

Do not use the early goblin drafts or [generated construction reference](goblin-base/construction-reference.png) as the final rendering target. They are useful records of what needed correction.

## What makes the rat style work

- Broad, mostly uniform areas carry the main body color. The surface is not mottled with highlights or texture.
- A small number of distinct values separate lit surfaces, shadow planes, and deep overlaps.
- Short light segments follow selected upper contours. They do not form a continuous rim around the sprite.
- Dark shapes explain overlaps and undersides, especially where legs meet the body. They have a structural purpose.
- Small, high-contrast face details provide a focal point. They do not compete with details across the entire body.
- Pixel clusters and stepped contours stay crisp at native size. There is no soft filtering or painted texture.

Flat color still needs depth. Keep the large planes simple, then place a few deliberate shadows and edge accents where they explain the form.

When a sound flat sprite looks dull beside the rat, check value separation before adding detail. Our goblin and kobold improved with deeper overlap shadows, slightly brighter main colors, clearer short contour highlights, and stronger tiny face accents. This was a palette-only pass; it preserved the shading shapes and avoided new texture. Refresh dependent outfit composites and restored hand pixels when the base palette changes.

## Workflow

### 1. Inspect before drawing

Open the actual reference pixels at native size and an integer enlargement. Inspect more than one frame if pose or overlap is unclear. Record the canvas dimensions, visible bounds, facing direction, ground contact, main color groups, and light direction. Check how the game sizes and anchors sprites before changing a runtime asset's dimensions.

Write a short construction brief: species, camera, stance, relative body proportions, equipment state, and parts that must remain editable. Do not start by adding face details to an unresolved body.

### 2. Establish one coherent pose

Block the head, ribcage, pelvis, shoulder, elbows, hips, knees, hands, and feet. Use a simple skeleton or solid masses before shading.

Head, chest, pelvis, and feet must share a coherent viewing direction. Distinguish near and far limbs through overlap and placement. Do not attach a profile head to a frontal torso by accident. Keep the weight supported by the feet and make the joint chain understandable.

Exaggerated goblin proportions are valid when they are consistent. The failed early revisions had a long exposed neck, a large projecting head, pipe-like arms, and legs that did not share a convincing stance. Merely stretching the legs did not fix the construction.

Check the silhouette before polishing. It should communicate the creature and pose without internal detail. Negative spaces around arms and between legs should support the stance, not look like rectangular holes cut into the body.

### 3. Use generation for the problem it can solve

The successful route here was a stronger generated construction reference followed by substantial Aseprite reconstruction and repainting. Repeated small edits to the weak initial pixel construction did not produce a convincing body.

When generating, explicitly separate the image's roles: the rat supplies style; the new creature supplies anatomy and pose. Request one complete unarmed base pose, a limited palette, clear overlaps, and a simple background that can be removed. Preserve transparency when the generator supplies it; otherwise remove the chosen background completely during preparation.

Inspect the result before importing it as a final asset. A good pose can arrive with the wrong rendering style. Our generated reference had excessive shading and texture even though the prompt asked for simplicity. Keep the useful pose and replace the unsuitable rendering.

Prompt starting point:

> Create one [creature] base sprite for Delve. Use the supplied rat only as the rendering and pixel-scale reference. Use a coherent [view/facing] throughout the head, torso, pelvis, and feet, with clear near/far limb overlaps and a grounded [stance]. Keep [equipment state] and leave the body suitable for later gear layers. Use broad flat color clusters, one main shadow tone, sparse deep overlap shadows, and short highlights on upper contours. No dithering, mottled texture, scattered highlights, gradients, or continuous heavy outlines. Show one full-body pose with room around it. Prioritize construction and readability at the intended native resolution.

This is a starting brief, not a guarantee of quality. Save the exact prompt and identify which tool produced the reference.

### 4. Reconstruct on the native grid in Aseprite

Choose a real working resolution based on the game and reference, not the generator's presentation dimensions. An enlarged image that resembles pixel art is not necessarily aligned to a uniform grid.

Sample or redraw onto a fixed grid, remove the background, collapse texture colors into deliberate palette entries, and repair broken contours. Nearest-neighbor scaling preserves existing pixels; it does not fix poor source construction or noisy shading.

The current goblin uses a 56 x 64 canvas with visible bounds of 35 x 52 pixels and nine opaque colors. These are facts about this asset, not mandatory dimensions or color counts for future creatures. Its taller canvas is not yet validated as an integrated combat asset.

### 5. Paint flat planes, then add depth

Start with a main skin color and a broad shadow color. Reserve deeper values for overlaps and small highlights for selected upper contours. Keep clothing colors independent of skin so later palette variants remain practical.

Give each shadow a reason: cast shadow, surface turning away from the light, or occlusion between parts. If a patch cannot be explained that way, remove or reshape it.

For humanoid bodies:

- **Torso:** taper the shadow around the ribcage and waist. Connect it to the shoulder or far arm where appropriate. Avoid a floating rectangular stripe across the chest or a horizontal dark band across the abdomen.
- **Arms:** follow the changing width and direction from shoulder through elbow to wrist. Let the shadow narrow and turn at the elbow. Separate the near upper arm from the torso with a small overlap shadow, not a dark tube around the whole limb.
- **Legs:** carry the shadow along the thigh, bend it through the knee, and taper it down the calf. Avoid switching abruptly from one fixed horizontal threshold to another at the knee.
- **Far limbs:** use a darker overall plane and selective overlap shadows. They should recede while retaining readable hands, knees, and feet.
- **Edges:** place short highlights where upper-facing contours catch light. Use deep accents under the jaw and at selected contact edges. Do not outline every edge equally.

Draw shadow shapes for the whole form, not independently within rectangular layer bounds. In procedural Aseprite work, authored stepped boundaries or carefully shaped polygons are better than rules such as `x >= fixed_value` across an entire limb. Code that runs correctly can still produce bad art; inspect the rendered result.

### 6. Preserve the parts that are working

Once the user accepts the pose, fix shading without changing the silhouette, scale, or palette unless the correction requires it. Once flat rendering is established, do not reintroduce texture during a depth pass.

Use one focused revision at a time: construction, flat colors, edge depth, then body-shadow cleanup. Save the previous master before overwriting it and compare against the immediately preceding version, not an unrelated early draft.

### 7. Match contrast before declaring the sprite finished

Place the result beside the rat and the latest approved goblin/kobold at equal pixel scale. Clean shapes can still look dull if the darkest overlaps are too close to the main body color or the short highlights are too weak.

First adjust palette values while keeping pixel placement fixed: deepen the darkest overlap color, modestly lift the main body color if needed, and separate the upper contour highlight. Strengthen small focal accents such as eyes, teeth, or horn tips. Preserve broad flat areas and the existing color count. Do not add texture, a full outline, or extra highlight dots to manufacture contrast.

Check the result on the same neutral background and at native size. Keep the rat unchanged as the control. Verify that a palette-only pass leaves the alpha mask and color-region geometry unchanged. Refresh any outfit composites and restored hand layers that depend on the base colors.

For a new quadruped such as a wolf, establish a horizontal ribcage, pelvis, shoulder, four coherent leg chains, and grounded feet before shading. Separate near and far legs through overlap and darker values. Use the rat's rendering treatment, but build the new animal's anatomy; do not stretch the rat into a different species. Suggest fur with a few silhouette breaks at the neck or tail, not repeated surface texture.

## Editable delivery

Deliver an Aseprite master, transparent native PNG, integer-scale preview, and a reference comparison. Keep an exact prompt/provenance note when generation was used.

Separate useful anatomical parts and removable clothing into named layers. Near/far order must match the pose. Continue the body underneath removable clothing and check it with that layer hidden. Do not claim complete hidden anatomy merely because the visible flattened render looks correct. Leave a practical place for equipment overlays and preserve hand registration.

Treat the master and rebuild script consistently. If the script is the source, encode the cleanup in it. If the master has manual edits, preserve them before rebuilding; the current goblin script overwrites its generated outputs. Do not deliver a script that silently recreates an older version.

The current [Aseprite build script](../tools/draw_goblin_base.lua) contains reference sampling, deliberate flat-color repainting, layer assembly, previews, and a saved-master comparison. Reuse its workflow, not its creature-specific masks or sampling coordinates.

## Review before delivery

- View at native size and an integer enlargement. Native-size readability is the primary check; enlargement reveals pixel errors.
- Compare beside the actual rat on a neutral background, at identical pixel scale with feet aligned. Do not scale each creature independently to make them appear compatible.
- Inspect the solid silhouette, anatomical overlaps, and joint transitions. Check that shadows describe volumes rather than square patches.
- Confirm that detail density, highlight frequency, dark accents, and palette contrast still match the reference.
- Compare the depth of underside shadows and brightness of short contour highlights directly with the rat. A clean but uniformly muted sprite still needs a contrast pass.
- Check transparent edges, fixed pixel size, and stray pixels. Use only fully transparent or opaque pixels for this style.
- Reopen the saved Aseprite master and compare its rendered pixels with the exported PNG. Verify useful layers and the intended frame count.
- For a shading-only revision, compare alpha masks to verify the silhouette stayed unchanged; compare palettes when palette preservation was intended.
- State what was changed and show the result. Do not claim professional quality merely because the files exported or the checks passed.

Single-pose asset work and game integration are separate scopes. Goblin, kobold, and wolf bases are now integrated with five-frame breathing and blink idles. The renderer uses each folder's `sprite.tres` and Godot `SpriteFrames`; there is no fixed eight-frame requirement. Author clip names, textures, FPS, per-frame durations, and looping in the resource. Set pixel scale, foot margin, and source-facing direction in the sprite definition. Keep the master canvas intact instead of trimming padding to satisfy renderer constants. See [runtime sprite instructions](../assets/sprites/enemies/README.md).

After changing a base PNG, refresh runtime copies with `python tools/export_enemy_bases.py`; it refreshes the rest clip from idle-timing.json when present and preserves placement and other clips. When integrating art, check animation, world scale, anchoring, and an actual combat screenshot. Outfits are not yet integrated. Dire Wolf now has its own base and animations.

Check the creature's rules size separately from its image canvas: Large occupies 2x2 tiles, Huge 3x3, and Gargantuan at least 4x4. Runtime roots and ground indicators follow the engine footprint. For asymmetric art, set `GroundAnchorX` to the planted support center in the unflipped frame rather than trimming the canvas or centering on a long tail. Verify both facings, movement, and the full footprint in world. Record any reviewed `PixelSize` adjustment in the asset README; keep equal-pixel style comparisons separate from world-size review.

## Research used in this iteration

- [Derek Yu: Pixel Art Basics](https://www.derekyu.com/makegames/pixelart.html): form, coherent lighting, contour cleanup, and selective outlines.
- [Derek Yu: Common Mistakes](https://www.derekyu.com/makegames/pixelart2.html): redundant colors, pillow shading, and flat or flimsy construction.
- [SLYNYRD: Human Anatomy](https://www.slynyrd.com/blog/2019/5/21/pixelblog-17-human-anatomy): establish proportions and gesture before detail.
- [SLYNYRD: Developing Style](https://www.slynyrd.com/blog/2018/7/14/pixelblog-7-developing-style): palette, clusters, perspective, and resolution jointly define style.

Apply these principles through Delve's existing art and the user's feedback. Do not copy a tutorial's palette, proportions, or rendering density indiscriminately.

## Idle animation

Preserve the approved base as frame one in a separate layered Aseprite idle master. Use a one-pixel upper-body lift, a connected waist/chest transition, planted feet, and a short blink between longer holds. Apply the same deformation across overlapping layers to avoid seams. Keep tail motion small and anchored at its root. Preserve palette, flat shading, canvas and foot margin; avoid interpolated pixels and whole-sprite bouncing. Give species different timing. Check every pose, the loop boundary and game playback. Export transparent frames and timing together; gear added later must follow the same body registration in every frame.

Compare full loop duration beside the rat, not FPS alone: frame holds contribute to the total. Current pacing is rat 1.78 seconds, goblin 2 seconds, kobold 1.875 seconds, and wolf 2.25 seconds. Keep blinks brief (0.125 seconds) while adjusting breathing holds. The first 3?4 second base loops looked too slow beside the original 1.33 second rat loop.

## Attack animation

Use anticipation, a clear contact pose, follow-through, and recovery to the approved base. Humanoids strike with an articulated shoulder/elbow/hand chain; a wolf opens and closes its jaw. Preserve foot registration and flat palette. Inspect newly exposed areas when a limb moves: ownership masks may leave stray pixels or missing anatomy. Check contacts and layer seams on every pose. Keep native anatomical layers and leave equipment separate. Author a non-looping clip and its zero-based impact frame in the sprite resource; derive the combat delay from frame holds and FPS. Attacks take priority over movement, resume idle/movement after recovery, and honor frozen poses. Review both contact and recovery in combat.

Before animating a limb, hide it and inspect the rear layers on their own. Complete the tail, torso, and shoulder surfaces behind it; a segmentation mask from a flattened pose contains only visible pixels. Do not carry a hand-shaped notch or its occlusion shadow into an exposed tail. Repair the rear layer before applying frame deformation, and review both the hidden-limb view and every composite. Detached-pixel cleanup cannot reconstruct missing anatomy.

Audit the arm-hidden source itself for detached pixels and one-pixel diagonal spurs at the old shoulder/wrist boundary. Correct layer ownership before export rather than relying only on cleanup of flattened animation frames. Check both support art and all posed frames for connected silhouettes, then inspect the contours visually; connectivity alone does not prove sound anatomy.

For a bite, keep the upper muzzle and nose stable while the lower jaw turns down from a cheek hinge. Shape the opening as a tapered mouth cavity, not parallel horizontal bars. Use sparse tooth pixels against the dark cavity; show them at contact as well as during the open pose. Check that the chin stays connected and recovery restores the base face.

For a coiled snake, keep a continuous neck-to-coil connection and a fixed ground contact. Use the pale belly and dark overlaps to explain the coil; omit repeated scale texture. Separate tail, coil, neck, and head into native layers. Snakes keep their eyes open: use a slight neck lift for idle instead of copying the humanoid blink. Reserve canvas room for the extended strike, and place bite VFX beyond the contact pose's muzzle. See `viper-base/README.md` for the complete asset setup.
