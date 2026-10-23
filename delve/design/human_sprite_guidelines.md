# Human sprites and modular bases

Read this with [sprite generation guidelines](sprite_generation_guidelines.md). It applies to humans and wearable parts intended to match Delve's enemy sprites. The [measured reference sheet](sprite-style/README.md) fixes the rendering target. Existing human wardrobe studies provide construction and fitting examples; none becomes the approved enemy-style human base through this document alone.

## Record the construction before drawing

Each job needs a brief beside its master. Record these decisions before detailed pixels:

| Decision | Required record |
|---|---|
| Reference roles | Exact rendering reference paths and hashes; separate anatomy and equipment references |
| Source | Purchased source and crop/translation, or code-drawn construction; preserve originals |
| Body | Age/build, body family ID and revision, visible height, head size, stance, camera and facing |
| Grid | Canvas width/height, integer origin, planted foot coordinates and ground anchor |
| Landmarks | Crown, chin, neck root, shoulders, elbows, wrists, pelvis, knees, ankles and grip points in canvas coordinates |
| Palette | Index 0 transparent; every allowed opaque hex; material and value role for each entry |
| Modularity | Required garment/gear slots, supported body revision, poses and facings; layer order |
| Delivery | Required clips, frame durations, export recipe, source of truth and protected layers |

Keep the construction drawing in a hidden `ref/construction` group or a separate reference file. It must show a joint chain and solid body masses at the intended native scale. A construction drawing can be a code-drawn wireframe or blockout. Image generation is optional reference work, subject to the repo's code-drawn pixel rule.

Use a suitable authored pack body first when available. A pack can solve anatomy without matching Delve's rendering. Preserve its original, then simplify a copy for this style. Do not silently replace the current game's human assets while doing a base study.

## Human proportions

Choose proportions for the intended adult, child, or stylized character. For the first ordinary adult study, start around six to seven head heights, with the head measured from crown to chin without hair or headwear. This is a proposed construction range, not an approved Delve human standard. A roughly 60-70 px visible adult beside the 52 px goblin is a useful first comparison; lock the final height only after native and in-game scale review.

SLYNYRD's [human anatomy study](https://www.slynyrd.com/blog/2019/5/21/pixelblog-17-human-anatomy) demonstrates wireframe, mass blockout, and final form, including a six-head stylization. Use that construction method without adopting its palette or finishing style.

At blockout stage:

- Establish the head, ribcage and pelvis as separate masses. Use a short neck connection and a visible waist transition. The head, chest and pelvis must agree on the view unless a deliberate twist is drawn.
- Trace shoulder to elbow to wrist and hip to knee to ankle. Changes in limb width must explain those joints. Avoid straight tubes, box knees, and hands attached directly to upper arms.
- Use the standing figure's crotch near mid-height, relaxed elbows near the waist, and relaxed wrists near the upper thighs as reference checks. Bend and foreshortening change their screen positions. Do not snap every pose to fixed horizontal lines.
- Place the support under the body's weight. Give the feet compatible ground contact and distinct near/far placement. Keep useful negative space between limbs without cutting rectangular slots into the body.
- Read the head and hands at 1x. Do not enlarge the skull or entire canvas merely to fit eyes, fingers, or a detailed mouth. Reduce the feature if the approved pixel budget cannot hold it.
- Represent build through shoulder, ribcage, pelvis, limb and silhouette differences. Hair, beard removal, or recoloring alone does not establish a different body construction.

Review a flat silhouette, then a main/shadow blockout before face or clothing detail. If the figure reads as a child when an adult is intended, revise the head-to-body relationship and joint spacing together. Stretching the legs or shrinking only the head can break the pose.

For a new direction, compare two or three genuinely different blockouts at the same pixel scale. Keep the selected construction as a checkpoint. When an existing approved base already meets the task, use it without reopening the design choice.

## Render humans like the enemies

Keep skin, hair, cloth, leather and metal as named material ramps. Start each material with main and shadow colors, then add a deep overlap or a short highlight only where it improves the form. Shared hex values are allowed, but recoloring must select the material's layers or masks so skin changes cannot recolor boots by accident.

Human skin does not need to inherit goblin green or the pack's skin ramp. Choose a skin tone, test its value separation beside the goblin and kobold, and lock the full hex list before the final draw. A recolor changes values; reducing excessive detail requires changing clusters.

| Region | Draw | Reject |
|---|---|---|
| Head | Forehead/cheek plane, small jaw shadow, economical eye and nose marks | Outlined teeth, a large white eye, scattered face dots |
| Torso | Broad chest/ribcage plane with a tapering side shadow | Separate abs, pectoral stripes, floating dark rectangles |
| Arms and legs | Shadows that turn and taper with elbow/knee changes | Cylindrical dark rims, repeated muscle patches, horizontal shading bands |
| Cloth | Large panels, hem, overlap shadow, a few folds explaining tension | Parallel pinstripes of folds or one highlight per row |
| Metal | Clear silhouette and a small bright plane or edge | Speckled reflections and an extra ramp for every plate |
| Hair | One readable mass, a shadow mass, sparse contour breaks | Individual strands and noise over the scalp |

Use the enemies' upper-facing light treatment, darker far limbs and selected dark overlaps. Keep broad surfaces quiet. No dithering, soft alpha, filtered edges, gradients, or a continuous bright rim. A detail visible only in the enlarged review needs a clear purpose at native size.

## Layer ownership and hidden anatomy

A base is modular only when removing a part exposes usable art underneath it. Naming the pieces of a flattened image does not supply hidden pixels.

Build complete anatomical masses first, with overlap at shoulder, hip, neck, elbow and wrist connections appropriate to the supported pose. Retain the torso behind the near arm, scalp behind hair, and limbs under clothes. A flattened source split by selection needs its covered regions reconstructed before it can be called a reusable base.

Keep permanent body shading on body layers. A garment's cast shadow belongs to a removable garment component, and a held weapon's contact shadow belongs to its equipment/grip state. Removing a sleeve, belt, hair mass, or shield must not leave its outline or shadow burned into the body.

Separate far and near parts where depth requires it. Each garment may need several layers distributed through the stack. A coat can have rear tails behind the legs, a torso panel over the body, and sleeves over their corresponding arms. One top-level clothes group cannot interleave with limbs.

This is an example back-to-front stack for a side/three-quarter standing pose. Reverse this list to read it as Aseprite's top-to-bottom timeline. Modify the order for the pose and record it in the recipe.

| Depth | Typical contents |
|---|---|
| Rear | Cape back, hair back, rear weapon segment |
| Far arm | Far upper arm/forearm/hand, far sleeve or bracer, far grip components |
| Far leg | Far leg, trouser leg and boot |
| Body | Torso/pelvis, underwear, torso shirt/armor, belt, garment shadow components |
| Near leg | Near leg, trouser leg and boot; front skirt/coat panel where required |
| Head | Head/neck, face, hair front, headwear |
| Near arm | Near upper arm/forearm/hand, near sleeve or bracer |
| Front gear | Weapon/shield front segments, replacement grip/straps in their required order |

Split a limb at a joint only when the animation or equipment needs independent movement there. Avoid a layer for every tiny shading patch. Use stable ASCII names such as `body/arm_near`, `shirt/torso`, `shirt/sleeve_near`, and `sword/grip_near`. Repeated display names require distinct full paths or IDs.

Use transparent image layers, Normal blending, and full layer/cel opacity for exported art. Keep construction guides, swatches, backgrounds and ground shadows outside the export recipe. Lock approved base layers during wardrobe work. Aseprite documents [layer locking, visibility and groups](https://www.aseprite.org/docs/layers/); those controls help editing but do not prove layer independence.

## Garment and weapon contract

Every interchangeable part must record its body family and revision, canvas, origin, pose/facing, anchor points, palette roles, layer order, and supported frames. A 128 x 96 outfit from the pack is not compatible with a newly drawn 64 x 80 body because both depict a human.

Keep exported layers on the same full canvas. If a pipeline trims cels, retain their exact offsets and test reassembly. Refit a garment when the body silhouette changes, even if the canvas remains unchanged. Distinct body builds need explicit fits; do not stretch one outfit across them and claim compatibility.

For a held weapon, record the grip pivot and handle direction for each pose. The fingers cover the handle, the handle passes through the fist, and the guard/blade stay outside it. Use a replacement hand when the grip changes; the open hand and gripping hand are mutually exclusive. A shield has a forearm attachment and its own front/back occlusion. Check both hands for two-handed equipment.

Use an explicit recipe to select mutually exclusive clothing and hand variants. Turning an item off must also remove its rear segment, cast shadow, and grip override and restore the correct base hand. The recipe must toggle every component, even when those layers occupy different groups.

## Prove the base can be reused

Before extending a new base into a wardrobe or animation set, make a small fitting test with a shirt, trousers, boots, and one held item. They can be plain test pieces. Save the bare base and the dressed composite, then inspect:

1. All clothing, hair and gear hidden. The body remains complete and unchanged.
2. Near arm hidden, then far arm hidden. Shoulder and torso surfaces remain usable; no hand-shaped hole or old contact shadow is exposed.
3. Each new garment alone, and the composite with that garment removed. It contains only its owned pixels and all its removable shadows disappear.
4. Weapon equipped, weapon removed, and the alternate hand state. Grip registration and restored anatomy remain correct.
5. The composite with a different shirt color and a different skin color. Each substitution affects only its material.
6. One raised or bent arm pose exposing the covered shoulder/armpit. Inspect the sleeve, wrist and rear surfaces. If only the standing pose works, label the base as standing-only.

Do not fill every transparent enclosed area automatically. Gaps between an arm and torso or between bent legs can be intentional. Tiny eyes and teeth can be legitimate isolated pixels. Audit reports are review targets; record intentional exceptions by frame, layer and coordinates. Unexplained floating pixels and pinholes still fail.

## Animation registration

Approve the static construction and fitting test before expanding the clips. Store attachment positions per frame, including shoulder, wrist/grip, head and ground contact. A translation can follow breathing; a bent elbow or rotated grip requires a corresponding pose and fitted pixels.

Retain the base pose as a reference and keep nonmoving support feet registered during idle. For attacks and walking, inspect each newly exposed body surface and each equipment intersection. Clothing and weapons need the same frame timing and supported poses as the body. A missing equipment cel must have an intentional meaning; it cannot silently drop the weapon for one frame.

Aseprite [linked cels](https://www.aseprite.org/docs/linked-cels/) share edits. Link deliberately unchanged poses; unlink before a pose-specific redraw. Recheck every linked frame after changing a shared cel. Reopen the saved master and render the final export recipe, since a correct-looking working canvas can have the wrong saved visibility state.

## Acceptance and delivery

Keep technical validation and visual acceptance separate. Palette and alpha checks cannot judge whether a human looks convincing.

| Gate | Evidence required before advancing |
|---|---|
| Construction | Native-size silhouette and two-value body beside rat/goblin; coherent joints and intended age/build |
| Style | Same-scale native and 4x comparison; broad planes, restrained details, matching contrast and perspective |
| Modularity | The removal, grip and recolor views above; unchanged base-layer pixel/position diffs |
| Technical | Explicit palette on every deliverable cel, including hidden variants; binary alpha; no unintended opacity/blend changes, clipping or stray pixels |
| Animation | Every required frame and loop at game speed; gear registration, exposed surfaces, timing and impact frame |
| Runtime | Screenshot beside enemies with the intended camera, PixelSize, ground anchor and both facings |

For a palette-only change, compare both alpha and the mapping of old color regions to new colors. For a layer-only change, compare untouched layers including cel position, visibility, frame duration and pixels. A flattened image diff can miss damage hidden under clothing.

Deliver the layered `.aseprite`, native PNG exports, named palette, brief/landmarks, layer selection recipe, timing where applicable, and a review sheet. Record which file is authoritative. If code rebuilds the master, put accepted repairs into its data and prove a rebuild preserves them. If the edited master is authoritative, mark old builders as unsafe to run over it.

Give each review defect a location, visible problem, proposed repair, protected parts and fresh evidence after repair. Do not keep polishing a rejected construction. If two focused attempts leave the same anatomical defect, return to the joint blockout or change the construction reference.

State the passed gates and remaining defects. A static study can be complete for its requested scope without being an animation-ready base or an integrated game asset. No human base is newly approved by the rules alone; the first candidate must pass these comparisons and fitting tests.
