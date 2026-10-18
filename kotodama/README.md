# Kotodama (言霊)

A kanji sanctuary for learning Japanese. Each kanji is a small spirit you invite into the yard by writing its form on a talisman. Words are flowers you plant and water by naming them. The yard grows from a clearing at a torii gate into a shrine village as you learn. Spaced repetition decides who is hungry each day. Nothing dies.

Design: [`../designs/kotodama.md`](../designs/kotodama.md).

## Run

Godot 4.6, GDScript. Open `project.godot` and press F5.

The yard tiles come from the Mana Seed packs, which are not in the repo. Copy them into `assets/packs/` (see `CLAUDE.md`). The game runs without them on flat colours.

## Play

- Lights at the torii are new spirits waiting. Click one to invite it: pick its parts, watch the strokes, write it on the ofuda, click in its zone to place it, then type the readings of its first words.
- A bubble over a spirit or flower means it is hungry. Click it and type the reading in romaji, pick its meaning, or draw it.
- Pan with the right or middle mouse button or the arrow keys. Zoom with the wheel. Rest shows the day's tally.
- Save file: `user://kotodama.json` (`%APPDATA%\Godot\app_userdata\Kotodama\`).

## Tests

```
"G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe" --headless --path . -s tools/test_core.gd
"G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe" --headless --path . --quit-after 300 tools/test_scene.tscn
"G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe" --path . --quit-after 900 tools/shot_scene.tscn
```

The first two print `TEST RESULT: PASS`. The third opens a window and writes screenshots to `tools/shots/`.

## Build the data

```
python tools/build_data.py
```

Needs Python 3 with Pillow. Downloads OpenJLPT, KANJIDIC2, KRADFILE and KanjiVG into `tools/cache/`, then writes:

| Output | What |
|---|---|
| `data/kanji.json` | every JLPT kanji in teaching order: level, zone, readings, meanings, parts |
| `data/parts.json` | every component a lesson shows, with its display glyph and name |
| `data/words.json` | every JLPT word that contains kanji, in planting order |
| `data/zones.json` | zone names, tints, and the Kangxi radical to zone map |
| `data/strokes/<cp>.json` | stroke polylines from KanjiVG, 109×109 box |
| `assets/glyphs/<cp>.png` | 32 px ink glyph per kanji and part, thresholded Noto Sans JP |

Sources and licences are in `CREDITS.md`.
