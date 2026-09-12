# Viper

Native 64 × 48 sprite, facing right, with 44 × 30 visible resting bounds and a four-pixel ground margin. Flat olive planes, pale belly, dark coil overlaps, short crown highlights, and an amber eye match the rat/goblin/kobold/wolf lineup.

- `viper-base.aseprite`: editable tail, ground coil, raised neck, head/jaw, and empty equipment layers.
- `viper-idle.aseprite`: five frames, two-second loop, subtle neck lift. No blink.
- `viper-attack.aseprite`: six frames, 0.58-second strike, contact at 0.18 seconds. Anticipation, extended bite with teeth, and recovery to the exact base.
- `reference-lineup-4x.png`, `idle-preview.gif`, and `attack-preview.gif`: review artifacts.
- `provenance.md`: built-in imagegen construction prompt. All native reconstruction and animation is done in Aseprite.

Rebuild with Aseprite batch script `tools/build_viper.lua`, then run `python tools/export_enemy_bases.py` and `python tools/export_enemy_attacks.py`. Rebuilding overwrites generated masters; preserve manual changes first.

The regular Viper uses `assets/sprites/enemies/viper_base/sprite.tres`. Its resource selects idle, attack, contact timing, placement, and `scenes/fx/attack_viper_bite.tscn`. The bite marks sit ahead of the head. Giant Viper remains a separate missing-art creature. Open `scenes/dev/enemy_sprite_preview.tscn` to compare all five species in game.

Validation: Aseprite reopened both animation masters and compared every exported frame; all poses form one connected silhouette, keep opaque/transparent alpha and the base palette, and retain the four-pixel ground margin. First/last idle and final attack exactly match the base. All eleven runtime animation copies match the source PNGs. Delve builds with zero errors and zero Delve warnings (28 existing Pf2e.Core warnings); animation spike passes 56 checks and rendered combat spike passes 19. `in-game-idle.png` and `in-game-attack.png` record the five-species preview.
