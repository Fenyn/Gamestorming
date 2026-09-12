# Wolf base

First unarmored wolf pose for Delve's level 1 Wolf, with a future Dire Wolf variant in mind. A right-facing quadruped with four grounded paws, a low tail, a broad gray body plane, dark underside overlaps, and short upper contour highlights. Fur is suggested by the silhouette rather than surface texture.

- [Aseprite master](wolf-base.aseprite): 72 x 56 RGBA, one pose, eight layers.
- [Native PNG](wolf-base.png) and [8x preview](wolf-base-8x.png).
- [Reference lineup](reference-lineup-4x.png): rat, approved goblin, kobold, wolf, and wolf silhouette. Feet align at the same pixel scale.

Layers separate the tail, far hind leg, far foreleg, torso, near hind leg, near foreleg, neck/head, and an empty equipment layer. They separate visible parts for later editing; unseen anatomy has not been constructed for a walk cycle.

The built-in image generation tool supplied [construction-reference.png](construction-reference.png), using the rat and approved creature lineup as visual references. See the [exact prompt](generation-prompt.txt). Aseprite samples onto a fixed grid, reduces the colors, removes stray fur marks, simplifies leg shadows, and restores a crisp eye accent.

The [build script](../../tools/build_wolf_base.lua) runs in Aseprite with `--batch --script tools/build_wolf_base.lua`, optionally preceded by `--script-param root=<absolute-delve-path>`. Rebuilding overwrites generated outputs, so preserve manual edits first. The script reopens the saved master and checks its pixels against the PNG.

Follow the [sprite generation guidelines](../sprite_generation_guidelines.md). This base is registered for Wolf, using a five-frame breathing and blink idle in `assets/sprites/enemies/wolf_base/sprite.tres` and a four-pixel foot margin. Run `python tools/export_enemy_bases.py` after revising the source PNG. The Dire Wolf still needs its own heavier silhouette and size treatment.

Idle animation: `wolf-idle.aseprite` retains the anatomical layers. See [motion preview](idle-preview.gif) and [frame sheet](idle-frames-4x.png). Rebuild with Aseprite `--batch --script tools/build_enemy_idles.lua`, then run `python tools/export_enemy_bases.py`. The approved single-pose master is preserved.

Attack: [wolf-attack.aseprite](wolf-attack.aseprite), [motion preview](attack-preview.gif), and [frame sheet](attack-frames-4x.png). Six frames, 0.58 seconds; contact is frame 3 (0.18 seconds). Rebuild with `tools/build_enemy_attacks.lua` in Aseprite, then run `python tools/export_enemy_attacks.py`. GIF previews include an extra rest pause for review.
