# Boar

72 × 48 native canvas, four-pixel ground margin, facing right. Nine Aseprite layers separate tail, far legs, ribcage/shoulder, near legs, head/ears, tusks, and an empty equipment layer.

- `boar-base.aseprite`: editable resting base and transparent PNG.
- `boar-idle.aseprite`: five frames, 2.125-second breathing/blink loop.
- `boar-attack.aseprite`: six frames, 0.58-second dip and upward tusk thrust. Contact at 0.18 seconds, then exact base recovery.
- `reference-lineup-4x.png`: same-scale comparison with all current creatures.
- `idle-preview.gif` and `attack-preview.gif`: timing previews.

The built-in imagegen construction prompt is recorded in `provenance.md`. All native reconstruction, palette reduction, and animation use Aseprite `tools/build_boar.lua`. Preserve manual changes before rebuilding. Run `tools/export_enemy_bases.py` and `tools/export_enemy_attacks.py` after a rebuild.

Boar maps to `assets/sprites/enemies/boar_base/sprite.tres`. That resource selects its clips, contact frame, placement, and the tusk accent scene. The seven-species `enemy_sprite_preview.tscn` includes it.

Validation: native masters reopened and compared against every PNG; fixed ground margin, exact recovery and all runtime copies verified. Build passes; enemy animation spike passes 66 checks, rendered combat spike passes 19. The group combat capture is `in-game-attack.png`; overlapping units make the native lineup the clearer art comparison.
