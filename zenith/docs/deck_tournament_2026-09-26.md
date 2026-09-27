# Deck tournament, 2026-09-26

Full matrix of the 14 precons in `data/decks`, printed rules, deck playstyle profiles on,
`tests/matchlab.gd --scenario=res://tests/scenarios/balance.json`, 6 shards merged with
`tools/merge_matchlab.gd`. Raw reports are under `reports/tournament_2026-09-26/`.

- Search: `--budget=600 --repeats=1`, 364 matches, 52 per deck (95% range about ±13 points).
- Scorer: `--policy=scorer --repeats=9`, 3276 matches, 468 per deck (about ±4 points).
- Before: the morning's code (`search/`, `scorer/`). After: the AI fixes of the same day
  (`search_after/`, `scorer_after2/`), listed below.
- 2026-09-20: `docs/deck_tournament_2026-09-20.md`, scorer, 2400 per deck.

| deck | scorer before | scorer after | search before | search after | 2026-09-20 scorer |
|---|---:|---:|---:|---:|---:|
| pyre_attrition | 65.6% | 84.0% | 80.8% | 71.2% | 73.8% |
| steel_beatdown | 84.6% | 83.3% | 82.7% | 88.5% | 83.6% |
| shade_mind_siege | 85.5% | 78.0% | 78.8% | 78.8% | – |
| freestyle_swords | 68.2% | 60.9% | 67.3% | 71.2% | 65.8% |
| shade_henchmen | 57.3% | 52.1% | 53.8% | 50.0% | 67.8% |
| pyre_beatdown | 55.1% | 50.2% | 57.7% | 53.8% | 61.1% |
| root_seals | 56.4% | 49.8% | 32.7% | 57.7% | 51.9% |
| pyre_ascent | 13.9% | 48.9% | 34.6% | 38.5% | 21.3% |
| tide_deepwater | 42.7% | 43.2% | 65.4% | 42.3% | 55.5% |
| storm_unbound | 45.7% | 41.7% | 26.9% | 40.4% | 43.0% |
| storm_volley | 37.8% | 34.4% | 36.5% | 40.4% | 42.9% |
| tide_companions | 41.5% | 32.3% | 42.3% | 32.7% | 37.2% |
| steel_heir | 20.7% | 20.9% | 17.3% | 21.2% | 19.6% |
| shade_salvage | 25.0% | 20.3% | 23.1% | 13.5% | 26.7% |

Wins by route (survival / seal / ascension): scorer before 2984 / 132 / 160, after 2705 / 99 / 472;
search before 317 / 5 / 42, after 308 / 20 / 36.

## What changed between before and after

- The Squall Mastery's Strike lock never fired (its line was `if_successful`, which a Mastery never
  runs); it is `on_success` now, with a test that every Mastery line names a trigger that runs.
- The scorer values a check's two branches, which is why both Pyre decks now use their Mastery's
  Fervor and climb: ascension wins went from 160 to 472.
- The scorer prices paying life or a card for damage, burning the discard pile, "either side"
  effects, standing modifiers and the Mastery's lines on an attack, and values held attacks and
  defenses by the damage they deal or stop. A kept card through the opponent's turn is a defense
  first.
- Declaring Combat is answered by the scorer under search too, which restored Root's plan of never
  opening Combat (search Seal wins 5 to 20).
- The search leaf counts Energy the next Power Up refills at half, doomed hand cards at half and
  standing modifiers by the attacks they touch, and a depth-1 near tie keeps the scorer's pick.

The four decks that moved between policies (root_seals, storm_unbound, tide_deepwater, pyre_ascent)
now agree between scorer and search within the noise.

## Revised lists (`scorer_decks/`)

steel_heir took 13 swaps (Emrys Risks It All x4, Emrys' Rising Blow x4, Steel Shedding Scales x3,
Marble Seals 5 and 6 for High Watch, Watchful Eye, Caedan Cuts It Short, Dismissal and two Clawed
Hands Drills) and went from 20.9% to 39.1% under the scorer. shade_salvage took 18 swaps (cheaper
Energy returns, Salt Seals 1, 3 and 6, Siphon Dormant, Tithe) and stayed at 20.9%. The rest of the
field moved within the noise.

## Open

- pyre_attrition at 84% under the scorer, driven by the Ascension route now that its Mastery is
  played.
- steel_heir and shade_salvage stay near 20% under both policies; the causes are in their lists.
