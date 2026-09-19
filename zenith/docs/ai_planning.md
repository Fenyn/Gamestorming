# AI planning

Implemented 2026-09-19. See [the design review](ai_strategy_review.md) for the original diagnosis and external research.

## Core behavior

`AiPlayer` remains the seat driver. It resolves public matchup preferences, then passes both the current profile and the unpivoted matchup profile into `AiSearch`. Easy, Normal and Hard use sequence search automatically; no client or host integration switch is required. Reserve decisions use the specialized `AiReserve` valuation through the scorer because short combat lookahead does not evaluate pregame deck swaps.

Search samples possible worlds through `Referee.sim_for`, selects a diverse set of legal root options, and explores alternative continuations with iterative deepening. The branching width is bounded, and a quiet option survives pruning. Forced decisions advance without spending an additional strategic depth. Every simulated submission still comes from a pending prompt.

Each completed iteration compares every retained root choice against the same initial sampled worlds. If time or node budget expires, the incomplete iteration is discarded. The last complete comparison determines the move; if none completed, the legal scorer choice is used. This prevents early-listed candidates from winning merely because they got more computation.

The continuation policy resolves `when` pivots from its matchup base at each hypothetical state. A simulated Bond can therefore change subsequent aggression. Leaf evaluation uses the fixed root profile, so branches cannot increase their value simply by changing the scale of weights.

Short greedy continuations evaluate the leaf beyond its immediate decision. An additional bounded settling allowance resolves pending attacks, effects, and choices where possible. Unresolved cutoffs are counted in diagnostics. `turns` is an outer horizon; it does not promise that the search reaches every turn under the available budget.

## What the AI values

The scorer and evaluator share contextual card values. Keeping, discarding and tutoring account for combo contribution rather than only printed damage. Tutor hints traverse current-Aspect effects, check conditions and affordability, discount future/conditional routes, and stop recursive cycles. They remain optimistic estimates; actual sequence simulation determines whether the chain executes.

The evaluator adds own-hand quality, remaining usable personality powers, available Drill/Non-Combat activations, and normalized Bond progress to existing resource and win-route terms. Duplicate hand cards receive diminishing quality credit. Spent, prohibited, unaffordable or condition-failed powers do not receive usable-power credit. Hidden opponent hand quality and hidden tutor-target availability are not treated as public facts.

Profiles may set `own`/`foe` weights `power`, `engine`, and `combo_progress`, plus `own.hand_quality`. Current fallback weights are respectively 0.35, 0.25, 0.5 for own combo/0.35 for opposing combo, and 0.15 for hand quality. Existing `bond_band` enables Bond-specific strategic valuation. Generic effect-based sequence search works without named-card scripts.

## Intention and information

Search retains conditional action hints keyed by observations and a short representative sequence expressed as card-definition roles and command kinds. Semantic hints survive tutor reveals that change sampled UID/identity associations. At the next real prompt, hints must match a current legal option and compete against fresh evaluation. They influence ordering and near-equal choices; they never force execution or prevent a better survival/winning line. Disruption naturally invalidates unavailable steps.

Initial samples preserve the player's known deck composition, but the opponent's undisclosed cards come from a public-compatible library prior. Public declarations, visible cards, copy limits and an inferred Seal set constrain that prior. Tiny invalid rule-fixture libraries have a documented fallback. This is a broad belief model, not an exact inferred opponent list or learned archetype model.

Opponent continuations are ranked from that opponent's permitted perspective. Alternative replies become weighted successor particles. Those particles are regrouped by what the AI itself observes before it chooses a follow-up. Otherwise an unseen opponent hand could accidentally become a branch label that tells the AI which continuation to play. Weights are preserved through terminal states, forced decisions and rollouts. Once the AI actually observes different information, its future decisions may differ.

Exact transposition keys include mutable card state, ordered zones, usage flags, pending effects, prompts and RNG state. Observation keys are never used as position-value cache keys. Exact caching is optional and disabled by default because its serialization overhead is substantial.

## Controls

| `think` key | Normal | Meaning |
| --- | --- | --- |
| `algorithm` | `sequence` | `rollout` selects the historical comparison baseline |
| `top_k` | 6 | Root candidate capacity, with quiet/remembered choices retained |
| `samples` | 2 | Initial sampled worlds shared by root alternatives |
| `budget_ms` | 400 | Whole-decision time allowance; 0 disables the timer for deterministic tests |
| `node_budget` | 1500 | Maximum simulated submissions |
| `sequence_depth` | 6 | Maximum branching depth reached by iterative deepening |
| `branch_width` | 3 | Own continuation alternatives, plus quiet |
| `response_width` | 2 | Ranked opponent alternatives, plus quiet |
| `rollout_steps` | 4 | Greedy continuation length at search leaves |
| `settle_steps` | 8 | Extra allowance for unresolved exchanges |
| `max_steps` | 80 | Main path limit, with bounded settling at leaves |
| `intent_margin` | 0.15 | Near-tie tolerance for an independently evaluated plan hint |
| `cache` | false | Exact, search-local transposition caching |

Hard raises candidate capacity to 8, samples to 3, time to 1600 ms, submissions to 6000, depth to 10 and own width to 4. Easy uses the same planner with 80 ms, one sample, 300 submissions, depth 2, three root candidates and noisy scoring. Difficulty settings still layer over each deck's strategic profile. All shipped difficulty levels and ordinary simulation/diagnostic entry points now default to sequence planning; scorer-only and historical rollout policies require explicit selection. Pregame Reserve decisions retain the specialized `AiReserve` valuation.

## Diagnostics and verification

`AiEvaluator.explain(sim, seat, profile)` returns signed named contributions and a total equal to ordinary evaluation. `search.metrics.position` contains the initial position breakdown. `last_report` contains the completed candidate scores, common sample count, completed depth and representative line. A line is a hypothetical continuation, not a guaranteed command script or a full contingent strategy tree.

Metrics include submission count, elapsed time, cutoff reason, simulated pivot states, cache hits, unsettled/terminal leaves, rejected candidates and intent status. The arena reports median/p95/max decision latency, completed depth and scorer fallbacks, alongside wins, unfinished games and per-deck results. Its `--report` flag writes a machine-readable summary.

Run these with the Godot 4.6 executable from the repository README:

```text
--headless --path zenith -s tests/run_tests.gd
--headless --path zenith -s tests/ai_routing_tests.gd
--headless --path zenith -s tests/ai_strategy_tests.gd -- --budget-ms=400 --samples=2
--headless --path zenith -s tests/ai_feature_tests.gd
--headless --path zenith -s tests/ai_information_tests.gd
--headless --path zenith -s tests/ai_arena.gd -- --a=search --b=rollout --decks=steel_beatdown,tide_companions --seeds=2 --budget=400 --samples=2
```

Strategy puzzles execute the full tutor/Bond chain; preserve scarce pieces; choose a lower-Might winning controller; abandon a disrupted plan; defend against immediate loss; and verify simulated profile transitions. A dedicated sequencing puzzle establishes that the scorer chooses an inferior attack both initially and after the first setup action, while recursive search executes two setup actions and then wins.

The simultaneous-keep regression also answers the second player's pending decision first. Simulated commands resolve against their own player's prompt, so simultaneous decisions do not silently fall back to the scorer.

Recorded checks: engine suite 2,834; strategy puzzles 124 at 400 ms/two samples; feature tests 25; information consistency 18; existing UI smoke 113. All passed. The environment prints an unrelated certificate-store warning during headless startup.

Core-routing follow-up: 85 routing checks cover every shipped deck and difficulty, default simulation settings, explicit comparison policies, and actual Session → DuelHost → AiPlayer decisions. These pass alongside the 2,834 engine checks and 124 strategy checks. The Easy planner also completed a two-game arena smoke at its shipped 80 ms budget; this verifies legal integration, not relative playing strength. Tournament, ally-probe, trace and matchlab entry points passed small-budget smoke runs.

The [normal arena report](ai_strategy_benchmark_normal.json) covers both seats, two seeds and all four pairings of Steel beatdown and Tide companions: 16 completed games, no illegal commands or unfinished games. Sequence search won 11/16 against the historical rollout baseline. Its per-deck results were 8/8 for Steel and 3/8 for Tide; the aggregate should not be read as proof that ally piloting is solved. Both policies requested 400 ms and two samples, but actual average decision times differed: about 374 ms for sequence versus 190 ms for rollout. Sequence median/p95/max were 406/416/434 ms; the baseline's were 158/500/754 ms. The new search completed about 1.14 branching levels per measured decision on average and used scorer fallback 70 times. Tiny scenarios can reach much deeper than full-deck positions under the same timer.

The [strategic arena report](ai_strategy_benchmark_strategic.json) adds eight completed games across both seats and all pairings of Root Seals and Shade henchmen, at the same configured budget and sample count. Search won 6/8, including an Unsealing victory, with no illegal commands or unfinished games. Each deck won 3/4 as the search policy. Search median/p95/max were 407/414/429 ms. Together the two reports record 17/24 wins, across four decks; they do not constitute an exhaustive matchup study.

The historical rollout baseline shares the current scorer, evaluator and fair sampler. Comparisons therefore isolate search behavior rather than reproduce the old executable exactly. Small arena runs are integration evidence, not proof of superiority across every archetype. No neural training or learned opponent model is required for this implementation; those remain possible later developments if measured failures warrant them.

A subsequent [weak-deck comparison](deck_ai_comparison.md) tests the four lowest-ranked decks from the latest full tournament against all ten opposing decks. Across 160 paired games at Normal's budget, the planner won 24/80 target appearances versus the current scorer's 25/80. Steel Heir and Pyre Ascent each gained one net win; Tide Companions lost two and Shade Salvage lost one. This limits the earlier positive arena result: the planner is integrated, but improved strategic piloting is not established across the weak decks. The paired runner and selective tournament policy flags preserve these cases for further diagnosis.
