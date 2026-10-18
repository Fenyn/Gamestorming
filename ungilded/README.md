# Ungilded

Story-driven PF2e tactics game, driven by the Pf2e.Core Remaster rules engine. This project hosts the opening (Prologue): see `designs/ungilded_opening.md` in the repo root. The combat layer (board, HD-2D terrain and looks, HUD, dice, log, reactions, knowledge journal) was copied from Delve.

The Pf2e.Core data path is the `ungilded/pf2e_pack_path` project setting in `project.godot`. Point it at this machine's `Pf2e.Core/Data/pf2e-source/packs/pf2e` folder.

## Run

```
dotnet build Ungilded.sln -c Debug
G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe --path G:/Godot/Gamestorming/ungilded
```

The main scene is the title, `scenes/story/title.tscn` (F5). Prologue plays the opening from `scenes/story/prologue.tscn` and returns to the title after the last beat.

The dev harness is `scenes/dev/combat_test.tscn` (F6 on the open scene): two preset heroes against two Giant Rats on a generated sewer map. `Biome` on the scene's root picks another biome ("forest"); `UseGeneratedMap` off gives the flat board. `UNGILDED_MAP_SEED` overrides the map seed. The heroes are Delve's Veteran and Elara presets. They are temporary, until the Prologue pregens exist. `scripts/presets` still holds Delve's whole roster for the same reason.

## Story

Scripts are in `scripts/story/`, scenes in `scenes/story/`, data in `assets/story/` and `assets/portraits/`.

- `assets/story/*.tres` hold one `DialogueSequence` each: the narrative intro, scenes 1 to 7, the Encounter 1 Friend line and the Encounter 4 lines (half HP, quarter HP, victory, closing). Text is verbatim from the spec. `Backdrop` says whether the lines play over black or over the board.
- `assets/portraits/player_portraits.tres` and `friend_portraits.tres` map each `Emotion` to a 64x64 region of the copied Unity sheets. The line's Emotion picks the portrait.
- `assets/story/story_theme.tres` adds the story type variations (narration page, dialogue name and text, italic narration) and the `StoryPalette` ember colour. Everything else falls through to `assets/ui/ui_theme.tres`.
- `title.tscn`: title art, Prologue and Quit.
- `fade_overlay.tscn` (layer 20): the black backdrop. `FadeIn` brings the black up, `FadeOut` takes it away.
- `narration.tscn` (layer 21): one line per page over black.
- `dialogue_box.tscn` (layer 22): portrait, name and typewriter text along the bottom. Narration lines are italic with no portrait.
- `tutorial_popup.tscn` (layer 23): BBCode text and Continue. `ShowMessage` completes on dismiss.
- `prologue.tscn`: `PrologueDirector` runs its `Beats` (Narration, Dialogue, Encounter). Encounters go through `IEncounterRunner` (`Prepare`, `Run`, `Release`). With `EncounterRunnerNode` empty it uses `StubEncounterRunner`, which wins every fight at once.

## Spikes

Headless, each prints `SPIKE RESULT: PASS`:

```
...console.exe --path G:/Godot/Gamestorming/ungilded --headless res://scenes/dev/<name>_spike.tscn
```

for `combat_smoke`, `prologue_content` and `story_flow`.

`combat_smoke_spike` starts the harness fight in the full combat scene, Strides the first hero into reach, Strikes once, passes later hero turns and waits for one enemy turn to end.

Run it without `--headless` to also save the board at the first hero turn to `dev_shots/combat_smoke.png`. Keep the window off-screen:

```
...console.exe --path G:/Godot/Gamestorming/ungilded --position -4000,-4000 res://scenes/dev/combat_smoke_spike.tscn
```

`UNGILDED_SMOKE_BIOME=forest` runs the same spike on a forest map and saves `dev_shots/combat_smoke_forest.png`. Forest maps are larger, so the Strike check can fail there when no rat is in reach after two Strides.

`prologue_content_spike` checks the Prologue content in `scripts/content`: the two pregens (`PrologueCast`), the sewer creatures (`PrologueBestiary`) and the four authored maps (`PrologueMaps`). It then starts Encounter 4 in the combat scene and checks that the Tyrant's acid weakness is live and that the journal masks its AC. Run it without `--headless` (off-screen, as above) to also save the Encounter 3 and 4 boards to `dev_shots/map_e3.png` and `dev_shots/map_e4.png`.

`story_flow_spike` checks every dialogue sequence against the spec line counts, speaker names and narration flags, checks both portrait sets and the title and Prologue scene links, runs the Prologue director through every beat with the stub runner (beat order, runner calls, black or board behind each line, lines shown), and checks the tutorial popup queue. Rendered, it also saves `dev_shots/title.png`, `narration.png`, `dialogue_narration.png`, `dialogue_black.png`, `dialogue_board.png` and `popup.png`. The board captures run the combat harness behind the box.

`UNGILDED_SHOT_DIRECTORY`, when set, replaces the directory of every capture.

## Art tools

Run from the project folder after a palette change in `assets/ui/ui_theme.tres`:

- `python tools/art/kenney_chrome.py` rewrites `assets/ui/kenney/`.
- `python tools/art/bake_condition_tiles.py` rewrites `assets/ui/conditions/tiles/`.
- `python tools/art/import_goldenskull.py` rewrites `assets/textures/terrain/gs/` from the source pack.

The enemy sprite exporters named in `assets/sprites/enemies/README.md` stay in Delve, with the layered masters they read.
