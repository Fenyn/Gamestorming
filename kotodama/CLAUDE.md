# Kotodama — kanji sanctuary

Godot 4.6, GDScript only. Design: `../designs/kotodama.md`. Read it before changing the loop.

## Rules of the game

- Every click the player makes to progress is a retrieval: a reading typed, a meaning picked, a form drawn, parts picked. No mechanic may let the player progress without knowing the kanji.
- No timers, streaks, failure counts or currency. A miss shows the answer. Stage drops are silent.
- Nothing dies. Overdue items wait.

## Data

- `tools/build_data.py` builds `data/` and `assets/glyphs/` from OpenJLPT, KANJIDIC2, KRADFILE and KanjiVG. Never edit those outputs by hand. Change the script and rebuild.
- Readings are stored as hiragana. Compare kana to kana, never romaji to romaji.
- `data/strokes/<cp>.json` polylines are in KanjiVG's 109×109 box.

## GDScript

- Explicit types everywhere. Never `:=` from an untyped source (JSON values, Array elements, Dictionary lookups).
- Autoloads in `scripts/autoload/`, no `class_name`. Every other script has a `class_name`.
- Nodes resolved with `%UniqueName` or `@export`. Objects placed in `.tscn`, dynamic ones from `PackedScene.instantiate()`.
- Tunables (tolerances, budgets, ladder days) are `@export` on the scene that uses them.
- UTF-8 without BOM in every text file.

## Art

- Pack art first. Mana Seed tiles live in `assets/packs/` (gitignored, copied from `F:\UnityNVME\Art\Sprites\Mana Seed`).
- Shrine props are drawn by code under the repo pixel rule (grid and hex palette stated, every colour checked).
- Spirits are composed at runtime: zone blob + `assets/glyphs/<cp>.png` + eyes.

## Verify

- Pure-logic tests run as scripts: `"G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe" --headless --path kotodama -s tools/test_core.gd`.
- Tests that touch autoloads run as scenes: `... --headless --path kotodama tools/test_scene.tscn`. A `-s` script cannot resolve autoload names.
- Both print `TEST RESULT: PASS`. After adding scenes, sprites or fonts, run `... --headless --path kotodama --import` once.
- Run: open `kotodama/project.godot` and F5.
