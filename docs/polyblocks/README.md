# PolyBlocks packages

How-to notes for the Bukkbeek PolyBlocks packs downloaded to `F:\UnityNVME\Art\GodotVFX`.
Written 2026-09-22 from reading the package files, not from testing in the editor.

- [EffectBlocks](effectblocks.md): about 93 low-poly 3D particle effect scenes. No API, no addon.
  Zenith vendors the v4 subset at `zenith/PolyBlocks/EffectBlocks`. Covers scene shapes, playback,
  customising, the full catalog, and the v3 vs v4 diff.
- [NatureBlocks v1](natureblocks.md): low-poly terrain, rocks, trees and vegetation, plus 14 editor
  tools (Path3D generators and scatterers). Must live at `res://PolyBlocks`. Godot 4.5+, Forward+.
- [EffectBlocks PixelRenderer v2](pixelrenderer.md): standalone tool that renders one EffectBlocks
  scene to 31 loose pixel-art PNG frames. No sprite sheet packing. Bundles an older EffectBlocks build.

Shared facts:

- All three want Forward+ (or Mobile for NatureBlocks). Screen and depth texture hints break Compatibility.
- All three hardcode `res://PolyBlocks/...` paths.
- No licence file ships in any download. Check the itch.io page before shipping a build.
