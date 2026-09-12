# Grizzly Bear

96 x 64 native canvas, 76 x 46 visible bounds, seven opaque colors, right-facing, four-pixel foot margin, .02 world units per pixel. The hump, round ears, short muzzle and broad paws distinguish the bear from wolf and boar.

- `grizzly-bear-base.aseprite` and PNG: layered resting pose.
- `grizzly-bear-idle.aseprite`: five frames, 2.25 seconds with a short blink and one-pixel breath.
- `grizzly-bear-attack.aseprite`: six frames, 0.58 seconds, impact on frame index 2 after 0.18 seconds. Folded paw anticipation, forward claw swipe, downward follow-through and exact base recovery.
- `reference-lineup-4x.png`: native-scale feet-aligned comparison.
- `foreleg-hidden-8x.png`: completed chest behind the removable striking foreleg.
- `silhouette-8x.png`: silhouette inspection.
- Frame sheets and GIFs show every pose and authored timing.

Rebuild with Aseprite `--batch --script tools/build_grizzly_bear.lua`. The script replaces its generated masters; preserve manual edits first. Shared base/attack exporters copy PNGs and timing into `assets/sprites/enemies/grizzly_bear_base`. The resource uses the existing swipe accent.

Validation: every saved master reopened and compared to its PNG frames by the builder; nine layers and expected frame counts checked. All frames have binary alpha, canvas size 96 x 64, and bottom bound 60. Idle frame one and final attack recovery exactly match the base. Runtime frame copies checked byte-for-byte. Native size, integer enlargement, exposed chest, and every attack pose visually reviewed. Combat integration is reviewed separately.

See `provenance.md` for the exact built-in generation prompt and focused revision notes.
