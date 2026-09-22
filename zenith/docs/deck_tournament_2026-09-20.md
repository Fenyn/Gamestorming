# Deck tournament, 2026-09-20

Full round robin of the 13 precons. 15596 matches, 200 per deck pair, both seats.
`tests/deck_outcomes.gd`, `--policy=scorer --repeats=50 --seed=1`, deck playstyle profiles on,
one process per pair, 8 concurrent, Godot 4.6.2 mono.

Scorer, not the Normal sequence-search profile. Normal at this sample size is a multi-day run;
see `designs/zenith_adventure.md` for the timing curve. These are directly comparable to the
2026-09-19 standings quoted in `designs/zenith_adventure.md`, which were also scorer.

## Standings

| deck | played | win% | survival | seal | ascension |
|---|---:|---:|---:|---:|---:|
| steel_beatdown | 2400 | 83.6% | 1990 | 0 | 17 |
| pyre_attrition | 2400 | 73.8% | 1216 | 0 | 556 |
| shade_henchmen | 2400 | 67.8% | 1625 | 0 | 1 |
| freestyle_swords | 2400 | 65.8% | 1574 | 0 | 4 |
| pyre_beatdown | 2400 | 61.1% | 1398 | 0 | 68 |
| tide_deepwater | 2399 | 55.5% | 1331 | 0 | 1 |
| root_seals | 2396 | 51.9% | 546 | 697 | 0 |
| storm_unbound | 2400 | 43.0% | 987 | 0 | 44 |
| storm_volley | 2399 | 42.9% | 1028 | 0 | 0 |
| tide_companions | 2398 | 37.2% | 890 | 0 | 1 |
| shade_salvage | 2400 | 26.7% | 636 | 1 | 4 |
| pyre_ascent | 2400 | 21.3% | 335 | 0 | 176 |
| steel_heir | 2400 | 19.6% | 467 | 0 | 3 |

## Matrix

Row's win% against column, 200 matches each.

| pilot | freestyle swords | pyre ascent | pyre attrition | pyre beatdown | root seals | shade henchmen | shade salvage | steel beatdown | steel heir | storm unbound | storm volley | tide companions | tide deepwater |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| freestyle_swords | - | 94% | 52% | 40% | 78% | 46% | 82% | 30% | 90% | 82% | 64% | 72% | 56% |
| pyre_ascent | 6% | - | 6% | 7% | 15% | 14% | 38% | 16% | 62% | 24% | 42% | 11% | 14% |
| pyre_attrition | 48% | 94% | - | 70% | 47% | 58% | 86% | 44% | 98% | 94% | 96% | 82% | 70% |
| pyre_beatdown | 60% | 93% | 30% | - | 52% | 43% | 71% | 24% | 96% | 68% | 68% | 62% | 65% |
| root_seals | 22% | 85% | 53% | 48% | - | 10% | 59% | 14% | 74% | 65% | 60% | 77% | 58% |
| shade_henchmen | 54% | 86% | 42% | 57% | 90% | - | 85% | 24% | 80% | 84% | 70% | 72% | 68% |
| shade_salvage | 18% | 62% | 14% | 29% | 41% | 15% | - | 3% | 62% | 12% | 16% | 30% | 20% |
| steel_beatdown | 70% | 84% | 56% | 76% | 86% | 76% | 97% | - | 98% | 91% | 99% | 86% | 82% |
| steel_heir | 10% | 38% | 2% | 4% | 26% | 20% | 38% | 2% | - | 28% | 30% | 22% | 16% |
| storm_unbound | 18% | 76% | 6% | 32% | 35% | 16% | 88% | 9% | 72% | - | 61% | 78% | 26% |
| storm_volley | 36% | 58% | 4% | 32% | 40% | 30% | 84% | 1% | 70% | 39% | - | 85% | 35% |
| tide_companions | 28% | 89% | 18% | 38% | 23% | 28% | 70% | 14% | 78% | 22% | 15% | - | 22% |
| tide_deepwater | 44% | 86% | 30% | 35% | 42% | 32% | 80% | 18% | 84% | 74% | 65% | 78% | - |
