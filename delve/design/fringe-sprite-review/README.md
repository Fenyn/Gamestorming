# Fringe sprite review

The five previously missing Fringe creatures now have their own sprite mappings, layered Aseprite masters, native PNGs, idle loops and attacks. All 15 creatures in the Fringe roster resolve to art, including the Elite Dire Wolf boss.

Open [the portable browser review](fringe-review.html) to play idles and attacks, pause poses, change the shared integer pixel scale, and inspect silhouettes. It embeds the PNGs and needs no server. [Native lineup](fringe-lineup-native.png), [4x lineup](fringe-lineup-4x.png), and [silhouettes](fringe-silhouettes-4x.png) align ground contacts without rescaling individual creatures.

Lineup order: existing rat, goblin, kobold, wolf, viper, spider, boar on the upper row; Giant Viper, Giant Monitor Lizard, Dire Wolf, Grizzly Bear, Giant Stag Beetle on the lower row. Goblin and kobold roles continue sharing species bases. Hero sprites have a different pixel-to-world scale, so these equal-pixel sheets compare enemy rendering style, not hero world size.

## Individual art reviews

Each creature received an author review, coordinating review, and an independent review by another creature's agent. These inspected native pixels, integer enlargement, silhouette, anatomical overlaps, shadow placement and every idle/attack pose. Revisions were judged visually; export checks were treated separately.

| Creature | Issues corrected during review | Final visual evidence |
|---|---|---|
| Giant Viper | Deepened the existing recessed neck plane; replaced the rectangular contact mouth with a diagonal cheek-hinged jaw and one pronounced upper fang. Continuous pale belly and rear-coil recess keep the body readable without scale texture. No blinking. | [Source review](../giant-viper-base/README.md), [contact sheet](../giant-viper-base/attack-frames-4x.png), [combat contact](combat/giant_viper_contact.png) |
| Giant Monitor Lizard | Rebuilt the vague wedge head as a blunt muzzle with a hinged jaw; removed unsupported shoulder/hip speckles; clarified underside and thigh planes, connected splayed palms and separated claw tips. | [Source review](../giant-monitor-lizard-base/README.md), [contact sheet](../giant-monitor-lizard-base/attack-frames-4x.png), [combat contact](combat/giant_monitor_lizard_contact.png) |
| Dire Wolf | User flagged shading and legs. Rebuilt shoulder/elbow/wrist and hip/stifle/hock chains, replaced outlined far limbs with receding planes, reduced bright paw caps, and connected the belly shadow to the ribcage. Reviewed hidden-leg support and tapered bite. | [Before/after and support](../dire-wolf-base/leg-shading-before-after-support-6x.png), [source review](../dire-wolf-base/README.md), [combat idle](combat/dire_wolf_idle.png) |
| Grizzly Bear | Enlarged the first draft to read as Large; flattened noisy coat shading; removed isolated shoulder highlights; rebuilt the swipe as anticipation, elbow extension, contact and follow-through. Completed exposed chest support and corrected the shoulder lighting jump between poses. | [Source review](../grizzly-bear-base/README.md), [contact sheet](../grizzly-bear-base/attack-frames-4x.png), [combat contact](combat/grizzly_bear_contact.png) |
| Giant Stag Beetle | User flagged misplaced shadows. Removed the floating shell stripe, then corrected an overly flat revision with a curved shell side plane, separate pronotum/head volumes and narrow contact shadows. Rebuilt leg side planes and open toothed mandibles. | [Source review](../giant-stag-beetle-base/README.md), [contact sheet](../giant-stag-beetle-base/attack-frames-4x.png), [combat idle](combat/giant_stag_beetle_idle.png) |

Final independent reviews found no remaining concrete shape or shading defect requiring another pass. This records the review judgment, not a claim that technical tests establish art quality. Existing species were controls for these reviews; their art was not repainted.

## Scale, sources and rebuild

Monster Core classifies Giant Viper and Giant Monitor Lizard as Medium; the other three are Large. All five use four pixels of bottom padding. After in-world footprint review, the monitor uses 0.018 world units per pixel with ground anchor X=80.5, and the beetle uses 0.025 with X=42.5. The other three retain 0.02 and canvas-centered anchors. The monitor's long canvas accommodates its tail; its feet remain centered on a Medium 1x1 footprint. Large creatures use centered 2x2 footprints and matching ground disks. `native-metrics.json` records canvas, visible bounds and palette counts.

Construction references used the built-in imagegen tool, followed by Aseprite reconstruction and animation. Exact prompts and provenance are preserved in each species directory. The layered base, idle and attack masters are the editable deliverables; no generated bitmap is referenced outside the workspace.

Rebuild a species with its `tools/build_<creature>.lua` script in Aseprite. These scripts own the pixels and overwrite their generated masters, so preserve manual edits or encode them in the script first. Then run:

```text
python tools/export_enemy_bases.py
python tools/export_enemy_attacks.py
python tools/build_fringe_review.py
```

Run `tools/review_fringe_sprites.lua` in Aseprite to refresh the native comparison sheets. Export source registrations live in `tools/enemy_sprite_sources.py`. Exporters read UTF-8 resources explicitly to avoid Windows BOM corruption.

## Integration evidence

- `enemy_sprite_spike`: 121 checks passed, including all Fringe mappings, Elite/Weak variants, playback, planted idles, fixed canvas, binary alpha and exact attack recovery.
- `fringe_sprite_shot_spike`: 32 checks passed. Group attacks, effect creation/recovery, and individual idle/contact images are in `combat/`. Inspected all five in combat for readable shape, world scale and ground placement.
- Saved Aseprite masters were reopened and compared against all exported poses by each builder. Runtime PNGs match the source frames.
- SHA-256 comparison confirmed all 96 existing enemy PNGs unchanged by the shared exports.
- Full rebuild completed with zero errors and no Delve warnings; it reported 28 existing Pf2e.Core warnings. The subsequent incremental build completed with zero warnings and errors.
- The standard combat screenshot baseline is captured before and after. A concurrent combat-log UI change briefly left the loaded assembly referring to the removed DiceToggle; rebuilding against the updated source resolved that mismatch.

The preview scene uses combat RNG seed 454 so Aldric acts first and waits while captures run. This avoids enemy movement during the art review and changes only the dev scene. `DELVE_SHOT_DIRECTORY` selects a writable screenshot folder.

The sandboxed Godot runs still report the existing certificate-store warning and skip the unrelated malformed `raja-rakshasa.json` pack entry. Neither prevents these sprite checks. Authored locomotion clips are outside this pass; these units keep the existing idle-during-movement behavior.

## Footprint correction

The latest individual in-world captures are in `footprint-combat/`: monitor and beetle anchors follow planted feet instead of canvas midpoints, and HP bars follow visible bodies instead of transparent headroom. Spawn, movement and team disks now follow the engine creature footprint. Deployment checks every footprint tile. The equal-pixel browser lineup remains an art-style comparison; runtime sizing is recorded above.

Validation after the footprint correction: build passed with zero warnings/errors; creature footprint 51 checks, deployment 12, target selection 27, enemy sprites 121, player turn 23, encounter reset 19, terrain spatial 57. Rendered five-creature review passed 32 checks (`footprint-combat/`); all-species preview passed 22 (`footprint-roster/`). Reviewed monitor idle/contact, beetle idle, dire wolf idle and full-roster placement. Creature targeting now highlights and accepts any occupied tile for strikes, targeted spells and skills.

## Grounded visual prototype (supersedes the floating disk)

See [the grounded prototype](grounded-prototype/README.md). Lowest supporting tiles now place the drawn body, while per-tile outlines and faint fill show the complete occupied footprint across elevation changes. The older `footprint-combat/` and `footprint-roster/` images above retain the previous highest-center placement for comparison.
