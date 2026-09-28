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

`res://assets/ui/ui_theme.tres` is the project theme (Project Settings > GUI > Theme > Custom) and the only theme. Its default font is Pixeloid Sans at 18 px. Bold variations use Pixeloid Sans Bold; `TitleLabel`, `CampTitle` and `BannerLabel` use Alagard. The size ladder is in `design/ui_guidelines.md` §4.2.

Pixeloid and Alagard import with grayscale antialiasing and with hinting and subpixel positioning off. They render crisp at whole-multiple sizes at 1080p and stay legible when the window scales down. Scenes carry no font or font-size overrides; change a font on its theme variation.

Knightwood, Compass 9 and Pixel Bastarda are on disk but unused. Credits are in `CREDITS.md`.
