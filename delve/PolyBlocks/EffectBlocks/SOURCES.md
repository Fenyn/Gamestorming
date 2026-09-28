# EffectBlocks v4 (Bukkbeek)

Source: https://bukkbeek.itch.io/effectblocks, copied from the user's purchased pack at
`F:/UnityNVME/Art/GodotVFX/EffectBlocks v4/PolyBlocks/EffectBlocks/` by
`tools/art/vendor_effectblocks.py`. Only the effects listed in that script and their dependencies are
included, unchanged, at the pack's own `res://PolyBlocks/EffectBlocks/` paths (binary materials
depend on them).

The author's terms allow commercial and non-commercial game use and forbid redistributing or
reselling the pack itself, modified or not. Do not ship this folder as a standalone collection.

Integration: `scripts/fx/EffectBurst.cs` strips demo scripts before the scene enters the tree and
owns one-shot timing and cleanup. `scripts/dungeon/ExplorationFx.cs` decides when each effect plays.
