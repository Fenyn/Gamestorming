# Giant Monitor Lizard

Medium creature. Native canvas 120 x 56, visible bounds 104 x 30, seven opaque colors, right-facing, four-pixel foot margin and .018 world units per pixel. The long tapering tail accounts for roughly half its length; the low torso, splayed bent limbs, blunt snout and pale throat distinguish it from the mammals.

- `giant-monitor-lizard-base.aseprite` and PNG: layered resting base.
- `giant-monitor-lizard-idle.aseprite`: five-frame, two-second breathing/blink loop.
- `giant-monitor-lizard-attack.aseprite`: six-frame bite, .58 seconds, impact index 2 at .18 seconds, exact base recovery.
- `reference-lineup-4x.png`, `silhouette-8x.png`: equal-scale suite comparison and silhouette review.
- Native frames, four-times frame sheets and GIF previews retain authored timing.

The nine master layers separate tail, far legs, ribcage, near legs, neck/upper head, lower jaw and empty equipment slot. Rebuild using Aseprite `--batch --script tools/build_giant_monitor_lizard.lua`; preserve manual master edits first. Shared exporters refresh `assets/sprites/enemies/giant_monitor_lizard_base`. `sprite.tres` uses the existing bite accent and explicit clip timings.

Validation: saved masters reopened and checked pixel-for-pixel against exported frames, nine layers and expected frame counts. Binary alpha, fixed 120 x 56 canvas, bottom bound 52 in all eleven animation frames, exact base recovery, and identical runtime PNG copies verified. Reviewed native-size shape, enlargement, silhouette, all bite poses and reference lineup. Combat integration is checked separately.

Focused revisions: extended the vague initial wedge into a blunt monitor snout; removed unsupported hip/shoulder shadow speckles; repainted ribcage underside and near hind thigh as deliberate tapering planes; joined toe accents to broad palms while retaining separated splayed tips. See `provenance.md` for exact prompt and process.

Runtime placement review: `sprite.tres` uses PixelSize=.018 and GroundAnchorX=80.5 pixels, with four pixels of bottom padding. This centers the planted support under the token in both facings. Native PNGs and layered masters are unchanged. See `../fringe-sprite-review/footprint-combat/` for the in-world captures.
