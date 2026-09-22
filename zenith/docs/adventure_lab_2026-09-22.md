# Adventure lab, 2026-09-22

`tests/adventure_lab.gd`, 10 runs per starter, seed 7, player AI `scorer`, opponents at each
ladder row's `ai_level`, lives rule on (player 2, opponent 1, boss 2), random Aspect and bundle
picks. 878 stage duels in all. Raw per-stage TSVs are in `reports/adventure_lab/<starter>.tsv`.

Read the numbers as a floor: the scorer plays worse than a person and picks rewards at random.
Ten runs a starter is small, so single-run differences are noise.

| Starter | Runs won | Mean stages cleared | Median death stage | Mean Motes | Broken |
|---|---|---|---|---|---|
| pyre_attrition | 3/10 | 6.9 | 8 | 346 | 0 |
| tide_companions | 1/10 | 6.8 | 8 | 335 | 0 |
| steel_beatdown | 3/10 | 6.2 | 6 | 297 | 0 |
| pyre_ascent | 4/10 | 5.9 | 5.5 | 280 | 0 |
| tide_deepwater | 0/10 | 5.5 | 6.5 | 241 | 0 |
| storm_volley | 0/10 | 5.2 | 7.0 | 232 | 0 |
| storm_unbound | 0/10 | 5.1 | 6.0 | 215 | 0 |
| root_seals | 1/10 | 5.1 | 6 | 227 | 0 |
| pyre_beatdown | 1/10 | 5.0 | 6 | 211 | 0 |
| shade_mind_siege | 0/10 | 4.9 | 6.5 | 223 | 0 |
| steel_heir | 0/10 | 4.8 | 6.0 | 198 | 0 |
| shade_henchmen | 0/10 | 4.8 | 6.0 | 197 | 0 |
| shade_salvage | 0/10 | 4.7 | 6.0 | 205 | 0 |
| freestyle_swords | 0/10 | 4.2 | 5.0 | 160 | 0 |

Win rate per stage (wins/reached), starters ordered as above:

| Starter | S1 | S2 | S3 | S4 | S5 | S6 | S7 | S8 |
|---|---|---|---|---|---|---|---|---|
| pyre_attrition | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 | 9/10 | 7/9 | 3/7 |
| tide_companions | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 | 7/10 | 1/7 |
| steel_beatdown | 10/10 | 10/10 | 10/10 | 10/10 | 8/10 | 6/8 | 5/6 | 3/5 |
| pyre_ascent | 10/10 | 10/10 | 10/10 | 9/10 | 7/9 | 5/7 | 4/5 | 4/4 |
| tide_deepwater | 10/10 | 10/10 | 10/10 | 10/10 | 7/10 | 5/7 | 3/5 | 0/3 |
| storm_volley | 9/10 | 9/9 | 9/9 | 9/9 | 8/9 | 6/8 | 2/6 | 0/2 |
| storm_unbound | 10/10 | 10/10 | 10/10 | 9/10 | 6/9 | 4/6 | 2/4 | 0/2 |
| root_seals | 10/10 | 9/10 | 9/9 | 8/9 | 6/8 | 5/6 | 3/5 | 1/3 |
| pyre_beatdown | 10/10 | 10/10 | 9/10 | 9/9 | 7/9 | 3/7 | 1/3 | 1/1 |
| shade_mind_siege | 9/10 | 8/9 | 8/8 | 8/8 | 7/8 | 5/7 | 4/5 | 0/4 |
| steel_heir | 10/10 | 10/10 | 9/10 | 8/9 | 6/8 | 4/6 | 1/4 | 0/1 |
| shade_henchmen | 10/10 | 10/10 | 10/10 | 7/10 | 6/7 | 4/6 | 1/4 | 0/1 |
| shade_salvage | 9/10 | 9/9 | 8/9 | 8/8 | 6/8 | 4/6 | 3/4 | 0/3 |
| freestyle_swords | 10/10 | 10/10 | 9/10 | 7/9 | 4/7 | 1/4 | 1/1 | 0/1 |

Opponent families across all runs (player win rate when faced):

| Family | Faced | Player wins | Rate |
|---|---|---|---|
| steel_beatdown | 43 | 14 | 33% |
| pyre_attrition | 66 | 26 | 39% |
| shade_mind_siege | 35 | 16 | 46% |
| root_seals | 37 | 27 | 73% |
| pyre_beatdown | 53 | 47 | 89% |
| freestyle_swords | 54 | 48 | 89% |
| pyre_ascent | 74 | 69 | 93% |
| shade_henchmen | 66 | 62 | 94% |
| storm_unbound | 80 | 76 | 95% |
| tide_deepwater | 55 | 53 | 96% |
| storm_volley | 57 | 55 | 96% |
| steel_heir | 84 | 84 | 100% |
| tide_companions | 98 | 98 | 100% |
| shade_salvage | 76 | 76 | 100% |

Bundles taken at least 8 times, with the win rate of stages played while held (rough, favours early picks):

| Bundle | Taken | After | Rate |
|---|---|---|---|
| grounds_the_high_watch | 41 | 133/169 | 79% |
| free_draw_checks | 38 | 141/174 | 81% |
| free_answer_fetch | 35 | 112/145 | 77% |
| free_recovery | 24 | 87/107 | 81% |
| free_ally_sweep | 18 | 22/40 | 55% |
| grounds_weighted_hollow | 16 | 26/41 | 63% |
| shade_hand_keep | 16 | 45/61 | 74% |
| free_ally_call | 15 | 14/28 | 50% |
| emrys_ally_core | 15 | 27/41 | 66% |
| pyre_art_answer | 14 | 53/65 | 82% |
| free_vigil_answers | 14 | 57/69 | 83% |
| grounds_the_marked_ring | 12 | 19/29 | 66% |
| grounds_ancient_grove | 12 | 9/18 | 50% |
| free_lone_blade | 12 | 19/30 | 63% |
| free_damage_floor | 12 | 34/44 | 77% |
| ashmark_fuel | 12 | 55/64 | 86% |
| storm_strike_answers | 12 | 39/51 | 76% |
| sable_ally_core | 11 | 19/29 | 66% |
| pyre_basic_climb | 11 | 47/55 | 85% |
| free_any_stops | 11 | 47/56 | 84% |
| free_grounds_answer | 11 | 12/22 | 55% |
| free_tempo_tax | 11 | 26/34 | 76% |
| shade_art_answer | 11 | 36/47 | 77% |
| shade_hand_strip | 11 | 36/47 | 77% |
| free_recycle_attacks | 10 | 13/22 | 59% |
| steel_endurance_line | 10 | 28/38 | 74% |
| storm_shield_drills | 10 | 42/52 | 81% |
| steel_strike_floor | 9 | 41/47 | 87% |
| storm_art_volley | 9 | 23/32 | 72% |
| tide_tempo_guard | 9 | 34/43 | 79% |
| grounds_frostbound_moor | 8 | 16/24 | 67% |
| free_unstoppable | 8 | 11/17 | 65% |
| pyre_recursion | 8 | 8/14 | 57% |
| free_lobbed_setup | 8 | 18/23 | 78% |
| root_strike_guards | 8 | 29/36 | 81% |

Stage rows in total: 878; loss reasons: survival 111, ascension 11, seal 5
Mean turns per stage: S1 5.0, S2 4.8, S3 5.5, S4 6.0, S5 7.8, S6 7.8, S7 10.6, S8 11.9

Stage 7 (t5, stronger band) and stage 8 (boss) by opponent, wins/faced across all starters:

| Opponent | Stage 7 | Stage 8 |
|---|---|---|
| root_seals | 23/28 | 4/9 |
| steel_beatdown | 10/23 | 4/20 |
| shade_mind_siege | 11/20 | 5/15 |

Reading:

- Stages 1 to 4 are near-free for every starter (freestyle_swords and shade_henchmen drop a few at
  stage 4). The ladder bites at stage 5 and the boss is where most surviving runs end.
- The "stronger" band is really two decks: steel_beatdown and shade_mind_siege win the boss stage
  about three times in four; root_seals loses it more often than it wins it at t5.
- pyre_attrition, steel_beatdown and shade_mind_siege as opponents beat the player at every tier;
  steel_heir, tide_companions and shade_salvage never won a single duel as opponents.
- Loss route is survival in 111 of 127 losses. Ascension losses (11) and Seal losses (5) are rare.
- Turn count climbs from 5 at stage 1 to 12 at the boss.

## Starter pick rating, 2026-09-22

The S/A/B/C `rating` letter is gone. Each starter file now stores `cleared`, its mean ladder
stages cleared in this sweep, next to its `difficulty`. `DeckList.run_score()` adds an ease
bonus (easy 2, medium 1, hard 0) to `cleared` for one number out of ten, and the roster tile
shows that as a row of five pips (score halved, rounded) along the bottom edge of the tile,
tinted gold from 6.0 cleared, green from 5.0, red below. Nothing else about strength or ease is
written on the tile; no number reaches the player.

| Starter | Cleared | Play | Pips |
|---|---|---|---|
| steel_beatdown | 6.2 | easy | 4 |
| pyre_attrition | 6.9 | medium | 4 |
| pyre_ascent | 5.9 | easy | 4 |
| tide_companions | 6.8 | medium | 4 |
| pyre_beatdown | 5.0 | easy | 4 |
| shade_henchmen | 4.8 | easy | 3 |
| tide_deepwater | 5.5 | medium | 3 |
| storm_volley | 5.2 | medium | 3 |
| storm_unbound | 5.1 | medium | 3 |
| root_seals | 5.1 | medium | 3 |
| steel_heir | 4.8 | medium | 3 |
| shade_salvage | 4.7 | medium | 3 |
| freestyle_swords | 4.2 | medium | 3 |
| shade_mind_siege | 4.9 | hard | 2 |
