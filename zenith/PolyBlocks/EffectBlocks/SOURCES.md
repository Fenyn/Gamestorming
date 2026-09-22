# EffectBlocks v4 — Bukkbeek

Source: https://bukkbeek.itch.io/effectblocks

Copied from the user's purchased local pack:
`F:/UnityNVME/Art/GodotVFX/EffectBlocks v4/PolyBlocks/EffectBlocks/`.
Only eight used effect scenes and their dependency closure are included. Source
scenes, textures, materials, shaders and scripts are copied unchanged; the original
`res://PolyBlocks/EffectBlocks/` paths preserve binary material dependencies.

The author's terms allow commercial and non-commercial game use and prohibit
redistributing/reselling the asset pack itself, including modified versions.
These assets are incorporated into Eidolarch; do not distribute this directory as
a standalone asset collection. The author states graphical assets are handmade.

Integration: `scripts/ui/effect_blocks.gd` detaches demonstration scripts before
entering the tree, duplicates materials for instance-specific colors, and owns
one-shot timing/cleanup. Game controllers tune scale, density, and brightness.

- `fire/fire_light`: hall/arena braziers (flame, smoke, embers).
- `other/dust`: hall dust in selection, matchup, tournament, and arena.
- `other/portal_magic`: hall portal inside the stone arch.
- `other/fireflies`: restrained school-colored motes along arena edges.
- `impacts/impact_4`: combat sparks.
- `impacts/impact_1`: resolved-damage impact.
- `ground_effects/ground_effect_1`: inward protection feedback.
- `loot/power_up`: ascension.

Reduced motion stops and hides ambient particle systems and the animated portal.
Combat uses the existing static, fading feedback instead of pack bursts in that
mode. Geometry, card layouts, base font and public combat indicators are retained.
