# Fonts

Imported from `F:/UnityNVME/Art/Fonts`. Each face uses its TrueType version; duplicate OpenType and web versions are omitted. Supplied licenses and readmes are kept beside the fonts.

| Folder | Faces |
| --- | --- |
| alagard | Alagard |
| compass_9 | Compass 9 |
| knightwood | Knightwood |
| pixel_bastarda | Regular, Light |
| pixeloid | Sans, Sans Bold, Mono |

## Theme selection

Open `res://assets/ui/ui_theme.tres` in the Inspector and assign **Default Font**. Drag a `.ttf` from this folder into that field. **Default Font Size** controls the fallback size. The theme is already assigned under Project Settings > GUI > Theme > Custom and directly on the run-map scenes.

A control inherits the default unless its theme type or local overrides specify another font. All four run-map sidebar headings use **MapHeading**. Its **Fonts > Font** resource is named **Map sidebar headings**; change its **Base Font** to update Wardstone, Your party, Recovery, and the destination title together. This resource is separate from buttons, the ward value, and screen titles. Assigning a font directly to MapHeading's font slot also updates all four headings.

Other display text still uses the shared `fv_display` FontVariation. Changing that resource affects its consumers, but does not change the four sidebar headings. Font-size overrides remain independent.

Importing fonts does not select a replacement. The existing UI font choices are unchanged.
