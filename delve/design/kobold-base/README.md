# Kobold base

Unarmed right-facing kobold, built for future Warrior and Scout outfit layers. Rust-colored skin, swept horns, clawed feet, and a curved tail distinguish it from the goblin. Color planes remain flat, with selective overlap shadows and short upper contour highlights.

The latest palette pass separates the deep shadows, main skin color, and upper highlights more clearly, with brighter eye and horn accents. It preserves the silhouette and existing shading shapes. The previous palette is preserved in `revisions/pre-pop`.

- [Editable master](kobold-base.aseprite): 64 x 64 RGBA, one pose, ten layers.
- [Native transparent PNG](kobold-base.png).
- [8x preview](kobold-base-8x.png).
- [Reference lineup](reference-lineup-5x.png): rat, approved goblin, kobold, and kobold silhouette, at identical pixel scale with feet aligned.
- [Underlying body check](body-without-loincloth.png): garment hidden to inspect the pelvis and leg separation.

Layers separate the tail, far leg, far arm, near leg, torso/pelvis, removable loincloth, head/neck, near arm/hand, horns, and empty equipment overlay. Skin continues under the garment at the hips; the hanging cloth is not baked into the body silhouette. Keep all layers on the full canvas for outfit registration.

The built-in image generation tool supplied [construction-reference.png](construction-reference.png), using the approved goblin and rat as style references. The exact prompt is saved in [generation-prompt.txt](generation-prompt.txt). Aseprite reconstructs that reference on a fixed grid, reduces the palette, removes texture, cleans selected color clusters, and assembles the layers. The source presentation is not the final sprite.

Rebuild with Aseprite `--batch --script tools/build_kobold_base.lua`, optionally supplying `--script-param root=<absolute-delve-path>`. The [build script](../../tools/build_kobold_base.lua) overwrites generated outputs, so preserve manual edits first. It reopens the saved master and checks the rendered pixels against the PNG.

Follow the [sprite generation guidelines](../sprite_generation_guidelines.md) for revisions. This unarmed base is registered for Kobold Warrior and Scout, using a five-frame breathing and blink idle in `assets/sprites/enemies/kobold_base/sprite.tres` and a six-pixel foot margin. Run `python tools/export_enemy_bases.py` after revising the source PNG.

Idle animation: `kobold-idle.aseprite` retains the anatomical layers. See [motion preview](idle-preview.gif) and [frame sheet](idle-frames-4x.png). Rebuild with Aseprite `--batch --script tools/build_enemy_idles.lua`, then run `python tools/export_enemy_bases.py`. The approved single-pose master is preserved.

Attack: [kobold-attack.aseprite](kobold-attack.aseprite), [motion preview](attack-preview.gif), and [frame sheet](attack-frames-4x.png). Six frames, 0.58 seconds; contact is frame 3 (0.18 seconds). Rebuild with `tools/build_enemy_attacks.lua` in Aseprite, then run `python tools/export_enemy_attacks.py`. GIF previews include an extra rest pause for review.
