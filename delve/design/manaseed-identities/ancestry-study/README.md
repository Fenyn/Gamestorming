# Ancestry proportion study

[Dressed comparison](lineup-5x.png) · [Bodies without clothing](bodies-5x.png)

Columns: Aldric (human), Elara (elf), Tharr (dwarf), Fenwick (halfling). Rows: south, north, east, west. All use the same pixel scale and ground contact.

- **Human:** unchanged control.
- **Elf:** two pixels taller through torso and legs, with a slightly narrower waist. Existing face and violet ponytail retained. The extra boot row from the first pass has been removed.
- **Dwarf:** three pixels shorter through torso/lower body, with broader shoulders and chest. The revised pass restores a leg row and reduces the excessive breadth of the first pass.
- **Halfling:** six pixels shorter overall. Head and hat are narrower and lose two rows; torso and legs lose four rows. This restores body length relative to the head instead of retaining a full-size head over an excessively compressed body. Clothing follows the same registration.

The Aseprite masters contain four named standing facings and separate body, outfit and hair/hat layers. This is a proportion study built by selecting/repeating native pixel rows and adjusting breadth by anatomical region, followed by visual review. It is not a uniform resize. The same coordinate mapping applies to every layer, preserving clothing registration and hidden body pixels. Colors remain exactly from the current Mana Seed sprites.

Verified: every saved master reopens to the exported pixels; all 16 poses retain hard transparency, original palette colors, and the original ground contact. Aldric matches the current stand frames exactly.

These are standing studies, not replacement runtime sheets. Walks, attacks and other action poses still need pose-specific adaptation before these proportions can enter the game. The current runtime sprites and recovered baseline masters remain unchanged.

Rebuild in Aseprite with `tools/build_manaseed_ancestries.lua`.
