# Eidolarch (code name Zenith)

Duel card game client. Godot 4.6, GDScript. Design doc is `../designs/zenith.md`; read it before rules work. `docs/strategy.md` is how the game is played well, per deck and per archetype; read it before AI profile or deck balance work.

## Rules

- No source-material names anywhere: code, data, assets, comments, docs. Mechanics are emulated, flavor is original.
- Rules and rulings come from the anchor CRD, `docs/reference/crd_2014-08-19.pdf` (searchable copy beside it). Check every rule and card ruling against it first, and never against a later rules document. House rules are the ones `../designs/zenith.md` marks as house rules.
- Every starter card parallels one printed card from the reference game's era, promos included. Nothing from fan-made, custom or homebrew sets, even when a deck sheet or article lists it. `docs/card_roster.csv` records the source; check it against a printed-card listing before adding a card.
- Engine stays pure: `engine/` is RefCounted only, no Nodes, no autoloads, no scene access. Deterministic for a seed plus a command list.
- Every player decision is a `Prompt` with explicit `Command` options. Clients and AI pick from `options`, never construct commands by hand.
- Clients render from `SeatView` / `PromptView` only, through `Referee`. Never hand a client the `DuelEngine` or a `CardInstance`; if the view lacks something, extend the view.
- Adventure run state (`adventure/`) is RefCounted only: no Nodes, no autoload access, no scene access, and tested from `tests/run_tests.gd`. The screens under `scripts/adventure/` are the only part that reads `Session`.
- The AI (`ai/`) is RefCounted only and fair. It gets engines from `Referee.sim_for` and nowhere else, never names a card or deck in code, and takes playstyle from an `AiProfile`. Do not run `tests/ai_arena.gd`, matchlab or other long AI simulations unless the user asks for one; they are slow, expensive and rarely needed for a regression check. Cover AI changes with targeted tests in `tests/run_tests.gd`.
- Do not automate a player's choice on an assumption. A search of the Life Deck always asks, shows the whole deck to the searcher, allows taking nothing, and shuffles once at the end unless the card says `no_shuffle`. The same goes for any new effect that looks at hidden cards.
- Card behavior is data first. Add an effect `op` or trigger to `DuelEngine` before reaching for a script hook.
- No card content yet. Fixtures under `tests/fixtures/` use "Test" names and are not content.

## Verify

Headless tests, from the repo root, with the 4.6 binary from `README.md`:

```
--headless --path zenith --import
--headless --path zenith -s tests/run_tests.gd
```

Re-run `--import` whenever a `class_name` script is added. Add a test for every rule you touch.

Client changes get a windowed autoplay screenshot (flags in `docs/dev_reference.md`) and a look at the PNG. Keep the screenshot under 1900 px wide.

## Style

- Explicit types everywhere. No `:=` from untyped sources (Dictionary reads, JSON).
- snake_case files, one class per file, `class_name` matches the file.
- Scenes hold static content; scripts do not spawn what the editor can place.
