# Mana Seed character identities

The current Mana Seed sprites remain the baseline and remain active in Delve. The rejected tall-character experiments and their builders have been removed. These files recover the existing sprites as editable layers; they do not replace gameplay assets.

## Current editable assets

Each character folder contains `p1.aseprite`, `p2.aseprite`, `p2_mine.aseprite`, and `p2_wood.aseprite`, plus native layer PNGs. Each master is a complete 512 × 512 page with the existing 64 × 64 cells. All four facings and animation poses are preserved.

| Character | Game folder | Body | Outfit | Hair / hat |
|---|---|---|---|---|
| Aldric | veteran | humn_v04 | pfpn_v02 — farmer clothes | dap1_v11 — brown dapper cut |
| Elara | rogue | humn_v02 | fstr_v03 — forester tunic | pon1_v07 — violet ponytail |
| Tharr | cleric | humn_v06 | bksm_v03 — smith apron | flat_v00 — grey flat-top |
| Fenwick | wizard | humn_v03 | alch_v04 — alchemist coat | pnty_v01 — blue pointed hat; no hair layer |

The current figures all use the same human-family Mana Seed body geometry. Elf, dwarf and halfling ancestry are character identities, not yet distinct body constructions in these sheets.

A separate [ancestry proportion study](ancestry-study/README.md) now gives Elara, Tharr and Fenwick distinct body shapes across four standing facings, with clothing registered to the changes. It leaves these recovered baseline sheets and runtime assets intact.

The subsequent [monster-style shading pass](monster-style/README.md) preserves those proportions and simplifies the material colors and interior highlights toward the rat/goblin rendering style.

## Proposed identity layers

Start with the existing silhouettes and familiar faces. Add one defining feature per character, using the pack's registered layers wherever possible. These are proposals, not changes already applied to the masters.

| Character | Preserve | First identity change | Later equipment / ancestry work |
|---|---|---|---|
| Aldric — practical farmhand-soldier | Brown crop, rolled sleeves, work trousers, sturdy boots | Muted red neck cloth or short mantle; keep the workwear readable | Mail shirt using the existing outfit silhouette; longsword and steel shield on compatible combat pages |
| Elara — composed elven merchant-rogue | Violet ponytail, fitted tunic, clear waist, light boots | Plum clothing accent and one small belt pouch | A tiny ear treatment under hair; fitted leather outfit; rapier and shortsword with authored grips |
| Tharr — dwarven stonemason-cleric | Grey hair, smith apron, solid workwear | Compact grey beard as a face layer; teal shoulder cloth | Breastplate replacing the apron chest; scimitar and shield for Delve's current build. Hammer is an alternate older-profile option |
| Fenwick — halfling cook-wizard | Blue pointed hat, alchemist coat, visible face | Shift the coat's main fabric toward subdued blue while retaining cream trim | One small food/medicine pouch; staff on a matching action page. Keep the hat unless deliberately redesigning his established silhouette |

Use muted red, plum, teal and blue as limited accents, consistent with the UI identities. Do not recolor every material. Preserve separate skin, hair, cloth, leather and metal ramps. Do not stretch or squash these bodies to imply ancestry; a later shorter body needs clothing and animation authored to that anatomy.

## Layer order and registration

Use the native order: `0bot` rear garment → `0bas` body → `1out` outfit → `2clo` mantle → `3fac` face detail → `4har` hair → `5hat` headwear → `6tla` primary tool → `7tlb` secondary tool.

An outfit is one registered sheet across poses, not a sticker pasted onto the standing frame. When an item passes behind an arm, use the pack's intended split/occlusion for that pose. A visible weapon must have a closed grip and a continuous hilt. Check south, north, east and west before expanding a change to the walk and action frames.

Current gameplay uses `p1` for standing/walking and `p2_wood` for the shared axe swing. Equipped swords, shield, scimitar and staff are not yet faithfully represented by that animation. The pack includes sword/shield combat pages, but selecting them and wiring their timing is separate work. Do not paint static weapons over the existing axe animation.

## Optional monster-style adjustment

[Comparison](comparison-6x.png): columns are Aldric, Elara, Tharr and Fenwick. Top two rows are the current south/east poses; bottom two are the subtle palette preview. [Layer breakdown](current-layers-6x.png): rows are body, outfit, hair/hat and current composite.

The preview changes color only: dark values move down four RGB levels, bright values up three, and saturation decreases by 2%. It preserves every silhouette, pixel cluster, facial mark, pose and registration point. The change is intentionally small. Files ending `-subtle-preview.png` are not used by the game.

Mana Seed already has strong selective edges. Preserve them. Start with value/palette alignment to the monsters; do not remove face pixels, soften outlines, merge material boundaries or redraw the base to chase the monsters' larger native canvas. Heroes and enemies currently use different pixel-to-world scales, so an equal-pixel comparison is not an in-game size comparison.

## Rebuild and verification

1. Run `python tools/prepare_manaseed_recipes.py` to resolve the local source pack.
2. Run Aseprite in batch with `tools/recover_manaseed_layers.lua`.

The builder compares all 16 reconstructed pages to the shipped runtime sheets, reopens every saved master, and compares visible pixels again. Runtime files are read-only inputs. Match the original baker's rule that only source alpha 255 contributes: Fenwick's hat contains a few partial-alpha pixels which the shipped bake excludes.

Source: `F:/UnityNVME/Art/Sprites/Mana Seed`. Exact paths are in `source-recipes.json`. Original Delve recipe: `G:/crocotile-mcp/examples/build_delve_hero_sheets.py`. The older Bulwark recipe does not describe Delve's current characters. This work uses Aseprite and existing source art; no image generation was used.
