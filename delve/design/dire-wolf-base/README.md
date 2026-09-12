# Dire Wolf

Right-facing Large canine, 96 x 64 native canvas, four-pixel foot margin, .02 world units per pixel. Its deeper shoulder, longer body, broader paws and thick ruff distinguish it from the regular Wolf at equal pixel scale. Eight opaque palette entries carry broad gray/taupe planes, deep cool overlaps, sparse contour accents and an amber eye.

The built-in image generation tool produced `construction-reference.png`; exact instructions are in `generation-prompt.txt`. The generated pose informed construction, but its blurred halo and numerous highlight bands were unsuitable for runtime art. `tools/build_dire_wolf.lua` reconstructs the animal as deliberately authored native pixel polygons in Aseprite. It does not resample or import the generated bitmap into the final asset.

Deliverables: `dire-wolf-base.aseprite`, `dire-wolf-base.png`, `dire-wolf-base-8x.png`, `reference-lineup-4x.png`, `silhouette-8x.png`, layered `dire-wolf-idle.aseprite` and `dire-wolf-attack.aseprite`, transparent `idle_N.png` / `attack_N.png`, timing manifests, integer-scale frame sheets and GIF previews. Runtime copies and the SpriteFrames definition are in `assets/sprites/enemies/dire_wolf_base`.

Ten native layers separate tail, both far legs, ribcage, both near legs, ruff/skull, hinged jaw, face accents and an empty equipment layer. Rear anatomical forms continue behind foreground legs; this is editable support for these idle/bite poses, not a completed walk cycle.

Idle has five poses over 2.25 seconds, a one-pixel upper body lift with planted paws and a .125-second blink. Attack has six poses over .58 seconds, zero-based contact frame 2 at .18 seconds. The jaw turns down from the cheek while the upper muzzle stays attached to the skull; sparse teeth remain visible at contact. Final attack pose and first idle pose restore the exact base pixels. Runtime uses the existing `attack_bite.tscn` effect (eight accents).

Review: compared native art and 4x lineup against the actual rat, approved goblin, wolf and boar with feet aligned and identical pixel scale. The first pass had a box-like open mouth; a focused second pass replaced the jaw warp with a tapered cavity and a connected diagonal lower jaw. Base silhouette and palette remained unchanged. Reviewed every idle and attack frame at integer scale, including the brief blink and exact recovery. The final shapes preserve broad coat areas without texture or a full outline.

Following the user's leg/shading feedback, the next pass articulated the near shoulder/elbow/wrist and hip/stifle/hock chains, replaced far-leg outline strips with receding flat planes, reduced the pale paw caps, and connected the belly shadow to the underside. Shadows now clip to their anatomical part rather than projecting stray shape fragments. `leg-shading-before-after-support-6x.png` shows the preceding version, revision, and near-leg-hidden support view. The larger body/head direction is retained; revised legs and shading propagate into every idle and attack frame.

Build verification reopens all three masters and compares every rendered frame pixel with its PNG, checks layer and frame counts, binary alpha and exact base/recovery. A separate check verifies planted foot rows and runtime/export equality. Game placement, VFX reach, and combat playback are integration checks performed separately.

Rebuild using Aseprite `--batch --script tools/build_dire_wolf.lua`, optionally `--script-param root=<absolute-delve-path>`. The script is the source of truth and overwrites its exports; encode edits there or preserve manual master changes before rebuilding. It writes runtime images but preserves the authored runtime resource.
