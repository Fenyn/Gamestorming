# AI strategy review

Reviewed 2026-09-19. This is a source review and implementation proposal, not a benchmark or an AI behavior change. Profiles, engine code, and strategy documentation are also being edited in the shared workspace; observations refer to the files inspected on this date.

## Recommendation

Keep the legal-prompt interface, simulation boundary, and data-driven profiles. Add bounded search over action sequences, an evaluator that recognizes usable combinations, and persistent but interruptible strategic intent. Increasing the existing rollout budget alone will not address the main limitations.

## What exists and why complex decks struggle

The path is `AiPlayer.choose` → `AiSearch.choose` → `AiScorer` continuations → `AiEvaluator.evaluate`. Reserve choices use `AiReserve` separately. Simulations originate at `Referee.sim_for`.

1. **Only the first decision branches.** `ai/ai_search.gd` shortlists root options and simulates each, but `_playout` then picks one greedy continuation at every prompt. More sampled deals improve estimates of those continuations, not discovery of alternative follow-ups. A setup card can lose because the continuation spends its payoff incorrectly. Default search keeps six leading options plus a quiet option, samples up to six deals, and normally runs through the current turn. Tide already requests three turns. That extends the same greedy policy.

2. **Setup can disappear before simulation.** `_shortlist` preserves the highest immediate scores and one quiet option. It does not preserve coverage of tutors, enablers, protection, or resource-conversion actions. Eight similar attacks can crowd out an important setup choice even on hard difficulty.

3. **Tutor support exists, but it prices reachability rather than an executable chain.** `AiScorer.TUTOR_DEPTH` is three. `_tutor_value` recursively values the best reachable card with a profile discount; `_combo_value` specifically recognizes Bond relationships from data. However, recursive valuation does not submit those intermediate plays. It does not advance zones, spend costs, or validate the entire sequence. `_searching_effects` collects searches across triggers and conditional branches, including `else_effects`, and reads personality power data from aspect 1. These are useful optimistic hints, not evidence that the route can execute now. Recursion depth bounds cycles but does not make the imagined route legal.

4. **Action scoring and position scoring disagree about strategic value.** `AiEvaluator.side_value` gives hand cards a count-based value and allies a flat value plus Energy. It has useful special terms for Ascension, Seals, Grounds and ally handover, but no general value for a missing combo piece, a reusable power, or an enabled sequence. Bonding consumes two allies to make one. The material-count term drops even when the new ally has much greater strategic value; other terms may compensate, but the evaluator does not directly measure that payoff. Similar trouble applies to sacrificing material to establish an engine.

5. **State-dependent strategy freezes inside a rollout.** `AiPlayer._matchup_profile` resolves `when` conditions at the real decision. `_playout` reuses that resolved profile throughout its hypothetical future. A simulated Bond therefore does not enable Tide's `when.bonded` aggression pivot. The real AI will pivot on its next decision, but its prediction of its own future behavior does not. Simply overlaying new pivots on the already-resolved profile would also be wrong when a condition stops holding; each simulated state needs resolution from the unpivoted matchup base.

6. **Some decisions discard the contextual values already available.** Discard and keep choices use `hold_value`, while tutor choices use `card_value`, which includes combo context. Control primarily uses Might band and a profile bias. A controller's available power, expended resources, protection role, and contribution to the rest of the sequence deserve consideration together.

7. **Tests establish local preferences more than strategy execution.** `test_ai_follows_a_tutor_chain` checks that recursive tutor valuation rises and remains below the payoff's valuation. It does not make the AI execute a chain against competing plays and disruption. Existing arena and trace tools are valuable infrastructure for extending this coverage.

These are architectural explanations for the reported behavior, not measured claims about how frequently each failure occurs. The historical measurements in `strategy.md` should not be treated as a fresh baseline.

## External systems worth studying

| System | Verified approach | Lesson for Zenith |
| --- | --- | --- |
| Original Hearthstone AI, Blizzard's 2014 postmortem | Uses player options and simple scoring; aims at intermediate play; two-card kills were the only preplanned combinations. | Preserve shared legal actions and deliberate difficulty design. This historical bot is not evidence of a general combo planner. [Developer slides, slide 8](https://media.gdcvault.com/GDC2014/Presentations/Brian_Schwab_AI_Postmortem_Hearthstone.pdf). |
| Silverfish, a third-party Hearthstone AI | `MiniSimulator` expands successive moves, limits depth and width, scores retained boards, and can remove equivalent states. | A bounded beam of alternative sequences is a practical next step from Zenith's single greedy continuation. It still needs good evaluation to retain slow setup lines. [Source](https://github.com/noHero123/silverfish/blob/master/ai/MiniSimulator.cs). |
| Forge, an independent Magic implementation | Its simulation subsystem tracks a best sequence, recurses with a depth limit, and combines target, mode, and card choices with their parent actions into a plan. | Treat casting, tutoring, choosing, and following up as connected decisions. This describes the inspected subsystem, not every Forge AI path. [Source](https://github.com/Card-Forge/forge/blob/master/forge-ai/src/main/java/forge/ai/simulation/SimulationController.java). |
| MTG Arena | Wizards documents a rules engine that builds legal actions and applies card-specific rule modifications. | Zenith already has the right separation between rules and decision-making. This article does not document Sparky's strategy algorithm, and this review did not locate a primary technical account sufficient to characterize it. [Wizards engineering article](https://magic.wizards.com/en/news/mtg-arena/on-whiteboards-naps-and-living-breakthrough). |
| Dominion and Race for the Galaxy, Temple Gates | The developer describes learned position evaluation and opponent prediction for Race, and neural-network-guided MCTS with reinforcement learning for Dominion's longer-term strategies. | Long-term state evaluation matters alongside search. Consider a learned evaluator after acquiring reliable training data and a strong benchmark. Their reported performance does not predict Zenith performance. [Developer article](https://www.templegatesgames.com/dominion-ai/). |

Hearthstone research also separates high-level card actions from dependent target choices and studies learned rollout policies. That supports improving continuation quality and structuring compound choices, rather than assuming that adding MCTS alone solves strategy. This is research AI, not Blizzard's implementation. [Zhang et al., Improving Hearthstone AI by Learning High-Level Rollout Policies](https://jakubkowalski.tech/Projects/LOCM/literature/Zhang2017ImprovingHearthstone.pdf).

## Proposed architecture

### 1. Shared strategic features

Extract facts from card mechanics and the current permitted state: available searches and destinations, enabling conditions, reusable powers, resource conversions, protection, reachable payoffs, missing pieces, and action availability. Reuse these facts in move ordering, discard decisions, and position evaluation so they agree about why a card matters.

Value the *marginal contribution* of a piece to a reachable plan. A duplicate or an inaccessible payoff should not earn the same bonus as the last missing piece. Account for the Life Deck as both health and future access. A tutor route also has costs in actions, Energy, timing, and exposure to disruption.

Keep card and deck names out of AI logic. Derive dependencies from effects, filters, and existing relationships. Use generic declarative hints only where the mechanics do not express strategic intent clearly enough. The engine remains the authority on whether an action or condition actually works.

### 2. Bounded sequence search

Start with beam search: expand several continuations, keep a limited number of promising distinct states, and repeat. Retain some candidate capacity for different strategic roles, rather than letting minor attack variants fill the beam. This is a proposal, not a claim that a particular width or depth will meet the frame budget.

Resolve an action's forced bookkeeping without charging each automatic transition as a strategic decision. Still branch on meaningful targets, tutor selections, and response choices. Never skip an opponent's legal response window. Use a few plausible opponent continuations, with tactical search at critical defenses, instead of assuming one generic reply is sufficient.

Evaluate at meaningful decision boundaries. The current step cap can stop a rollout during a partly resolved exchange. Add bounded extensions for those exchanges, plus explicit handling and logging when evaluation still occurs at a truncated state.

Refresh state-dependent policy as the simulated board changes, while keeping leaf values comparable across candidate lines. Do not reward a branch merely for switching to a more generous scale of weights.

Reuse equivalent states only when their keys include all rules-relevant information: pending decisions/effects, once-per-turn usage, controller, zones, random state and relevant history. Similar-looking boards are not necessarily equivalent.

### 3. Carry intent between prompts

Remember a small set of current goals, selected targets, and expected enabling conditions. For example, assemble a Bond, retain protection, reach ally control, then use the ally's available attacks. Each subsequent prompt validates the intended step against its legal options.

Replan on new information, disruption, or a better immediate opportunity. Intent should help the AI keep a tutor target or conserve a scarce piece without forcing a stale script when survival or a win takes priority. Store references to legal options and observable facts, not commands that bypass prompts.

### 4. Improve uncertainty and efficiency

Keep common sampled deals across competing root actions. Audit the knowledge model before deepening search: `determinize` shuffles the actual hidden card multiset, which hides placement but retains composition. Establish whether opposing deck contents are public in each mode. If not, sample composition from permitted information rather than the authoritative hidden pool.

Do not let a future simulated decision adapt to a hidden card the acting player could not have observed. Searching each imagined world independently can overvalue plans that require such knowledge. Observation-consistent decisions and explicit beliefs are necessary as search becomes deeper.

The current deadline is checked after a complete sample round and excludes initial scoring. Measure the whole decision, add internal budget checks, and compare candidates with balanced completed work. Use deterministic node/sample budgets for regression tests and wall-clock limits for gameplay. Search-local caches are preferable to adding more shared mutable scorer state, especially if simulation becomes concurrent.

## Implementation order and acceptance

1. **Reproduce and instrument.** Add scenarios for a two-tutor chain with a distracting attack, a low-value first move enabling a payoff, preserving the only combo piece during discard, choosing control for its power, and abandoning a disrupted plan. Include versions where setup is wrong because a loss is imminent. Log rejected candidates, rollout traces, evaluation terms and cutoff reasons.
2. **Align evaluation and continuation.** Resolve simulated strategy pivots correctly and share contextual card value across tutor/keep/discard decisions. Add feasible combo progress and usable ally power to leaf evaluation without double-counting payoff and pieces.
3. **Add bounded sequence planning.** Introduce diverse candidates, real continuation branching, safe state reuse, and revalidated intent. Keep the existing scorer as a baseline and fallback.
4. **Tune or learn only against evidence.** Run `tests/ai_arena.gd` with both seats, multiple seeds and equal compute budgets. Report results per archetype, paired win rates, uncertainty, scenario completion, illegal actions, unfinished games, and median/p95/max decision latency. Separate engine correctness and deck strength from piloting ability. Consider learned weights/value models and information-set MCTS if the remaining failures justify them.

The first implementation slice should make the tutor/ally scenarios pass and preserve beatdown performance before expanding to every archetype. It should not require a card-specific hardcoded sequence to pass.
