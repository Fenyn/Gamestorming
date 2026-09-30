# Eidolarch: Adventure Mode

Single-player run mode for `zenith`. Drafted 2026-09-20, folded into one current document on
2026-09-23. Each section says what is built and what is design only.

A run starts from a hand-authored starter deck of one character and rebuilds it. The starter is
50 Life Deck cards (Root 55) with its Mastery and two or three Aspects. You duel your way through
a run, taking a bundle of cards after each win, and pay Motes at the end to keep what you want in
a permanent collection. Since 2026-09-23 a run is that character's story, played on a node map in
three acts and ending against Halden Quarr (section 7).

**Rules baseline:** unchanged from `zenith.md`, with two adventure-only rules: the lives rule
(section 12) and the lower deck floor in `DeckValidator` (section 9). Every reward is an existing
system: cards, Aspects, Relics, Reserve cards, Grounds.

---

## 1. Why the Life Deck carries the mode

The Life Deck is the health total. That one fact supplies the roguelite tension without inventing
anything, and it runs opposite to Slay the Spire:

- Adding a card raises effective health and dilutes draws.
- Removing a card sharpens draws and lowers health.

In Slay the Spire removal is almost always correct, which is a known flatness in its economy.
Here it is a real trade every time. More endurance and more dilution on the same slider. No
separate health bar, no healing item.

A run's deck grows only up to a size cap. The cap starts at the starter's size plus the deck slots
bought with Motes (section 8.2), and per-run boosts raise it further during the run, up to a
limit. Early runs are limited in size, and the full 85 comes only after upgrades. Cards won past
the cap wait in the run library (section 4.7).

---

## 2. Reference games

| Game | Structure | What was taken |
|---|---|---|
| DBZ CCG (GBA, 2002) | Rank ladder, 12 opponents, random card drops | Difficulty as deck size and Mastery access rather than stats. Refightable opponents. Finish with one character to unlock another |
| Pokémon TCG (GBC) | 8 club leaders, then Grand Masters | Collection grows, deck size does not. Each opponent teaches one counter-strategy |
| Soul Calibur 1 and 2 | Arcade story per character, Mission Battle and Weapon Master maps | A fixed rival and boss per character. Duels under stated rules. Missions that unlock characters, variants and a gallery |
| Slay the Spire 1 | 3 acts, branching map, relics, card removal | Node-type variety on one map. A forced relic pick. Relics as the real power curve |
| Slay the Spire 2 | Two act choices per stage, Enchantments | Persistent per-run card modifiers |
| Monster Train | Clan pairing, Covenant ladder | Difficulty ladder after first clear |
| Griftlands | Persistent NPCs | Opponents who return stronger within a run |

What the GBA game got right: the first opponent runs a 52-card deck with no Mastery, the late
villains run 74 with one. Difficulty was deck size and Mastery access. The final boss gets a
stated rule exemption printed on screen rather than a stat bump.

What it got wrong: batches of ten random cards after every win, of which three or four are
useful. Adventure mode offers a choice of three bundles instead.

---

## 3. The starter

### 3.1 How a starter is made

Starters are **separate hand-authored files**. Nothing reads across from `data/decks/` at
runtime, so the precons can be rebalanced for multiplayer without moving a starter. Every
multiplayer mode uses the full precons.

```
data/decks/                       the 14 full precons, multiplayer only
data/adventure/
  starters/<deck_id>_start.json   50-card starter (Root 55), same DeckList schema
  opponents/<deck_id>_<tier>.json opponent tiers t1 to t5 and boss (section 6.6)
  map.json                        node map shape and opponent strength per act (section 7.1)
  opponent_bands.json             weaker, medium, stronger opponent families
  bundles.json                    reward bundles (section 4.1)
  economy.json                    Motes prices and payouts (section 8.2)
user://adventure/
  run.json                        the run in flight
  wallet.json, collection.json, upgrades.json   meta state (section 8)
```

Starters use the existing schema so `DeckList` and `CardLibrary` load them unchanged, plus
`source_deck`, `difficulty` (easy, medium, hard) and `cleared` (mean stages cleared in the
adventure lab, which drives the pips on the roster tile).

### 3.2 Starter standards

Set 2026-09-21. The per-deck reasoning lives in `zenith/docs/adventure_starters.md`, whose
per-deck notes still describe the older 40-card builds.

- **Size.** 50 Life Deck cards, Root 55. No house copy cap: the printed limits apply.
- **Aspects.** Two, except the five setup decks (Steel Heir, Shade Salvage, Tide Companions,
  Storm Unbound, Root Seals), which start with three.
- **The Mastery is never stripped.** It is the anchor of the precon and the deck does not work
  without it.
- **Stop floor by archetype**, a minimum: most aggressive 8 (`pyre_beatdown`), beatdown 10
  (`steel_beatdown`, `shade_mind_siege`, `steel_heir`), midrange 12 (`pyre_attrition`,
  `freestyle_swords`, `tide_deepwater`, `shade_henchmen`), control and setup 14 (`pyre_ascent`,
  `storm_volley`, `storm_unbound`, `shade_salvage`, `tide_companions`, `root_seals`).
- **About a third of the stops are stop-any**, so Focused attacks matter.
- **The rest is built around the deck's plan**, reinforcing its school and its Duelist's own
  signature cards. The precon is a guideline. Padding from any legal card is fine where it fills
  a need.
- **One or two bombs.** Any non-personality, non-Seal card printed at `limit_per_deck` 1 counts.
- **No lockouts** (section 6.4). `shade_salvage` may hold a few.
- **No Grounds, and no Relic or Reserve**, except `tide_companions`, which carries `debtors_ring`
  and the precon's five-card Reserve so its Bond card can be reached.

### 3.3 Protected cores

The rule is **does removing a copy turn the plan off, or turn it down**.

- **Binary win conditions are protected whole.** Root starts with all seven Marble Seals or Root
  has no deck.
- **Scalar win conditions are rationed.** Four companions beats two, but two still plays.

Only `root_seals` holds a complete Seal set, so the Unsealing route is effectively Root's alone.

### 3.4 Starting Allies

Fixed per deck, not randomised. As in the starter files on 2026-09-23:

| Starter | Allies |
|---|---|
| tide_companions | Tavin Vale, Ansel Rooke, Wren Rooke, Sir Edric Rooke |
| shade_salvage | Cull, Orvath Kell, Gideon Mourne (Mercenary), Pim |
| storm_unbound | Cull, Orvath Kell, Pim |
| shade_henchmen | Vesna Draik, Brann Draik, Halvard Draik |
| pyre_ascent | Dame Alder Rooke |
| steel_heir | Dame Alder Rooke |
| storm_volley | Tithe |

Tide carries Tavin and Ansel because they are the pair `personality_ansel_and_tavin_1_back_to_back`
fuses, and the Bond is the deck's lever.

### 3.5 Starter strength

`docs/balance_2026-09-22.md`, scorer AI, 10 lab runs per starter. Mean stages cleared of 8:
steel_beatdown 6.5, pyre_attrition 6.0, shade_mind_siege 5.8, tide_deepwater 5.6,
storm_volley 5.2, shade_salvage 5.2, pyre_ascent 5.2, tide_companions 5.1, steel_heir 5.1,
storm_unbound 4.9, pyre_beatdown 4.8, freestyle_swords 4.6, root_seals 4.5, shade_henchmen 4.4.

Starters are not balanced against each other and do not need to be, since the player never faces
another starter. What matters is each starter against its own run.

---

## 4. Rewards

### 4.1 Theme bundles

**Built 2026-09-21** (`adventure/adventure_bundles.gd`, `adventure/adventure_rewards.gd`).

After every won duel the player picks one of three **theme bundles**: 2 or 3 cards that share a
theme, shown with their cards visible. Or they skip and cut a card instead (section 4.3).

- 147 bundles in `data/adventure/bundles.json`, transcribed from `zenith/docs/archetypes.md`
  section 5: 12 Pyre, 15 Steel, 13 Tide, 15 Storm, 15 Root, 13 Shade, 29 Freestyle, 7 Grounds,
  12 Ally, 16 signature. Each carries `group`, `tier`, its cards with counts, and a `character`
  (Ally core and signature) or `requires_character` (Ally follow-up).
- Bundles may hold any card legal in the run deck: school cards, Freestyle cards, Allies and
  Grounds. Masteries and Relics stay out. **Freestyle is a school like any other, only shared.**
- **An Ally always arrives with two of its own named cards.** An Ally's named cards are offered
  only in that bundle or once the Ally is in the run deck. An Ally with fewer than two named cards
  cannot be bundled yet.
- **No Seals through the bundle choice.**
- Tier gates by how far through the map the won duel stood (`AdventureMap.progress_of`):
  `early` from the start, `mid` from a quarter of the way (act 1 tier 7), `late` from halfway
  (act 2 tier 5).
- Every offer holds one bundle of the run's own school whenever one is eligible. No offer holds
  more than two bundles of one group. A bundle already taken is never offered again.
- **Legality is the hard gate.** All of a bundle's cards are added together to a copy of the run
  deck and passed through `DeckValidator`, and one problem drops the whole bundle.
  Alignment-gated cards (`alignment_only`) are filtered in the reward layer, because
  `DeckValidator` reads that field on personalities only.
- Offers are seeded per stage and saved with the run, so a reload shows the same three.

### 4.2 Reserve bundles

Decided 2026-09-23. The Relic node's sets built 2026-09-29 (`data/adventure/reserve_bundles.json`,
`adventure/adventure_reserve_bundles.gd`, `adventure/adventure_relic.gd`). Reserve bundles on
reward screens are not built yet.

- Reward screens can offer **Reserve bundles** as an option pack beside the ordinary bundles. A
  Reserve bundle's cards go into the Reserve, not the Life Deck. A Reserve exists only once the
  run has a Relic (section 7.5).
- **Reserve bundles hold counter tech:** specific removal and answers to deck types, which the
  player swaps in once the next opponent is known. Lockouts are not counter tech. They are usually
  main-deck staples and stay in the ordinary bundles. No signature cards either.
- 32 sets: Pyre 3, Steel 4, Tide 5, Storm 5, Shade 5, Root 6, Freestyle 4. Each has a `group`
  (a school or `freestyle`), a name, the opponent type it answers, and is **modular**: fixed
  **key** cards that define the answer (usually 2 or 3), plus **fill** slots drawn at random from a
  curated candidate list, 5 cards in all. A candidate may be drawn again up to its copy limit.
  Steel's fourth set holds Locking Jaws (`steel_strike_01`, Reserve only) as its one key card.
- **Legality.** "Fits" means DeckValidator on the run deck with the set added to the current
  Reserve, counting every problem except the Reserve's size (copy limits across Life Deck and
  Reserve, style, Reserve-only), plus each card's own gates (`alignment_only`, `only`, including
  `duelist_character`). No card is ever offered past its copy limit.
  - If any key card, or any copy of one, does not fit, the **whole set is not offered**. A run
    that already holds Locking Jaws never sees the Locking Jaws set.
  - Fill is drawn one card at a time from the candidates that still fit after the key cards and
    the fill already drawn, so a fill card that would break a rule is never drawn and a legal one
    takes its place.
  - A set whose fill candidates run dry is offered short of 5, as long as all its key cards are
    there.
- The draw is seeded from the Relic node's seed and the set id, and the resolved card list is
  saved with the offer, so a reload shows the same cards.
- Theme reward offers never see these sets; they live in their own file.

### 4.3 Cuts

The cut is on every reward screen: skip the bundle and remove one card instead. It is the only way
the deck gets smaller, and with the deck as the life total it is always a real trade. Built
(`AdventureRewards.can_cut`, `apply_cut`).

### 4.4 Aspects

Superseded 2026-09-24 by section 8.6. A duel with `"grant": "aspect"` (act 1 and act 2 bosses)
offers only the next-tier Aspect cards of the Duelist's character that the player owns. With none
owned, the grant is skipped. Aspect tiers are no longer bought with Motes, and opponents are not
capped at the player's Aspect count.

### 4.5 Grounds

Seven exist: `trampled_crossroads`, `ancient_grove`, `tollgate_yard`, `frostbound_moor`,
`weighted_hollow`, `the_high_watch`, `the_marked_ring`. All schoolless and limit 3.

- Grounds are completely optional cards. Starters ship with none.
- They arrive as a **block of 3** through the Grounds bundles, never as singles. A single copy is
  nearly blank.
- Because they are schoolless they are the one reward line shared by every deck.
- Their JSON carries no `text`; `card_text.gd` renders them from `effects`, `modifiers` and
  `forbid`. A Grounds with a `forbid` entry is a bomb and belongs late.

### 4.6 Pool expansion

Decided 2026-09-20. The school pools were too thin for bundles.

- Fill gaps first. `zenith/docs/archetypes.md` names what each school lacks by type and theme.
  Every school comes up to roughly 35 to 40 cards, thin schools first.
- Every new card parallels one printed card from the reference game's era, later sets included.
  The rule in `zenith/CLAUDE.md` is unchanged.
- Candidates go into `zenith/tools/source_candidates.tsv` with a status (candidate, approved,
  built). `docs/card_roster.csv` is rebuilt from shipped data by `tools/gen_roster.py`, so
  candidates cannot live there.
- Names are drafted per school and approved before the cards are written.
- New cards join the whole game's pool, not only adventure rewards.

Storm and Root were filled on 2026-09-21 (Storm 39, Root 38). The second batch, for Pyre, Steel,
Tide and Shade, is in `zenith/docs/expansion_batch2_review.md`.

### 4.7 The run library

Decided 2026-09-23. Library and Reserve screen built 2026-09-29 (`AdventureRun.library`,
`adventure/adventure_reserve.gd`, `scenes/adventure/library.tscn`).

- Every run keeps a **run library**: the cards it has won that are not in the Life Deck or the
  Reserve. It is saved with the run. Cards set aside from the Reserve go there; nothing is
  destroyed.
- Between nodes the player can move cards between the Life Deck, the library and the Reserve, if
  the run has one. Every move is checked by `DeckValidator`, and any move that would add a new
  problem is refused.
  - Reserve to library, and library to Reserve, are free single moves. Library to Reserve only
    while the Reserve is under its Relic's size, and never without a Relic.
  - The Life Deck only **swaps one for one** with the Reserve or the library, since the deck's size
    changes only at nodes. A swap that puts a Reserve-only card in the Life Deck, or a card past
    its copy limit, is refused.
  - While the player is setting cards aside after a Relic (7.5), the over-full Reserve is the one
    problem allowed to stand, and the screen can be left only once DeckValidator passes whole.
- The Reserve screen is the map's **View Deck** button, and opens by itself after a Relic leaves
  the Reserve over its size. Life Deck strips on the left, the Reserve under its Relic in the
  middle, the library on the right. A Reserve card clicked goes to the library, a library card to
  the Reserve when there is room; a Life Deck strip clicked is picked, and the next Reserve or
  library card clicked trades places with it. Dragging onto a card in another pile swaps; onto an
  empty part of the Reserve or library moves.
- A won card that does not fit under the deck's size cap goes to the library. Not built: it waits
  on the size cap (build plan 2.6).

---

## 5. Ranking card power

Not built. Prices use a printed tell in three bands instead (section 8.2). Needed for reward
weighting, for Motes prices, and for deciding what a scaled opponent keeps.

### 5.1 The printed tell

`limit_per_deck` is the strongest signal already in the data. A card printed at limit 1 or 2 is a
card a designer already judged too strong at three copies. Combined with `remove_after_use`,
limit 1 plus remove-after-use is nearly a bomb detector with no tuning at all.

### 5.2 Heuristic

Scored from `CardDef` fields, descending weight:

| Signal | Field |
|---|---|
| Lockouts and standing bans | `forbid` |
| Unstoppable or unpreventable attacks | `attack.unstoppable`, `attack.no_prevent` |
| Multi-use in one combat | `remain`, `remain_when` |
| Universal defense | `defense.stops == "any"`, `stop_focused` |
| Free resilience | `shield` on drills, `start_in_play` |
| Response capability | `counter == "combat"` |
| Output per cost | `attack.life`, `attack.stages` against `cost_stages`, `cost_life` |
| Broad static buffs | `modifiers` with no `when` |
| Tempo swings | `effects` ops touching fervor, aspect, energy, search, draw |
| Self-limiting | `remove_after_use`, `bottom_after_use`, as negative terms |

Stages count as pseudo damage when ranking. Four tiers: tiers 1 and 2 are starter-eligible, tier
3 is mid-run reward, tier 4 is late reward.

### 5.3 Validate against the sim

A field heuristic will misrank cards whose power is contextual. Ablation gives the real answer:
run a deck at baseline, swap one card for a filler basic, rerun, and take the win-rate delta as
that card's measured power. Use the heuristic to bucket everything and spend sim time only on the
top and bottom buckets.

---

## 6. Opponent decks

Opponents are generated from the precons; starters are not (section 3.1). `tools/scale_deck.py`
takes a precon and a target size and returns a coherent deck at that size.

### 6.1 Method

1. **Expand into slots.** A card at count 3 contributes three slots.
2. **Drop what adventure decks never hold.** Grounds, and Allies outside the deck's kept pair.
3. **Rank the slots**: core first (Seals, kept Allies), copy 1 of everything before any copy 2,
   the precon's own workhorses, weakest first so bombs land last. Energy damage counts at the same
   weight as life damage.
4. **Fill to target with role quotas** taken from the precon's own ratios, across offense,
   answers and support. Any card with a `defense` block is an answer.

### 6.2 Why it is built this way

**Monotone by construction.** Each tier is built by adding to the one below, so a tier-2 opponent
is a superset of a tier-1 one and the full precon is the end of the line.

**Weakest first is the right direction.** A small deck is basics with no bombs. Bombs appear only
as the size climbs, which is also why they are reward content: the player meets them before they
own them.

**Role quotas stop drift.** Without them, culling by score alone strips a beatdown deck of its few
answers. Holding the precon's own ratios keeps a scaled deck a smaller version of that deck.

### 6.3 No lockouts in small decks

A starter or low-tier opponent holds no card that turns off a whole card type. `tools/scale_deck.py`
filters them by field (`is_lockout`):

| Marker | What it is |
|---|---|
| `defense.stop_all` | stops every attack, or every attack of a kind, for the Combat |
| card-level `forbid` | a standing ban while the card is in play |
| op `stop_all` | the same as a rider on another card |
| op `forbid`, `choose_forbid_type` | "may not use X for the remainder of Combat" |
| op `choose_stop_all_kind` | choose Strikes or Arts, all of them stop |
| op `cannot_declare_combat`, `skip_next_attack_phase` | a lost turn or phase |
| op `name_card` | neither player may play the named card |

Seals are exempt. Lockouts stay in the precons, so t3 and later opponents run them, and they are
reward content in the ordinary bundles.

### 6.4 Opponent tiers

Six tiers in `data/adventure/opponents/`, 84 decks, all legal. Regenerated 2026-09-22 to the
starter standards: no copy cap, a stop floor per family at 50 cards scaled by size below 50,
about a third stop-any where the precon has them.

| Tier | Size | Lockouts | Aspects | Relic |
|---|---|---|---|---|
| t1 | 40 | no | 2 | no |
| t2 | 48 | no | 2 | no |
| t3 | 56 | yes | 3 | no |
| t4 | 64 | yes | 3 | no |
| t5 | 72 | yes | 3 | no |
| boss | full precon | yes | precon | yes |

Every deck keeps its Mastery at every tier. The adventure card floor is 30 (section 9).

### 6.5 Measured: small decks favour aggression

2026-09-20, `pyre_beatdown` against `storm_volley`, 80 matches per configuration:

| Configuration | Pyre win% | Turns |
|---|---|---|
| Full precons, 78 and 80 cards | 62.5% | 6.5 |
| Both starters at 40 | 77.5% | 3.4 |
| Both at 50 | 81.3% | 3.7 |
| Pyre 40 against Storm 50 | 67.5% | 3.7 |

Life Deck is health, so a smaller deck is a shorter duel. **Short duels favour archetypes whose
plan works on turn one and punish archetypes that need setup.** This is why the setup starters
start with a third Aspect and why the lives rule (section 12) was added.

### 6.6 Measured: size is a weak dial, deck identity is a strong one

2026-09-20, one starter against the tiers of `steel_beatdown`: t1 50.0%, t2 29.2%, t3 27.1%,
t5 20.8%. The same starter against four weak decks at t1: 91.7% to 97.9%.

**Shrinking an aggressive deck barely weakens it**, since it keeps its tempo and loses only its
endurance. **Deck identity swings harder than any tier.** So difficulty is set by which family
sits in which band (section 7.8), not by tier alone.

The latest opponent standings (`docs/balance_2026-09-22.md`, all tiers): steel_beatdown 89%,
shade_mind_siege 79%, pyre_attrition 79%, freestyle_swords 78%, pyre_beatdown 65%, root_seals
54%, shade_henchmen 48%, tide_deepwater 44%, storm_unbound 38%, storm_volley 36%,
pyre_ascent 29%, steel_heir 23%, tide_companions 21%, shade_salvage 18%.

---

## 7. The run

Decided 2026-09-23. Sections 7.1 to 7.7 are the design; section 7.8 is what is built today.

The model is the story and mission modes of the early Soul Calibur games, and the PS1-era habit
of playing one character to unlock the characters tied to them. The ally and nemesis links
between characters, and the lore behind them, are being written separately and feed sections 7.2
and 8.3.

### 7.1 A run is one character's story

- A run is played on a node map in the style of Slay the Spire, in **three acts of 8 tiers
  each**. Tier 8 of every act is a single boss node. Tiers 1 to 7 hold nodes joined by random
  connections, drawn per run, so the route to the boss differs every time.
- **Every path through tiers 1 to 7 of an act holds 2 to 5 duels**, not counting the boss, so an
  act is 3 to 6 duels and a run 9 to 18. Combat is the main part of the game, so a path with only
  2 duels should be rare; most paths hold 3 or 4. Every fighting node counts as a duel: Duel,
  Elite, Twist, Encounter and Key character.
- The act 1 and act 2 bosses are set per storyline starter (section 8.8); other starters draw
  them at random.
- **Opponent strength by act**, set 2026-09-23:

  | Act | Ordinary duels | Boss | Duel band | AI |
  |---|---|---|---|---|
  | 1 | t1, then t2 from tier 5 | t3 | weaker | easy |
  | 2 | t3, then t4 from tier 5 | t5 | medium | default |
  | 3 | t4, then t5 from tier 5 | Quarr, `steel_beatdown_boss` | medium | default |

  An Elite draws from one band stronger than a duel; every boss draws from the stronger band.
- **Aspect grants:** after the act 1 and act 2 bosses, and only from Aspect cards the player owns
  (section 8.6).
- The Relic node fills the whole of tier 3 of act 1, so every path meets it.
- The **final boss of every run is Halden Quarr** with `steel_beatdown`, at tier 8 of act 3. He
  wears the Lodestone Heart, the stone every storyline is after (`zenith/docs/cast.md`), and the
  Heart's Relic flags are his printed exemption. Gate bosses carry one stated
  rule exemption printed on screen, in place of inflated numbers.
- **Key characters.** A node type for meetings with characters the story or a quest wants the
  player to reach. It replaces the earlier idea of a fixed Rival and Nemesis. Until the character
  links exist, a key character is a random opponent.
- Every duel starts at full strength with the whole Life Deck shuffled. **No persistent wounds.
  No rest or heal node.** Cards lost in a duel come back for the next one.
- After every won duel: the bundle pick or a cut (section 4).

### 7.2 Node types

| Node | What it is |
|---|---|
| Duel | An ordinary fight |
| Elite | A fight from a stronger band, for a better reward |
| Key character | A meeting the story or a quest wants the player to reach (7.1) |
| Boss | Tier 8 of each act. Quarr at the end of act 3 |
| Twist | A duel under a stated special rule (7.3) |
| Encounter | A duel with an allied character fighting beside you (7.4) |
| Relic node | The Relic pick (7.5). Forced, once per run. Built 2026-09-29 |
| Shop | Spends Mana, the per-run currency (7.6) |
| Shrine | A choice of Resonance (7.7) |
| Forge | Cut cards from the deck, or add copies of cards already in it |
| Mystery | A text event with a choice. Later, after the others |

Hidden achievement chains can add a hidden node to the map (section 8.5).

### 7.3 Twist duels

A twist is a stated rule on one duel, printed on the node, in place of a stat bump.

- The **survival-only duel** (working name), after a tournament format of the reference game:
  only an emptied Life Deck scores, with no Ascension or Seal points, and damage dealt past lethal
  counts as overkill, which earns a knockout prize. `set_points_options` already switches the
  other win routes off.
- The opponent starts with a Drill or Grounds in play.
- The opponent opens at Fervor 3.

### 7.4 Ally encounters

The allied character's personality card starts in play on the player's side as an Ally for that
duel, using the existing Ally rules and the existing start-in-play setup
(`DuelEngine._start_in_play`). A personality is a personality (see `zenith.md`, Personalities):
any Aspect 1 to 3 card of a character can join this way, and no Ally-only card is needed.

**True 2v2 is shelved as an expansion point.** In that version the two members of a team enter
Combat together, either one attacks, and either one blocks for the other. The engine assumes two
seats throughout, so it is a large engine pass and waits until the rest of the run stands.

### 7.5 The Relic node

The Relic is the side-deck holder: one slot, an activated power, and a `reserve_size` that sets how
many cards the Reserve holds.

- A forced node a few rows into act 1, where every path meets, in the manner of a Slay the Spire
  boss relic.
- **One Relic node per run.** The player chooses one of three offers.
- An offer is a Relic plus a Reserve set of about five cards (section 4.2). Later Reserve bundles
  fill the rest.

Five Relics exist today: `relic_01` The Blank Mask (Reserve 13), `relic_03` The Lodestone Heart
(10), `relic_04` The Severing Clasp (7), `relic_05` The Champion's Laurel (9) and `relic_02` The
Debtor's Ring (5).

**Built 2026-09-29** (`adventure/adventure_relic.gd`, `scenes/adventure/relic.tscn`), pool in the
`relic` block of `data/adventure/economy.json`:

- The pool is the Blank Mask, the Severing Clasp, the Champion's Laurel and the Debtor's Ring. The
  Lodestone Heart is the final boss's and is never offered. The Debtor's Ring is offered only when
  the run's Life Deck or Reserve holds a personality card (an Ally).
- Three offers, each a distinct Relic with a Reserve set. The held Relic may be one of them. The
  three sets are different. A school run draws from its school's sets and the Freestyle sets, with
  at least one school set when one is legal and no more than two of one group; a run whose Mastery
  is Freestyle draws Freestyle sets only, as many as it likes.
- The offers are rolled once when the node opens, from the run seed and the node, and saved with
  the run. A run saved on the node, or while setting cards aside, loads back onto that screen.
- **Taking** an offer replaces the held Relic (the old one is gone) and adds the set's cards to the
  current Reserve; a run with no Relic starts from an empty one. The pick is recorded as
  `{kind: "relic", id, cards}`. If the Reserve is now over the new Relic's size, the run goes to
  the Reserve screen (section 4.7) to set cards aside into the run library, with the new cards
  marked NEW, and cannot leave until the Reserve fits.
- **Keep** is offered only to a run that already holds a Relic, and changes nothing. A run with no
  Relic has to take one.
- A starter that ships a Relic (`tide_companions`) holds it from the first node.

### 7.6 Mana

**Mana** is the per-run currency. It is spent at Shop nodes and is gone when the run ends. Motes
stay the only currency outside a run (section 8.2).

Built 2026-09-29, numbers in the `mana` block of `data/adventure/economy.json`:

- A run starts with **50 Mana**.
- A won fight pays **Duel 20, Elite 35, Boss 75**, plus 5 for every act after the first (act 2:
  25/40/80, act 3: 30/45/85). Key character, Twist and Encounter nodes pay as a Duel.
- A **Shop** sells 5 single cards drawn from what a reward could give the run: its own school,
  Freestyle, and its Duelist's own Signature cards, each legal to add. No personalities, Masteries,
  Relics, Seals or Grounds. Prices follow the Motes band: **45 / 70 / 110** for base, limited and
  restricted. The stock is rolled once per Shop from the run seed and the node, saved with the run,
  and never rerolled. A bought card joins the run deck at once and counts as a run gain.
- Mana never turns into Motes.

In the fiction it is the same charge constructs run on (`zenith/docs/cast.md`, Origins), so a
duelist carrying a lot of it is prey to them. This is flavour only: construct opponents do not
drain Mana (user, 2026-09-24).

### 7.7 Resonances

Not built. Approved 2026-09-20. A stacking per-run layer in the Slay the Spire relic sense: small
permanent modifiers that accumulate over a run and combine into something the player did not plan.
A duelist who keeps winning on the leylines starts to resonate with them. Deliberately not
"Enchantment", which is what Slay the Spire 2 calls its own system. They are not Relics.

**Implementation.** A Resonance is a hidden Drill with `start_in_play`, owned by the run rather
than by the Life Deck, and it cannot be discarded or removed. It carries `modifiers` and `effects`
in the schema `CardDef` already uses, so `card_text.gd` renders it unchanged. Ascending discards
Drills, so Resonances need a flag exempting them, which is the only engine change the layer needs.

**Economy.** Three to five per run, from Shrine nodes and Elite rewards. Tiered the way Slay the
Spire tiers relics, with the strongest reserved for gate wins.

| Tier | Example |
|---|---|
| Common | Open each duel at one Energy stage higher |
| Common | Draw one extra card on your first turn |
| Common | Your first Strike each duel does +2 stages |
| Uncommon | Gain +1 Fervor the first time you ascend |
| Uncommon | Your Seals cannot be captured the turn they are placed |
| Uncommon | The opponent opens with one fewer Drill |
| Gate | Your Reserve holds 3 more cards |
| Gate | Once per duel, ignore the first successful Art against you |

**Guard.** Resonances must not touch the Ascension or MPPV win directly. A Resonance that grants
Fervor on a schedule turns every duel into a race to the same ending.

### 7.8 What is built today

Built 2026-09-23: a run plays the node map. The 8-stage pipeline and `AdventureLadder` are gone.

- `adventure/adventure_map.gd` rolls the map from the run seed; it is never saved. Numbers live in
  `data/adventure/map.json`: 4 lanes, fight chance 0.55 per node, Duel 70, Elite 15, Key
  character 10. Twist and Encounter are at weight 0 until their duel rules exist. Across 60 runs,
  8% of paths hold 2 fights, 72% hold 3 or 4, and 20% hold 5.
- A family is drawn from the node's band, never the starter's own family, and never one met on the
  way into the node while the band has another. Quarr's family stays out of every other draw.
- `AdventureRun` holds `node_id` and `path`; `stage` counts the duels won. Non-fighting nodes do
  nothing yet and are passed through. The save is at version 5, and older saves are dropped.
- Forge built 2026-09-29: one free action per visit, cut a card or copy one already in the deck, or leave (`AdventureForge`).
- Mana and the Shop built 2026-09-29: five single cards for Mana, bought one click at a time until the player leaves (`AdventureShop`, section 7.6).
- The Relic node, Reserve sets, run library and Reserve screen built 2026-09-29 (`AdventureRelic`, `AdventureReserve`, sections 4.2, 4.7 and 7.5). The save is at version 8.
- The map takes most of the stage screen as a scrolling board (`scripts/adventure/map_route.gd`)
  on plain parchment, with the run's Duelist portrait as the player's token. A full-height side
  panel shows the deck, act, duels won, Mana and Motes over the picked node's preview: the opponent sheet
  for a fight, a note for anything else. The act's hex terrain is the dimmed screen backdrop only (green
  lowlands, marsh, winter highlands). The board has a location marker per node type,
  dashed roads, and Ornate frames. All of it is library art brought in by
  `tools/import_map_art.py`, listed in `assets/adventure_map/SOURCES.md`. None of it is generated.
- `tests/adventure_lab.gd` walks the map, picking a random path at every fork.

Bands: stronger `steel_beatdown`, `root_seals`, `shade_mind_siege`; medium `shade_henchmen`,
`pyre_beatdown`, `freestyle_swords`, `pyre_attrition`, `tide_deepwater`, `storm_volley`; weaker
the rest. The `story` field on every duel is empty.

Measured 2026-09-22 on the old 8-stage run (`docs/balance_2026-09-22.md`): stages 1 to 3 won
99%, stage 4 87%, 5 82%, 6 59%, 7 60%, boss 24%. 8 of 140 lab runs won. The map has not been
measured yet.

### 7.9 Losing

**A loss ends the run.** No retries. The run goes to the settle screen (section 8.2), where the
cards it added can be kept for Motes. Quitting mid-duel restarts that duel with the same seed.

---

## 8. Meta-progression

Decided 2026-09-24. Three routes, kept apart:

| Route | What it gives |
|---|---|
| **Motes** (8.2) | The vendor, deck slots per starter, and dusting of copies past the cap |
| **XP** (8.3, 8.4) | School XP fills a school's library. Personality XP pays a character's authored milestones |
| **Achievements** (8.5) | Everything else: first tier 3 Aspects, act 2 boss starters, hidden chains, unique story printings, the Lodestone Heart and Quarr |

Nothing earned through XP or achievements is ever for sale, and a milestone printing never shows
up on the vendor.

**Built 2026-09-24:** `AdventureProgress` (XP, levels, granting, a new run's owned Aspects and
starting Relic), `AdventureAchievements` and the journal screen, owned-only Aspect grants,
character-then-deck select. Data in `data/adventure/progression.json` and `achievements.json`.
Not built: hidden map nodes for achievement chains, a Mastery swap in the loadout, unique
personality printings (each needs a printed source), gallery and epilogues. See
`zenith/docs/adventure_build_plan.md` phase 6.

### 8.1 The collection

`adventure/adventure_collection.gd`, `user://adventure/collection.json`. Built.

- **The collection is a library, not a box.** A run copies cards out of it and never empties it,
  so the same copies serve every starter.
- **Copy caps.** At most 3 copies of a normal card and 4 of a card named for a character.
  Personalities and Seals are 1 apiece. A card printed at a tighter limit keeps that limit.
  Anything past the cap dissolves into Motes on the spot, with a ledger line and a report the
  screen shows once. The settle screen's Keep and the vendor's Buy stop at the cap instead.
- **A loadout takes no more copies than the collection holds.** Before a run, cards from the
  collection can be swapped into a starter (`adventure/adventure_loadout.gd`). The starter's own
  printed cards never count against the collection.

### 8.2 Motes

Motes are the one currency outside a run. Built 2026-09-21: `adventure_economy.gd`,
`adventure_wallet.gd`, `adventure_vendor.gd`, `adventure_settlement.gd`,
`adventure_upgrades.gd`, numbers in `data/adventure/economy.json`.

- **Keeping cards costs Motes.** Nothing banks for free. The run's status goes to `"settle"`
  after a win or a loss. A loss offers the cards the run added, at full price. A win offers
  everything the run owns, the starter's own cards included, at a 25% discount on that screen
  only. Both count the Life Deck, the Reserve and the library together (user, 2026-09-29), so a
  card gained into the Reserve or set aside in the library is a run gain like any other.
  Closing it ends the run and rolls the vendor's shelf over.
- **Prices** are flat by a printed tell, in three bands, until section 5's tiers exist: `base`
  80 (anything a deck may run three of), `limited` 160 (printed at two, every personality, every
  Grounds), `restricted` 320 (a lockout, a card printed at one, every Seal).
- **Income.** Each won duel pays by act: 20, 30 and 40, and an act boss 40, 60 and 80. Beating
  the final boss adds a completion bonus of 50. Dissolving pays 25% of price. A typical full win
  of 3 or 4 duels an act pays about 545 and keeps six or seven cards at base price.
- **Vendor.** Sells cards outright into the collection. Shelf of 6, rotating each run, reroll 40.
  It may stock a random personality card, but never one flagged as a milestone or achievement
  printing.
- **Deck slots, per starter.** A bought slot raises that starter's loadout size cap by one,
  filled with any legal pick from the collection. Slots run to `DeckValidator`'s maximum (85, Root
  90) minus the starter's printed total, so a run reaches the full 85 only after slots are bought.
  The Nth slot costs 100 × 1.1^(N-1), rounded to 10:

  | Slot | Price | Track so far | Full wins |
  | --- | --- | --- | --- |
  | 1 | 100 | 100 | 0.2 |
  | 3 | 120 | 330 | 0.7 |
  | 5 | 150 | 610 | 1.2 |
  | 10 | 240 | 1590 | 3.2 |
  | 20 | 610 | 5740 | 11.7 |
  | 32 | 1920 | 20110 | 41.0 |

- **Aspect tiers are no longer bought** (removed 2026-09-24). Aspect cards are owned through
  personality milestones and achievements (8.6).
- Files: `wallet.json` (Motes, ledger, vendor stock seed), `collection.json`, `upgrades.json`
  (`extra_slots` per starter).

### 8.3 School XP

A run earns XP for the school of its Mastery: per duel won, more per boss, a bonus for finishing
the run. Each school level adds a batch of about three of that school's cards to the collection,
through the collection's own caps, so a copy past the cap dusts into Motes. Milestone levels add
the school's alternate Masteries. A school's roughly 50 cards fill over about eight levels.

### 8.4 Personality XP

One XP track per character, shared by every deck of that character. It keeps building after the
character is unlocked.

| Source | XP (first guess) |
|---|---|
| As the main: each duel won, each boss, the run won | 10, 25, 50 |
| In play as an Ally or guest in a won duel | 15 |
| Beaten by the player: a duel, a boss | 5, 15 |

Levels run to 10 on a rising curve (100 for level 2, then about 250, 450, 700, 1000, up to about
2500). **Milestones are authored per character**, in whatever order suits them:

- signature cards, into the collection;
- **unique personality printings**, obtainable only from that milestone; other printings of the
  same character may come from the vendor or elsewhere;
- becoming a startable Ally;
- the character's starter deck, at a level set per character (Emrys early, Alder later);
- **deck abilities** for every starter of that character: a starting Relic, a starting Reserve,
  later a starting Resonance;
- a gallery page, and an epilogue at the top.

### 8.5 Achievements

Everything that is neither Motes nor XP. An achievement is ordered steps, tracked in the
background from run and duel events, and listed in an **achievement journal** grouped by
character.

- **Public**: listed with its steps from the start.
- **Hidden**: shown as "???" until its first step happens, then revealed with a one-line hint.
- **Secret**: invisible until done.

A random meeting never unlocks anything by itself; beating someone at a Key node can only start a
chain. Step types: beat a character (by node type, act, count, or within one run), beat an act
boss or finish a run with a main, characters in play together in a won duel, a duel won without
playing a card type, reaching Aspect N in a duel, a full Seal set, a card or character in the run
deck. Hidden chains can put a hidden node on the map.

The specific achievements are deliberately still open. Working examples: Edric's first tier 3
from winning a duel with Alder and Emrys in play; Ashmark's from beating Siphon at act 1 without a
block; the act 2 bosses opening Caedan, Sable and Ember Ascendant; hidden chains for Osric, both
Siphon decks and Quarr; the Lodestone Heart for beating Quarr with all three mains.

### 8.6 Aspects

- **No random in-run grants.** A new Aspect card is a meta unlock, from a personality milestone or
  an achievement. Each character's first tier 3 comes from an achievement.
- A run climbs only through Aspects the player owns: the starter's own printed stack, plus any
  owned higher card of that character. A boss win adds the next owned tier.
- Opponents are not capped at the player's Aspect count. The act 1 boss stays t3 with its third
  Aspect, the first rival who can outclimb the player.

### 8.7 The starting cast and character select

Three characters are open on a new save: Sir Edric Rooke (`tide_deepwater`), Gideon Mourne
(`shade_mind_siege`) and Bram Ashmark (`pyre_beatdown`). Every other starter unlocks through
personality XP or an achievement. **Halden Quarr is very hard to unlock**, since he is every
run's final boss.

Character select picks a character, then a deck when the character has more than one (Edric,
Ashmark, Siphon).

### 8.8 Storylines and the relations network

Decided 2026-09-23 with the lore in `zenith/docs/cast.md` (The Lodestone Heart, Storylines and
relations).

**Built 2026-09-23:** set act bosses, act 1 joins, Encounter guests and the three open starters,
in `data/adventure/storylines.json`, `AdventureStory` and `DuelEngine.set_guest_ally`. Random
draws never meet the run's own character; a set boss may. Not built: Key character meetings from
the network, Ally-pair introductions, story text.

**Each starter is a storyline.** Everyone is after the Lodestone Heart, and every run can fight
the whole roster, friendly tests included. The three runs overlap heavily in opponents. They
differ in which Allies join and which meetings and quests unlock characters.

| Starter | Viewpoint | Act 1 boss | Act 2 boss | Beating act 2 unlocks |
|---|---|---|---|---|
| Edric, `tide_deepwater` | The good side, with the Rooke and Vale families | Emrys Rooke, `steel_heir`: his eldest insists on coming and has to prove he is ready | Caedan Vale, `freestyle_swords` | Caedan |
| Mourne, `shade_mind_siege` | The outlaw side | Marrow, `shade_salvage`: she wants to hire him and they fight over his price | Sable Draik, `shade_henchmen`, as a recruitment test: she wants him in the company | Sable |
| Ashmark, `pyre_beatdown` | The villain | Siphon, `storm_volley`: a charged Collegium construct, his first meal | Sir Edric Rooke, `pyre_ascent` | Edric's Ember Ascendant deck |

Act 3 is Quarr, who takes more effort. Full starter unlocks sit around act 2: an act 2 boss often
unlocks that character through an achievement, but not always. An act 1 boss gives XP, an Ally or
an achievement step, not a starter:

- **Edric beats Emrys.** Emrys joins the run deck at his Aspect 1, The Eldest, and his personality
  XP starts to build toward Steel Inheritance.
- **Mourne beats Marrow.** Orvath Kell, the broken company's last officer and Mourne's old
  comrade, joins the run deck. Marrow's personality XP builds toward Scrap Requiem.
- **Ashmark beats Siphon.** He fields no Allies. It is the first step of the chain in which a
  rebuilt Siphon (Stormlock, `storm_unbound`) returns in a later run as a hidden challenger. His
  run may read thinner than the other two at act 1.

**The relations network.** Characters are linked by the relations in `cast.md`. Meeting nodes
(Key character, section 7.2) are drawn from the main personality's connections. An Ally in the
run occasionally brings in one of its own connections. The right pair of Allies can introduce the
main to someone new, which adds that connection for the run. Working examples: Cull and Kell
introduce Marrow; Pim and any Draik introduce Sable; Ansel and Tavin introduce Caedan; Alder and
Emrys introduce Osric; Siphon and Tithe introduce Cull; Cull and Scorn introduce Marrow.

**Where each starter unlocks** (working, 2026-09-24): Caedan, Sable and Ember Ascendant from act 2
boss achievements; Emrys, Alder, Marrow and Last Standing from personality XP; Osric, both Siphon
decks and Quarr from hidden achievement chains. Patterns taken from the PS1 and PS2 era: set
bosses that unlock their character (Tekken 2), hidden challengers on conditions that return after a
loss (Mortal Kombat, Smash Melee), recruits who need a certain character with you (Suikoden), and
side chains for secret characters (Final Fantasy Tactics).

**Only the three starters have storylines so far.** A run played with any other character (Caedan,
Sable, Emrys and the rest, once unlocked) still needs its own storyline, act bosses and meetings.
Until then those runs use random act bosses.

---

## 9. Legality

`DeckValidator` takes a mode argument rather than forking:

| Constant | Multiplayer | Adventure |
|---|---|---|
| MIN_CARDS | 50 | 30 (`MIN_CARDS_ADVENTURE`, so t1 opponents are legal) |
| MAX_CARDS | 85, 90 Root | unchanged |
| MIN_ASPECTS | 3 | 1 |
| MAX_ASPECTS | 5 | unchanged |
| SIGNATURE_LIMIT | 4 | unchanged |
| MAX_ALLY_ASPECT | 3 | unchanged |

---

## 10. Decided

- Starters are separate hand-authored files, 50 cards (Root 55), built to the standards in 3.2.
  No bleed-through from `data/decks/`. Starters are adventure only.
- The Mastery is never stripped.
- Starting Allies are concrete and fixed per deck.
- Starters and low-tier opponents hold no lockouts. Lockouts are reward content and main-deck
  staples.
- Opponent tiers are generated by one scaling function from the precons. Difficulty comes from
  which family sits in which band.
- Rewards are theme bundles, pick one of three, with a cut on every reward screen.
- Reserve bundles hold counter tech and go into the Reserve.
- Aspects are owned, never random: personality milestones and achievements unlock Aspect cards,
  and a run climbs only through owned ones (8.6). They are not bought with Motes.
- A run's deck has a size cap, and the full 85 needs bought slots. Won cards past the cap wait
  in the run library, and cards swap between the deck, the library and the Reserve between nodes.
- Grounds are optional and arrive as a block of 3.
- No persistent wounds and no heal node. A lost duel ends the run.
- Adventure duels use lives: player 2, opponent 1, boss 2 (section 12).
- A run is one character's story on a node map of three acts, 8 tiers each, with a boss at tier 8
  of every act and Halden Quarr as every run's final boss. Key character nodes replace a fixed
  Rival and Nemesis.
- Ally encounters put the allied character in play as an Ally. True 2v2 is shelved.
- One Relic node per run: a forced early node offering a Relic with a school-themed starting Reserve.
- Mana is the per-run currency. Motes are the only meta currency.
- Keeping cards costs Motes. The collection is a shared library with copy caps.
- Three meta routes: Motes (vendor, deck slots, dusting), XP (school and personality), and
  achievements for everything else, tracked in a journal (section 8).
- Three starting characters: Edric (`tide_deepwater`), Gideon (`shade_mind_siege`), Bram
  (`pyre_beatdown`). Quarr is very hard to unlock.
- Each starter is a storyline with set act 1 and act 2 bosses; meetings follow the relations
  network (section 8.8).
- Character select picks a character, then a deck when there are several.
- Stacking per-run modifiers are Resonances, implemented as undiscardable hidden Drills.

## 11. Open

- Power tiers: authored on the card JSON, or computed at load from the heuristic. They would
  replace the three price bands.
- Whether lockouts and limit-1 cards can sit in bundles, whether bundle size grows with the
  stage, whether Grounds get their own reward slot. Grounds bundles appear very often today.
- Whether `DeckValidator` should check `alignment_only` on every card rather than personalities
  only.
- Whether Grounds move to a pre-duel site slot instead of the Life Deck. Plays better, but it is a
  rules change that would have to apply to multiplayer too.
- Whether a Style swap is ever allowed mid-run. Every school check in `deck_validator.gd` assumes
  one Style per deck, so probably not.

---

## 12. Lives, 2026-09-21 (asymmetric since 2026-09-22)

Adventure duels run on lives. The player has two lives; an ordinary opponent has one; the boss
has two (`AdventureRules.lives_for(row)`, `DuelEngine.set_lives`). A seat with two lives takes two
points to beat, so the player needs one point against a normal opponent and two against the boss,
while every opponent needs two against the player. Every other mode is the printed game. The
engine stores this as a points-to-win count per seat.

- **Survival point.** A Life Deck that runs out scores the rival a point. The discard pile shuffles
  into a new Life Deck; cards removed from the game stay out, so the second deck is the weaker
  one. The table is untouched. The hit that scored loses whatever damage it had left. An empty
  discard pile at that moment is the loss.
- **Ascension point.** Entering the top Aspect or standing above the rival's ladder (the MPPV
  house rule) scores once per duelist and resets nothing beyond the Fervor peak the printed rules
  already give a top Aspect.
- **Seal point.** A full Seal set scores once per duelist and the Seals stay in play
  (`set_points_options`). Decided 2026-09-21 after measuring: with the set as an outright win,
  Root won 72% of a 14-starter round robin; as one point it still won 72%, so the change costs
  Root nothing and removes the one route that ended a duel in a single stroke.
- **Rejected the same day:** returning "remove from the game after use" cards for the second
  Life Deck. Measured, it helped the strongest decks most (Steel Beatdown 81 to 83, Root 72 to
  78) and moved the Art decks not at all. The switch stays in the engine, off.
- Measured against best-of-one on the same seeds, first to two lengthens a duel from about 5
  turns to about 8 and favours the slow engines (Root, the Drill deck) over the Art and Ally decks,
  whose one-shot cards do not come back.
