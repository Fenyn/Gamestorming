# Zenith

Duel card game client. Godot 4.6, GDScript. Design doc is `../designs/zenith.md`; read it before rules work.

## Rules

- No source-material names anywhere: code, data, assets, comments, docs. Mechanics are emulated, flavor is original.
- Mechanical values come from the reference game's final pre-reboot rulebook and rulings. When a rule changed across sets, use the later revision.
- Engine stays pure: `engine/` is RefCounted only, no Nodes, no autoloads, no scene access. Deterministic for a seed plus a command list.
- Every player decision is a `Prompt` with explicit `Command` options. Clients and AI pick from `options`, never construct commands by hand.
- Clients render from `SeatView` / `PromptView` only, through `Referee`. Never hand a client the `DuelEngine` or a `CardInstance`; if the view lacks something, extend the view.
- Card behavior is data first. Add an effect `op` or trigger to `DuelEngine` before reaching for a script hook.
- No card content yet. Fixtures under `tests/fixtures/` use "Test" names and are not content.

## Verify

Headless tests, from the repo root, with the 4.6 binary from `README.md`:

```
--headless --path zenith --import
--headless --path zenith -s tests/run_tests.gd
```

Re-run `--import` whenever a `class_name` script is added. Add a test for every rule you touch.

Client changes get a windowed autoplay screenshot (flags in `README.md`) and a look at the PNG. Keep the screenshot under 1900 px wide.

## Style

- Explicit types everywhere. No `:=` from untyped sources (Dictionary reads, JSON).
- snake_case files, one class per file, `class_name` matches the file.
- Scenes hold static content; scripts do not spawn what the editor can place.
