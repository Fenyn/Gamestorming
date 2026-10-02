# Eidolarch

A two-player dueling card game. Two duelists, mages or plain swordsmen, fight over a gate to another world. You win by emptying your rival's Life Deck, by climbing to your last Aspect with full Fervor, or by holding all seven Seals.

The rules emulate a classic collectible card game from the early 2000s under an original theme, names and cards. The folder and code name are `zenith`.

**Alpha 0.1.0.** [Play in a browser](https://fenyn.github.io/Gamestorming/zenith/) (offline modes only) or run the Windows build for online play.

## Modes

| Mode | What it is |
|---|---|
| Duel the AI | One duel against the AI at Easy, Normal or Hard. |
| Hotseat | Two players on one screen, with a hand-off between turns. |
| Adventure | A roguelite run over a three-act node map: duels, Elites, bosses, Shops, Forges, Shrines and Relic nodes. Wins pay Motes, which buy cards, deck slots and Aspects between runs. |
| Online | Duels refereed on a dedicated server: Find a duel (casual queue), share-code rooms, and ranked best-of-three with ratings. Desktop only. |
| Tutorial | Five scripted lessons in which Caedan Vale trains young Emrys. Built, but switched off for now. |
| Deck builder | Build and import decks. Built, but switched off for now. |

## Run it

Open `zenith/project.godot` in Godot 4.6.2 and press F5. The usual editor is the .NET build (`G:\Godot\Godot_v4.6.2-stable_mono_win64\`); exports use the standard GDScript-only build (`G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe`), because only it can export to the web.

## How it is built

- **Engine** (`engine/`): the rules. Pure RefCounted code, no Nodes, deterministic for a seed plus a list of commands. Every decision is a `Prompt` whose options are the only commands it accepts. `Referee` wraps the engine and gives each seat only what it may see (`SeatView`, `PromptView`).
- **AI** (`ai/`): `AiScorer` picks from the same options a player gets, with a weight profile per playstyle (`data/ai/profiles/`). It never names a card or deck.
- **Client** (`scenes/`, `scripts/`): a 3D table with a 2D hand and HUD. It renders only from seat views, so hotseat, AI, online and replays share one client.
- **Adventure** (`adventure/`): run state, map, rewards and economy, pure RefCounted and tested headless.
- **Online** (`scripts/net/`, `scripts/server/`): ENet over DTLS to one duel server that runs the only engine. Clients pin the server's certificate.
- **Tutorial** (`tutorial/`, `data/tutorial/`): a director that scripts the rival and gates the player's options, over the normal engine.
- **Deck builder** (`deckbuild/`, `scenes/builder/`): deck editing rules, an importer and saved player decks.

## Data

| Path | What |
|---|---|
| `data/cards/starter/starter_set.json` | Every card. Hand-maintained and the source of truth. Rules text on card faces is generated from it (`engine/card_text.gd`). |
| `data/decks/` | The fourteen starter decks. |
| `data/adventure/` | Map, opponents, rewards, economy, Resonances, lead-in dialogue. |
| `data/tutorial/` | Lesson script, tutorial decks and the Straw Knight. |
| `data/strike_table.json` | The Strike Table that turns Might into damage. |

## Rules

- Design and rules: `../designs/zenith.md`. Adventure design: `../designs/zenith_adventure.md`.
- Rulings come from the anchor CRD, `docs/reference/crd_2014-08-19.pdf` (searchable `.txt` beside it). House rules are the ones the design doc marks as house rules.
- Every card parallels one printed card from that era; `docs/card_roster.csv` records which.

## Tests

From the repo root with the .NET editor binary:

```powershell
$godot = "G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe"
& $godot --headless --path zenith --import          # once after adding a class_name script
& $godot --headless --path zenith -s tests/run_tests.gd
```

The regular suites are `run_tests`, `tutorial_tests`, `ui_cleanup_tests`, `title_ui_tests`, `combat_presentation_tests`, `ui_redesign_smoke` and `network_regression_tests`. The long AI simulations (`ai_arena`, `matchlab`, `adventure_lab`) are for balance questions and run only when asked.

Client changes get a windowed screenshot, for example:

```powershell
& $godot --path zenith --resolution 1600x900 res://scenes/duel/duel.tscn -- --dev-autoplay --dev-steps=45 --dev-seed=5 --dev-screenshot=C:\path\shot.png
```

## Shipping a build

In this order, because each client pins the certificate of the server it was exported against:

1. Run the regular suites.
2. `powershell -File zenith\tools\server\deploy.ps1` exports the Linux server, uploads it, restarts it and copies its certificate to `data/net/duel_server.crt`. Duels in progress end.
3. Export the Windows client with the GDScript-only editor: `--headless --path zenith --export-release "Windows Desktop" build/windows/eidolarch.exe`.
4. `powershell -File zenith\tools\web\export_web.ps1` exports the web build into `../web-prebuilt/zenith/`.
5. Commit, including `web-prebuilt/zenith/`, and push `main`. The Pages workflow publishes the site.

The web build is published prebuilt because the art packs are gitignored, so CI cannot export it. It runs the Compatibility renderer, greys out every online option ("Online play is only available in the desktop version."), and skips two heavy background effects.

## Release switches

`project.godot`, section `[zenith]`: `release/tutorial` and `release/deck_builder`, both `false`. While off, their buttons are greyed with a note. `--dev-tutorial` and `--dev-builder` open them anyway. The version shown on the title comes from `application/config/version`.

## Docs

| File | What |
|---|---|
| `docs/dev_reference.md` | Every dev flag, engine and client notes, the card JSON schema, the test and simulation runners. |
| `docs/duel_server.md` | The duel server: deploy, identity, transport, queues, ranked, match records. |
| `docs/cast.md` | Characters and lore. |
| `docs/strategy.md` | How each deck and archetype is played well. |
| `docs/card_roster.csv`, `card_pool.md` | Every card with its rules text and source card. |
| `docs/tutorial_script.md` | The tutorial beat by beat. |
| `docs/presentation.md` | Screens and effects. |
| `CLAUDE.md` | Rules for working in this project. |
