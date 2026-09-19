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

## Results

All 160 games completed legally. All four reports have identical source/data fingerprints. Each row compares 20 paired starting conditions, with opponents remaining on the scorer.

| Target / raw report | Scorer wins | Planner wins | Change | Losses turned into wins | Wins turned into losses |
| --- | ---: | ---: | ---: | ---: | ---: |
| [Steel Heir](deck_ai_steel_heir.json) | 2/20 (10%) | 3/20 (15%) | +5 points | 3 | 2 |
| [Pyre Ascent](deck_ai_pyre_ascent.json) | 6/20 (30%) | 7/20 (35%) | +5 points | 5 | 4 |
| [Tide Companions](deck_ai_tide_companions.json) | 7/20 (35%) | 5/20 (25%) | -10 points | 1 | 3 |
| [Shade Salvage](deck_ai_shade_salvage.json) | 10/20 (50%) | 9/20 (45%) | -5 points | 3 | 4 |

The planner won 24/80 target appearances versus the scorer's 25/80. This sample does not establish a general improvement. Steel Heir and Pyre each gained only one net win; Tide and Shade Salvage need further investigation. The historical tournament percentages differ from this current-build baseline because the sample, seeds, executable and potentially inputs differ. Only the paired columns above isolate the planner change in this experiment.

Pyre's win route changed substantially: its scorer won five games by survival and one by Ascension, while its planner won one by survival and six by Ascension. That is evidence of different strategic choices despite the small net gain. Both policies' wins for Steel Heir and Shade Salvage were by survival.

| Target | Branching decisions | Mean completed branching depth | Scorer fallbacks | Mean target decision ms | Maximum target decision ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Steel Heir | 850 | 0.91 | 138 (16.2%) | 401.4 | 418.1 |
| Pyre Ascent | 837 | 1.70 | 120 (14.3%) | 371.5 | 415.2 |
| Tide Companions | 1,974 | 0.94 | 277 (14.0%) | 388.5 | 425.6 |
| Shade Salvage | 1,463 | 1.01 | 145 (9.9%) | 396.2 | 448.4 |

Depth and fallback percentages exclude forced single-option choices. Zero-depth fallbacks remain in the depth average. Timing includes all target decisions, including forced choices and Reserve selection; individual engine operations may run beyond the 400 ms deadline. Search depth is measured in branching levels, not turns or cards in a guaranteed combo.

The next diagnostic should replay Tide's lost matchups and measure whether its assembly and controller choices improve with more completed search depth. A larger-budget comparison can distinguish a budget limitation from poor evaluation or candidate selection. These results alone do not identify the cause. Keep this seed set for regression checks and use additional seeds to validate any tuning; do not tune solely to these 20 starts.

Runner verification also covered small selective-policy tournaments, malformed arguments and completed-report resume. Interrupted-report handling received a code review. No gameplay rules, deck lists or strategic profile weights were changed for this comparison.
