# Monster-style shading pass

The latest proportion revision corrects Fenwick's oversized head/body ratio, gives Tharr more leg length and less breadth, and reduces Elara's boot elongation. [Proportion before/after](adult-proportions-before-after-5x.png): old south, revised south, old east, revised east. The previous masters are preserved in `../before-adult-proportions/`. Aldric is unchanged.

[Four-facing lineup](lineup-5x.png) · [Before / after](before-after-5x.png) · [Rat and goblin comparison](monster-comparison-4x.png)

Columns are Aldric, Elara, Tharr and Fenwick. The before/after board shows original south, revised south, original east, revised east. The monster comparison uses equal native pixel scale, not runtime world scale.

This pass preserves the approved ancestry proportions and every transparent silhouette pixel. It uses quieter material palettes, broad main-color regions, fewer interior highlight flecks, short upper-edge accents and dark structural shadows. Hair highlights are consolidated instead of retaining the original striped texture. Outfit highlights inside fabric are folded into the main color. Skin and facial marks retain their shading structure so these small faces remain readable.

Each character has a four-frame Aseprite master, named south/north/east/west, retaining separate body, outfit and hair/hat layers. Source proportions remain in `../ancestry-study/`; baseline Mana Seed sheets remain in the parent character folders. No runtime files were changed.

Verification: all 16 silhouettes match the approved ancestry poses; all four masters reopen to their exported PNGs. The exports retain binary transparency. Walking and action animations are still outside this standing-sprite study.

Rebuild in Aseprite with `tools/style_manaseed_ancestries.lua`. The script records the material palette changes and interior-highlight cleanup. No image generation was used.
