# Goblin base

For future creature work, read the reusable [sprite generation guidelines](../sprite_generation_guidelines.md). They capture the construction, style matching, shading, and verification lessons from this iteration.

The latest palette pass deepens overlap shadows, brightens the short contour highlights, and strengthens warm face accents to approach the rat's contrast. The pose and shading shapes are unchanged. The previous palette is preserved in `revisions/pre-pop`. Goblin outfit exports have been refreshed against this base.

Current revision preserves the improved construction pose and uses flat color planes to match `rat_v1`. Short highlights follow the crown, ear tip, and shoulder contour. Body shadows taper around the ribcage, waist, elbows, thighs, knees, and calves instead of cutting across them as rectangular bands. Large skin regions remain flat, without texture or scattered interior highlights.

- `goblin-base.aseprite`: editable master, 56 x 64 RGBA, one right-facing pose, ten layers.
- `goblin-base.png`: transparent native-resolution export.
- `goblin-base-8x.png`: nearest-neighbor preview.
- `rat-and-silhouette-review.png`: rat, goblin, and goblin silhouette at the same pixel scale.
- `proportions-comparison.png`: previous edge pass on the left, current body-shadow refinement on the right.
- `construction-reference.png`: generated construction reference, not the final game asset.
- `art-direction.md`: research sources and application notes.
- `generation-prompt.txt`: exact prompt used with the built-in image generation tool.

The visible goblin is 35 x 52 pixels on a 56 x 64 canvas. This revision increased the working height to preserve the reference pose's joints and hands. The rat reference's visible body is shorter; the review aligns their feet without rescaling either character.

The ten layers separate the far leg, far arm, near leg, torso and pelvis, removable loincloth, head and neck, near ear, face, near arm and hand, and an empty equipment overlay. Skin continues beneath the cloth. Palette variants and equipment are not included.

The pose was developed with the built-in image generation tool. Aseprite samples its construction onto a fixed grid, replaces the shading with authored flat color regions, separates the layers, and exports the final sprite. Prior drafts are preserved in `revisions/`.

Rebuild with Aseprite using `--batch --script-param root=G:/Godot/Gamestorming/delve --script tools/draw_goblin_base.lua`. Rebuilding overwrites the master and exports; preserve manual edits first. The script reopens the saved master and verifies its render matches the PNG pixel for pixel.

This single base pose is now registered for Goblin Warrior, Commando, and War Chanter. Runtime copies live in `assets/sprites/enemies/goblin_base`; `sprite.tres` defines a single-frame idle and a six-pixel foot margin. Run `python tools/export_enemy_bases.py` after revising the source PNG. Outfits remain separate design assets.

Idle animation: `goblin-idle.aseprite` retains the anatomical layers. See [motion preview](idle-preview.gif) and [frame sheet](idle-frames-4x.png). Rebuild with Aseprite `--batch --script tools/build_enemy_idles.lua`, then run `python tools/export_enemy_bases.py`. The approved single-pose master is preserved.

Attack: [goblin-attack.aseprite](goblin-attack.aseprite), [motion preview](attack-preview.gif), and [frame sheet](attack-frames-4x.png). Six frames, 0.58 seconds; contact is frame 3 (0.18 seconds). Rebuild with `tools/build_enemy_attacks.lua` in Aseprite, then run `python tools/export_enemy_attacks.py`. GIF previews include an extra rest pause for review.
