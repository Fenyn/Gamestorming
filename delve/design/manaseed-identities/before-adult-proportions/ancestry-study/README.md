# Ancestry proportion study

[Dressed comparison](lineup-5x.png) · [Bodies without clothing](bodies-5x.png)

Columns: Aldric (human), Elara (elf), Tharr (dwarf), Fenwick (halfling). Rows: south, north, east, west. All use the same pixel scale and ground contact.

- **Human:** unchanged control.
- **Elf:** three pixels taller through torso and legs, with a slightly narrower waist. Existing face and violet ponytail retained.
- **Dwarf:** four pixels shorter through torso/lower body; broader shoulders, chest and arms, with a modestly broader head and sturdy feet. The apron follows the new torso.
- **Halfling:** eight pixels shorter through torso and limbs, retaining the readable head and hat. Slightly narrower body with broader feet. The coat follows the shorter torso and legs.

The Aseprite masters contain four named standing facings and separate body, outfit and hair/hat layers. This is a proportion study built by selecting/repeating native pixel rows and adjusting breadth by anatomical region, followed by visual review. It is not a uniform resize. The same coordinate mapping applies to every layer, preserving clothing registration and hidden body pixels. Colors remain exactly from the current Mana Seed sprites.

Verified: every saved master reopens to the exported pixels; all 16 poses retain hard transparency, original palette colors, and the original ground contact. Aldric matches the current stand frames exactly.

These are standing studies, not replacement runtime sheets. Walks, attacks and other action poses still need pose-specific adaptation before these proportions can enter the game. The current runtime sprites and recovered baseline masters remain unchanged.

Rebuild in Aseprite with `tools/build_manaseed_ancestries.lua`.
