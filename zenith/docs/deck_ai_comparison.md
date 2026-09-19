# Weak-deck planner comparison

The latest recovered full tournament is [the September 19 report](deck_tournament_2026-09-19.txt), completed at 12:11 local time. It contains 1,320 completed matches, 240 appearances per deck, and no unfinished games. The bottom four were Steel Heir (46/240, 19.2%), Pyre Ascent (59/240, 24.6%), Tide Companions (65/240, 27.1%), and Shade Salvage (65/240, 27.1%). Storm Volley was 49.2%; Storm Unbound was 52.9%.

The original output came from the project's temporary tournament task output and is preserved verbatim here. It identifies Godot 4.4.1, but does not record its command line, policy, seed, or input hashes. The tournament scripts default to `scorer`. Treat these historical standings as target selection, not as a controlled baseline for the current build.

Normal and Hard already enable sequence search through `AiProfile`. There is no deck-specific implementation switch to install. The tournament scripts intentionally default to the faster scorer; `--search-decks` enables sequence search only for the named decks while leaving the rest on the selected base policy.

## Controlled experiment

`tests/deck_ai_comparison.gd` compares each selected deck against every other shipped deck, from both seats. For every pairing it runs the current scorer baseline and then sequence search with the same engine and per-seat AI seeds. The opposing policy stays on the scorer. Both arms use current card data, strategic profiles, scorer and hidden-information model, isolating the addition of sequence planning rather than attempting to reproduce the historical executable.

The report records individual outcomes, gained and lost wins, timing, search depth and scorer fallbacks. A fixed seed controls starting conditions; a wall-clock search budget means exact outcomes can still vary with machine load. Small samples indicate where to investigate, not a reliable new deck ranking.

The recorded experiment uses Godot 4.6.2, a 400 ms budget, two samples and the default Normal search parameters. Each target runs in its own process, with four processes running concurrently on a 16-logical-processor machine. Each process uses `--seed=77 --seeds=1` and all ten opposing decks. That gives 20 paired starting conditions per target and 160 games overall. Card data, engine, AI and profile hashes accompany each report; inputs are checked before and after every match. Decks and profiles are loaded once per process.

To reproduce a target's exact schedule, run it separately rather than combining all four target names. The schedule's random generator advances across targets within one invocation:

```text
--headless --path zenith -s tests/deck_ai_comparison.gd -- --targets=steel_heir --seeds=1 --seed=77 --budget=400 --samples=2 --report=res://reports/steel_heir.json
```

Replace the target and output name for the other decks. The report refuses to overwrite an existing file; `--resume` continues it only when its configuration and input hashes match. Use the same Godot executable when resuming. Partial pairs do not count toward win-rate deltas. Invalid or unfinished games abort the experiment rather than silently becoming losses.
