# Giant Monitor Lizard provenance

Tool: built-in `image_gen.imagegen`, using `design/boar-base/reference-lineup-4x.png` as rendering reference. Native reconstruction and animation: Aseprite `tools/build_giant_monitor_lizard.lua`.

Exact prompt:

> Use case: stylized-concept. Create ONE Giant Monitor Lizard construction reference for Delve. Supplied creature lineup is only rendering style and uniform pixel-scale reference. New animal anatomy: powerful low horizontal ribcage, long thick tapering tail extending to the LEFT, long muscular neck and alert wedge head facing RIGHT, four splayed legs with readable elbow/knee bends and grounded clawed feet. Coherent side/three-quarter camera across entire animal, not a top-down reptile. Broad olive-gray back, pale muted cream throat and jaw, darker far legs. About 96 by 36 native pixels, larger/longer than the ordinary wolf, with at least half of the total length belonging to its tail. Keep strong silhouette and flat broad color planes, one main shadow and sparse deep overlap accents, two short upper contour highlight patches, tiny amber eye. No spots, scale texture, stripes, dithering, gradients, continuous outlines, or repeated highlights. Closed mouth resting stance, no tongue, gear, other animals or text. Isolated full body centered with generous padding on genuinely transparent background. This is a construction reference; final rendering will be reconstructed on a native Aseprite grid.

Construction brief and review:

- Use the rat's limited broad planes and crisp stepped contours, wolf's near/far limb separation, and the suite's upper-left light. Keep reptile construction distinct: long tapered tail, bent sprawling limbs, no mammalian ears or fur, pale throat.
- The generated reference had soft glow outside its silhouette and many similar olive shades. Native sampling kept alpha above 200 only, collapsed colors to seven deliberate opaque swatches, and discarded all background glow.
- The first native sample lost the eye and short useful highlight; authored one amber eye, a dark nose, and a short upper-back accent. Removed an unsupported isolated neck shadow chip.
- Near hind knee turns forward then bends back to the broad clawed foot. Near front elbow turns back before the forearm drops to the planted foot. Far legs remain darker and partly hidden. Reviewed native silhouette and all attack frames.
- The bite keeps the upper muzzle stationary relative to the neck and rotates a separately layered lower jaw from the cheek. The dark cavity tapers into the hinge, sparse teeth remain in anticipation and contact, and recovery restores exact base pixels.

The rebuild script is the source of truth; preserve any manual edits before rerunning it. Combat integration is checked separately by the coordinating agent.
