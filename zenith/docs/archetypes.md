# Archetypes and theme bundles

What the card pool is made of, read off `data/cards/starter/starter_set.json`, and the reward
bundles that fall out of it. Written for the adventure reward screen: three theme bundles of 2 or 3
cards, shown face up, pick one.

It complements `docs/strategy.md`, which says how each precon is piloted. Nothing here repeats that.
Rules of record are `../../designs/zenith.md` and `../../designs/zenith_adventure.md`.

Pool as counted 2026-09-21, after the Storm and Root expansion: **397 cards**. 321 are Strikes,
Arts, Combat, Non-Combat or Drills; 28 Seals, 27 Personalities, 7 Grounds, 10 Masteries, 4 Relics.
Sections 1 to 4 count the 321. Sections 5 and 6 also cover Personalities and Grounds, which became
bundle-eligible on 2026-09-20. Seals did not: they are held for a separate reward route.

**Three classes of card, not two.** Ruled 2026-09-21. A card belongs to a **school** when it prints
one, to **Freestyle** when it is schoolless with no `character`, and to **Signature** when it prints
a `character`, whatever else it prints. Freestyle is the shared school; Signature is its own class
with its own copy limit and its own offer rule, treated in 2.8 and 5.11.

| Class | Cards | Strike | Art | Combat | Non-Combat | Drill |
|---|---|---|---|---|---|---|
| Pyre | 25 | 21 | 3 | 1 | 0 | 0 |
| Steel | 30 | 22 | 6 | 1 | 0 | 1 |
| Tide | 28 | 14 | 12 | 1 | 1 | 0 |
| Storm | 39 | 12 | 19 | 2 | 2 | 4 |
| Shade | 28 | 15 | 9 | 1 | 0 | 3 |
| Root | 38 | 16 | 10 | 6 | 2 | 4 |
| **School total** | **188** | 100 | 59 | 12 | 5 | 12 |
| Freestyle | 67 | 9 | 12 | 21 | 17 | 8 |
| Signature | 66 | 29 | 14 | 8 | 10 | 5 |

The expansion added 55 cards, all Storm (13 to 39) and Root (9 to 38). Steel reads 30 rather than
the 33 counted on 2026-09-20 because three Quarr cards moved to the Signature class; they are the
only signature cards in the set that also print a school, and section 2.8 records what that means.

---

## 1. Mechanic vocabulary

Every theme below occurs in the data. The signal is the field or op that identifies it. Counts are
over the 321 Strike/Art/Combat/Non-Combat/Drill cards; a card carries several themes. **School** is
the six schools together, **Free** is schoolless with no `character`, **Sig** is the Signature class.

| Theme | What it is | Data signal | n | School | Free | Sig |
|---|---|---|---|---|---|---|
| Strike attack | Performs a Strike, damage off the Strike Table | `attack.kind == strike` | 111 | 84 | 6 | 21 |
| Art attack | Performs an Art, 2 Energy for wounds | `attack.kind == art` | 67 | 46 | 9 | 12 |
| Energy damage | Damage in stages, converts 1:1 to wounds past 0 | `attack.stages`, `attack.printed_stages` | 87 | 65 | 5 | 17 |
| Life damage | Damage straight to the Life Deck | `attack.life`, `printed_life`, `life_per_*` | 45 | 36 | 2 | 7 |
| Fervor gain | Raises your own Fervor | op `fervor`/`set_fervor`, own, positive | 58 | 37 | 8 | 13 |
| Fervor denial | Lowers or fixes the opponent's Fervor | op `fervor`/`set_fervor`, `who: opponent` | 43 | 32 | 7 | 4 |
| Energy gain | Refills your own or an Ally's gauge | op `energy` own, positive or `"max"` | 24 | 17 | 4 | 3 |
| Energy drain | Takes the opponent's Energy | op `energy`/`set_energy`, `who: opponent` | 7 | 5 | 2 | 0 |
| Cost reduction | Makes your own attacks cheaper, to zero at the extreme | `modifiers` with `scope: "cost"`, on the card or on an attachment | 2 | 2 | 0 | 0 |
| Draw and search | Draws, digs, or fetches out of the Life Deck | ops `draw`, `draw_check`, `look_at`, `search` not from discard | 48 | 17 | 17 | 14 |
| Discard recursion | Pulls cards back out of the discard pile | ops `draw_discard`, `shuffle_discard`, `recover`, `return_removed`, `search` from discard | 39 | 17 | 11 | 11 |
| Removal from the game | Puts cards in the removed pile, yours or theirs | ops `remove_discard`, `remove_hand`, `remove: true`, `to: removed`, `discard_life` with `remove: true`, `remove_discard` with `from: "bottom"` or `amount: "any"` | 25 | 15 | 6 | 4 |
| Hand attack | Makes the opponent discard, lose or reveal cards from hand | ops `discard_hand`, `remove_hand`, `reveal_hand`, `who: opponent`; a dict `filter` narrows it to one card type | 16 | 14 | 1 | 1 |
| Stop by kind | Stops one Strike or one Art | `defense.stops` is `strike` or `art` | 47 | 35 | 2 | 10 |
| Universal stop | Stops one attack of either kind | `defense.stops == "any"` | 13 | 5 | 3 | 5 |
| Defense Shield | Auto-stops the first unstopped attack of its kind, from the table, free | `shield` | 4 | 4 | 0 | 0 |
| Lockout | Turns a whole card type or attack kind off | `is_lockout` in `tools/scale_deck.py`, which includes `name_card` and its `strip` form | 28 | 10 | 9 | 9 |
| Endurance | Prevents damage as the card flips, then leaves the game | `endurance`, `endurance_when` | 32 | 25 | 3 | 4 |
| Remain | Stays out to be used again this Combat | `remain`, `remain_when` | 17 | 10 | 1 | 6 |
| Empower | Pay to add wounds and drop the rest of the text | `empower` | 18 | 12 | 3 | 3 |
| Counter | Answers a Combat card in the response window | `counter == "combat"` | 1 | 0 | 0 | 1 |
| Timed use window | Usable only at a named moment, not in place of an attack | `use_at`: `after_damage`, `entering_combat`, `successful_attack`, `ascension_win`; `use_in_attack`, `use_after_kind` | 7 | 2 | 2 | 3 |
| Delayed stop | Stops an attack in a later phase, not this one | float `stop_next` with `duration: "next_attack_phase"`. **"Next attack phase" means the one after the current one**, not the current one | 4 | 3 | 0 | 1 |
| Board removal | Discards Drills, Non-Combats, Allies, Grounds or Seals in play | ops `discard_in_play`, `discard_grounds`; card types run up to `non_combat_ally_or_grounds`, and `to: "deck_bottom"` sends a Seal back instead of discarding it | 40 | 22 | 13 | 5 |
| Static modifier | Standing damage bonus while it is in play | `modifiers`, float `what: modifier`, or `attachment.modifiers`. `exclude_source` means the card does not buff itself | 17 | 9 | 5 | 3 |
| Ally support | Fetches Allies, pays per Ally, or needs one | `search` for `card_type: ally`, `life_per_ally`, op `bond`, `only.allies_min` | 13 | 4 | 5 | 4 |
| Seal support | Places, captures, guards, counts or bounces Seals | op `capture_seal`, `search` or `discard_in_play` for `card_type: seal`, `protect_seals`, `life_per_set_seal` | 15 | 4 | 7 | 4 |
| Aspect movement | Moves an Aspect, or forbids the Ascension win | ops `lose_aspect`, `set_aspect`, `no_ascension_win` | 6 | 0 | 4 | 2 |
| Cost in life | Pays life cards to attack or to block | `attack.pay_life`, `defense.cost_life`, own `discard_life` | 4 | 3 | 0 | 1 |
| Cost in Energy | Pays stages beyond the normal Art cost | `attack.cost_stages`, `pay_stages`, op `pay_energy` | 14 | 12 | 2 | 0 |
| Focused | Skips Shields, Masteries and stop-both cards, or answers one | `attack.focused`, `defense.stop_focused`, float `make_focused`, a `focused` variant | 24 | 12 | 4 | 8 |
| Unstoppable / unpreventable | Cannot be stopped, prevented or reduced | `attack.unstoppable`, `no_prevent`, `no_stop_by`, floats `prevent_all`, `prevent_art_life` | 10 | 5 | 2 | 3 |
| Floating effect | Rewrites the rest of the Combat or turn | op `float` | 24 | 16 | 5 | 3 |
| Ends the Combat or turn | Walks away from the exchange | ops `end_combat`, `end_turn` | 4 | 1 | 2 | 1 |
| Attachment | Sticks to a personality and keeps working | `attachment`, with `duration: "combat"` when it falls off at the end of the Combat | 5 | 2 | 0 | 3 |
| Starts in play | On the table at setup, no card played | `start_in_play` | 2 | 0 | 2 | 0 |
| Conditional play gate | Legal to use only when the board says so | `only.when.took_wounds_min`, `only.allies_min`, a `when` of `hand_school_min` | 3 | 3 | 0 | 0 |
| Reads the situation | Same card, different text depending on who or what is opposite | `attack.variants` with `when` (including `defender_tag`), `remain_when`, `endurance_when` | 17 | 8 | 0 | 9 |
| Deck attack | Reaches into the opponent's Life Deck rather than their hand or board | op `name_card` with `strip`, op `look_at` with `whose: "opponent"` and `to: "removed"` | 3 | 2 | 1 | 0 |
| One-shot bomb | Leaves the game after use and is printed under limit 3 | `remove_after_use` and `limit_per_deck < 3` | 20 | 3 | 13 | 4 |
| Printed at limit 1 | The designer's own "too strong at three" mark | `limit_per_deck == 1` | 29 | 3 | 22 | 4 |

Two placement forms of `look_at` now exist: `place: "choose"` lets the player order what they put
back, and `whose: "opponent"` with `to: "removed"` looks into the opponent's deck and takes a card
out of the game.

Themes on the card types outside the 321: Seals are the only cards with a placement power that
resolves for free (28), Grounds are the only shared permanents (7), and Personalities are the only
cards that absorb a whole attack and can take over Combat (27).

---

## 2. Per class

2.1 to 2.6 are the six schools, 2.7 is Freestyle as the shared seventh school, 2.8 is the Signature
class. "Precons" names the decks with that Style; how each is piloted is in `docs/strategy.md`.

### 2.1 Pyre — 25 cards (21 Strike, 3 Art, 1 Combat, 0 Non-Combat, 0 Drill)

- Fervor is the whole school. 19 of 25 cards move Fervor, and every basic Strike carries +1.
- It defends with Strikes: five of its Strike cards are Strike stops that also pay Fervor and Energy
  (`pyre_cinder_guard`, `pyre_bellows_guard`, `pyre_searing_guard`, `pyre_ashen_veil`) rather than
  with dedicated Combat cards.
- Board removal is on the attack, not on a spell: `pyre_scouring_flame`, `pyre_immolation`,
  `pyre_firestorm` and `pyre_ashfall` strip Drills, Allies and Non-Combats while dealing damage.
- Ranked themes: Fervor gain 19, stage damage 13, board removal 4, Energy gain 4, removal from the
  game 4, Endurance 4.
- What it lacks: Art answers. Exactly two cards stop an Art, `pyre_warding_stance` and
  `pyre_hearthguard` (`remove_after_use`). It has no Drill and no Non-Combat at all, so its whole
  support package has to come from Freestyle.
- Precons: `pyre_beatdown` (Ashmark, attack to climb), `pyre_ascent` (Sir Edric Rooke, block to
  climb, no Drills), `pyre_attrition` (Ashmark the Glut, strip the table and outlast).

### 2.2 Steel — 30 cards (22 Strike, 6 Art, 1 Combat, 0 Non-Combat, 1 Drill)

Quarr's three cards moved to the Signature class on 2026-09-21; they still print `school: steel`
and are counted in 2.8, not here.

- The biggest raw Strikes in the set: `steel_battering_ram` at 8 stages, `steel_cross` at a printed
  10, `steel_bull_charge` at a printed 7.
- It answers attacks with Energy denial. `steel_slip`, `steel_forearm_guard` and `steel_sink` stop
  and take 3 or 4 stages off the opponent, which sets up the 1:1 conversion.
- Endurance stands in for blocks: `steel_hammer_blow` 4, `steel_iron_fist` 3, `steel_scar_tissue` 2.
- Three cards read the Might comparison (`when: {higher_might: true}`), which no other school does.
- Ranked themes: stage damage 16, stop by kind 5, Endurance 5, Energy drain 3, lockout 3, Fervor
  gain 4.
- What it lacks: recursion (one card, `steel_scar_tissue`) and any Non-Combat. Two of its best Arts
  and one Art stop are Draconic-gated (`steel_shockwave`, `steel_plating`, plus Strikes
  `steel_rake`, `steel_talon`), so a Steel duelist without the bloodline loses four cards.
- Precons: `steel_beatdown` (Quarr, grind on Mastery draws), `steel_heir` (Emrys, stack permanent
  modifiers and cash them in).

### 2.3 Tide — 28 cards (14 Strike, 12 Art, 1 Combat, 1 Non-Combat, 0 Drill)

- Fervor denial is the identity: 12 of 28 cards lower the opponent's Fervor, more than the rest of
  the set put together outside Freestyle.
- The most even Strike/Art split of any school, and four cards attack and defend from one printing
  (`tide_surge` stops Strikes, `tide_undertow` stops Arts, `tide_confluence`, `tide_twin_breaker`).
- It reaches sideways rather than hitting hard: `tide_dredge` and `tide_depths` dig, `tide_drowning`
  and `tide_pull_under` strip the board, `tide_springwater` puts an Ally back into play.
- Ranked themes: Fervor denial 12, stage damage 8, life damage 8, stop by kind 6, board removal 4.
- What it lacks: Fervor gain (3 cards), Drills (none), and any large single hit. Its only static
  modifier is `tide_heavy_water` at +1 stage.
- Precons: `tide_companions` (Dame Alder, Allies and the Bond), `tide_deepwater` (Sir Edric Rooke,
  hold Fervor at 0 and strip).

### Storm — 13 cards (3 Strike, 10 Art, 0 Combat, 0 Non-Combat, 0 Drill)

- Arts and nothing else. Five of them are the same shape, a 5-wound Art with +1 or +2 Fervor
  (`storm_arc_bolt`, `storm_lash`, `storm_palm_surge`, `storm_chain_lightning`, and
  `storm_charged_ward` as a stop).
- Ranked themes: life damage 4, Fervor gain 5, stage damage 3, board removal 3, Endurance 3.
- What it lacks: nearly everything else. One Art stop that is not also an attack
  (`storm_earthing_rod`), one Strike answer (`storm_static_field`), one Energy refill
  (`storm_recharge`), zero Combat cards, zero Non-Combats, zero Drills, zero hand attack, zero
  recursion, zero Fervor denial.
- 13 school cards is not enough for bundle variety. It supports 7 honest bundles and no more; see
  the gap list in section 5.
- Precons: `storm_volley` (Siphon, discounted Art barrage), `storm_unbound` (Siphon, make Strikes
  unaffordable and out-trade).

### 2.5 Shade — 28 cards (15 Strike, 9 Art, 1 Combat, 0 Non-Combat, 3 Drill)

- Hand attack is Shade's and almost nobody else's: 9 of the 11 cards in the set that touch the
  opponent's hand are Shade.
- The `whisper` keyword sits on 9 cards and `shade_returning_whisper` reads it, putting three
  whispers from the discard on top of the Life Deck.
- It has the only school Drills that are engines rather than modifiers: `shade_composure_drill`
  (keep 2 in the Discard step), `shade_takedown_drill` (draw on a successful attack),
  `shade_faltering_drill` (pay 1 Energy to empty their hand at the Discard step).
- Ranked themes: hand attack 9, stage damage 12, life damage 6, stop by kind 5, cost in Energy 4.
- What it lacks: Fervor of any kind (1 denial, 3 gain), Energy gain (0), board removal (2). Several
  of its best cards are gated: `shade_nightmare_hold` is Pact, `shade_bitter_trade` needs the
  `marked` keyword, and `shade_ransoming_hand` is `reserve_only` and cannot go in a Life Deck at all.
- Precons: `shade_henchmen` (Sable, company on the table), `shade_salvage` (Marrow, Construct Arts),
  `shade_mind_siege` (Gideon Mourne, take the hand then finish).

### Root — 9 cards (2 Strike, 4 Art, 2 Combat, 1 Drill, 0 Non-Combat)

- The smallest pool in the set, and half of it is recursion: `root_dash`,
  `root_energy_deflection`, `root_dragon_blast` and `root_energy_focus` all move cards out of the
  discard pile.
- Two cards fetch an Art (`root_bolt`, `root_energy_focus`), which is the school's only tutor line.
- `root_dragon_blast` is the only card in the set whose damage scales off a Seal set.
- Ranked themes: recursion 4, Art attack 3, stop by kind 3.
- What it lacks: everything at volume. One Strike answer, two Art answers, zero Fervor cards, zero
  board removal, zero Non-Combats. Two of the nine are Verdant-gated, so a Root duelist without the
  bloodline has seven cards. 9 school cards supports 5 bundles and no more.
- Precon: `root_seals` (Osric, survive and carve all seven Marble Seals).

### Freestyle — 130 cards (36 Strike, 25 Art, 29 Combat, 27 Non-Combat, 13 Drill)

Split in two. **Generic Freestyle** is 67 cards with no `character`; **signature** is 63 cards that
name one. Freestyle carries the card types the schools do not: 27 of the 28 Non-Combats and 13 of
the 18 Drills in the whole set are schoolless.

- Generic themes ranked: draw and search 31, recursion 22, Fervor gain 21, board removal 18,
  lockout 17, one-shot bombs 16, Fervor denial 11.
- 55 of the 67 generic cards carry no gate. The other 12 are gated on alignment
  (`watchful_eye`, `kins_rescue`, `wardens_measure`, `guardian_drill`, `counterplay_drill` are
  Vigil; `sever_the_leyline`, `terms_of_the_pact` are Pact), on a bloodline (`closing_ranks`,
  Draconic) or on the `marked` keyword (`marked_demise`, `marked_lightning`, `marked_strength`).
  `spent_to_the_last` reads `only: {energy_min: 5}`, which is a price and not a gate.
- Precon: `freestyle_swords` (Caedan Vale, Drills the Mastery protects, then sword signatures).

Signature cards by character, reward-eligible types only: Emrys Rooke 9, Sir Edric Rooke 9,
Bram Ashmark 8, Gideon Mourne 7, Caedan Vale 7, Corin Thrace 5, Sable Draik 3, Halden Quarr 3,
The Fortress 2, Marrow 2, Siphon 2, and one each for Torvan Hask, Dame Alder Rooke, Scorn, Sledge,
Brann Draik, Halvard Draik, Vesna Draik, Mercy, Cull.

**Twenty-eight of those are unreachable by any run.** A signature card can only be offered when its
character can be in the deck, as the Duelist or as an Ally. No personality card at all exists for
Emrys Rooke, Corin Thrace, The Fortress, Torvan Hask, Scorn, Sledge or Mercy: 9 + 5 + 2 + 1 + 1 + 1 +
1 = 20 cards with no route into a Life Deck. Sable Draik, Halden Quarr and Marrow add 8 more; they
have Duelist printings only, and a Duelist printing is legal as an Ally only when its highest Aspect
is 2 below the deck's, so Sable and Quarr need a 5-Aspect deck and Marrow's 4-Aspect printing is
never legal as an Ally.

---

## 3. Per card type across schools

| Type | What it does here | How the schools differ |
|---|---|---|
| Strike | The main attack and, in four schools, the main defense. 40 of the 92 Strike-attack cards also print a `defense` block or an `endurance` value | Pyre and Steel live here (21 and 24 cards). Storm has 3. Steel carries the Endurance and the raw stage numbers, Pyre the Fervor riders, Shade the hand attack, Tide the Fervor denial |
| Art | 2 Energy for wounds, ignores the Strike Table, which is how a low-Might duelist threatens a high one | Storm is 10 of 13 Arts, Tide 12 of 28. Pyre has 3 and Steel 7, and most of those are stops rather than attacks. Root's four Arts are its damage and half its Seal engine |
| Combat | Utility, all effects secondary, used in place of an attack or as a defense when it stops | Almost entirely Freestyle: 29 of the 35. Each school has exactly one (`pyre_twin_flames`, `steel_standoff`, `tide_held_under`, `shade_veil`) except Root with two and Storm with none |
| Non-Combat | Placed in the Non-Combat step, used once in Combat, then discarded. Where the tutors live: 13 of the 27 generic ones search | Freestyle owns the type. `tide_heavy_water` is the only school Non-Combat in the set |
| Drill | Stays in play, one school of Drills per player, all discard on an Aspect change | 13 of 18 are Freestyle. The school Drills are static modifiers (`steel_conditioning_drill` +2 stages, `assembly_drill` is Freestyle) except Shade's three, which are engines, and `root_preparation_drill`, which looks at the opponent's top five |

---

## 4. Archetype plans

For each `Archetype.KINDS` id a precon uses. Order is what the plan needs first.

| Archetype | 1 engine | 2 payoff | 3 protection | Themes it feeds on | What a 40-card starter is missing |
|---|---|---|---|---|---|
| `strike_beatdown` | A Might floor: static modifiers and Energy gain, so every Strike reads a band higher | Big Strikes and Fervor riders | Stops for both kinds, Endurance, and an answer to Drills and Non-Combats | stage damage, Fervor gain, static modifier, Endurance | Copies. A beatdown precon runs its key Strike at 3 and the starter at 1 or 2, so the plan is there but does not turn up. Also Art answers: `pyre_beatdown_start` ships 5 stops in all |
| `art_beatdown` | Energy to spend and a way to get it back | 5-and-6-wound Arts, Empower, unpreventable finishers | Strike answers, because Arts leave you empty and the 1:1 conversion kills you | life damage, cost in Energy, Energy gain, Focused | Energy refills and Strike answers. Storm has one of each in its whole school pool |
| `allies` | Bodies on the table, and Ally fetch | Ally powers and cards that pay per Ally | Cards that guard Allies, and an answer to the opponent's Ally sweeps | Ally support, life damage, Energy gain | Allies. Starters ship 1 or 2 of a possible 4 or 5. Also the fetch (`rallying_call`, `hired_blades`, `warding_call`) |
| `drills` | Drills that survive, so a Mastery or a card that guards them | Static modifiers and the attacks that read them | An answer to Drill removal, which is 5 cards across the set | static modifier, draw and search, board removal | Drill count. A row of one Drill is not a row. Also the second copy of the modifier |
| `seals` | Seal tutors and a Seal guard | The seventh Seal | Survival: stops, recursion, and something that answers capture | Seal support, recursion, stop by kind | Nothing binary; `root_seals_start` ships all seven. It is missing the protection and the tempo to live long enough |
| `control` | Stops in volume and hand or board attack | The opponent running dry | Recursion, so spent answers come back | stop by kind, hand attack, Fervor denial, recursion | Stop count and recursion. Stops are the first thing a scaled deck loses |
| `ascension` (no precon uses it today) | Fervor gain and Aspect count | The climb itself | Fervor denial on their side, and an answer to `no_ascension_win` | Fervor gain, Fervor denial, aspect movement | Aspects. Runs start at 2 and the ladder grants them |

Reading for a reward system: **engine pieces early, payoff mid, protection whenever it is missing.**
The tier column in section 5 follows that. A lockout or a limit-1 card is late in every plan, because
the starter rules already keep them out (`designs/zenith_adventure.md` 6.4).

---

## 5. Proposed theme bundles

123 bundles. Names are plain and functional placeholders; none of them is a tone proposal.

**Three decisions taken 2026-09-20.**

1. **Freestyle is a school like any other, shared by every deck.** The 17-card
   `data/adventure/freestyle_core.json` list no longer limits anything: any legal schoolless card can
   be bundled. Signature cards of the run's own Duelist are unchanged. For Caedan Vale, whose Style
   is Freestyle, the Freestyle bundles in 5.7 are his school bundles.
2. **An Ally arrives with two of its own named cards.** An Ally bundle is the personality plus
   exactly two cards whose `character` is that Ally or whose `only` gate names it. **An Ally's named
   cards are offerable only inside its bundle or after that Ally is in the run deck.**
3. **No Seals through the choose-a-bundle reward.** Seals are held for a different reward route, so
   nothing in section 5 places a Seal. Cards that read Seals stay only where they work without
   owning any: capture and removal aim at the opponent's Seals and are kept, while cards that place
   or guard your own are listed in section 6 as offering nothing yet.

**Legality rules a bundle lives within.** All of these are enforced by `engine/deck_validator.gd`;
they are restated so the bundle tables can be read without it.

- One Style per deck. A deck may hold cards of its own school and schoolless cards. A Freestyle
  Style allows no *other* school's cards, so Caedan Vale's run sees Freestyle bundles and no Pyre,
  Steel, Tide, Storm, Shade or Root ones.
- Copies are `limit_per_deck`, default 3. A card naming your own Duelist allows 4 unless it prints a
  lower limit. **Personalities are limit 1 by type**, whatever they print.
- An Ally may not share the Duelist's character, must match the deck's alignment
  (`alignment_only`), and if its printing climbs past Aspect 1 its highest Aspect must be at least 2
  below the deck's Aspect count. **Every Ally printing in the set is Aspect 1 only**, so under the
  2026-09-20 house rule all 15 of them are legal at 2 Aspects, at 3, and at any count. The rule only
  bites on a Duelist printing used as an Ally: a 3-Aspect printing needs a 5-Aspect deck, and a 4 or
  5-Aspect printing is never legal as an Ally.
- Grounds unlock as a block of 3 copies of one Grounds. A Grounds forces a Combat skip on the turn
  it is placed and a new Grounds removes the old one, so a second Grounds bundle overwrites the
  first.
- `only` gates must be met: `duelist_character`, `character` (satisfied by the Duelist or by an Ally
  of that character in the deck), `tag`, `bloodline`, `alignment`.
- `shade_ransoming_hand` is `reserve_only` and can never be a reward while a run has no Relic.

**Tier key.** early = engine and basics, mid = payoff, late = lockouts, limit-1 cards and
one-shot bombs. Cards marked lockout in `tools/scale_deck.py` and cards printed at `limit_per_deck: 1`
are always late.

### 5.1 Pyre (12)

| id | name | cards | theme | wants it | tier | why |
|---|---|---|---|---|---|---|
| `pyre_strike_guards` | Strike guards | `pyre_cinder_guard` x2, `pyre_bellows_guard` | stop by kind, Fervor gain | strike_beatdown, ascension | early | Three Strike stops that each pay Fervor and Energy, so defending is still climbing |
| `pyre_art_answer` | Art answers | `pyre_warding_stance` x2, `pyre_hearthguard` | stop by kind | all Pyre | early | Pyre's only two Art stops. A Pyre starter has almost no answer to an Art deck |
| `pyre_basic_climb` | Fervor basics | `pyre_ember_strike` x2, `pyre_updraft` | Fervor gain, stage damage | strike_beatdown | early | The workhorse 3-stage Strike at playset count. Consistency, not power |
| `pyre_heavy_climb` | Heavy Fervor | `pyre_knee_bash` x2, `pyre_furnace_breath` | Fervor gain, stage damage | strike_beatdown | mid | 4-stage Strikes, and Furnace Breath pays 2 Fervor |
| `pyre_focus_line` | Focus line | `pyre_kindling`, `pyre_flame_lash` | Focused, Empower | strike_beatdown | mid | Kindling makes the rest of your Pyre attacks Focused; Flame Lash is the hit that wants to be |
| `pyre_energy_for_fervor` | Energy for Fervor | `pyre_searing_guard`, `pyre_flashpoint` | Energy gain, Fervor gain | ascension | mid | Searing Guard gives 5 Energy, Flashpoint spends 4 of them for 2 Fervor |
| `pyre_multi_use` | Multi-use Strikes | `pyre_comet_fall`, `pyre_twin_flames`, `pyre_flashover` | Remain | strike_beatdown | mid | Three of Pyre's four Remain cards, so one card covers two attack phases |
| `pyre_board_burn` | Board burn | `pyre_immolation`, `pyre_scouring_flame` | board removal | strike_beatdown, control | mid | An Art and a Strike that remove a Drill, Ally or Non-Combat while dealing damage |
| `pyre_recursion` | Attack recursion | `pyre_rekindling` x2, `pyre_ashen_veil` | recursion, removal from the game | strike_beatdown | mid | Rekindling fetches a Pyre attack from your discard; Ashen Veil removes 10 from theirs |
| `pyre_unstoppable` | Unstoppable Strikes | `pyre_blazing_charge` x2, `pyre_sword_cleave` | unstoppable, Fervor swing | strike_beatdown | mid | Blazing Charge cannot be stopped by a Strike card, which is what most decks block with |
| `pyre_wipe` | Board wipe | `pyre_firestorm`, `pyre_ashfall` | board removal, Empower | allies-hate, control | late | Firestorm trades its damage for every Drill and Ally they hold |
| `pyre_lockouts` | Attack lockouts | `pyre_backdraft`, `pyre_snuffing` | lockout | strike_beatdown | late | Backdraft stops all Arts for the Combat; Snuffing forbids their Powers |

### 5.2 Steel (15)

| id | name | cards | theme | wants it | tier | why |
|---|---|---|---|---|---|---|
| `steel_strike_floor` | Strike floor | `steel_conditioning_drill` x2, `steel_iron_fist` | static modifier | strike_beatdown, drills | early | +2 stages on every Strike, twice, is the largest standing modifier in the set |
| `steel_endurance_line` | Endurance line | `steel_hammer_blow` x2, `steel_scar_tissue` | Endurance, recursion | strike_beatdown | early | Endurance 4 and 2 are Steel's substitute for blocks |
| `steel_drain_stops` | Draining stops | `steel_forearm_guard` x2, `steel_slip` | stop by kind, Energy drain | strike_beatdown, control | early | Stop the Strike and take 3 or 4 stages, which sets up the 1:1 conversion |
| `steel_art_answer` | Art answers | `steel_sink` x2, `steel_bracing` | stop by kind | all Steel | early | Steel's only ungated Art answers |
| `steel_any_stop` | Universal stops | `steel_ironhide` x2 | universal stop, Energy gain | all Steel | mid | Stops either kind and refills 7 Energy |
| `steel_table_strip` | Table strip | `steel_headbutt`, `steel_crushing_weight` | board removal | strike_beatdown | mid | Steel's only answer to Non-Combats and Allies, both on the attack |
| `steel_tempo_tax` | Tempo tax | `steel_iron_jab` x2, `steel_dead_weight` | Energy denial | control | mid | Their next attack costs 2 more, and Dead Weight stops them gaining Energy at all |
| `steel_life_for_power` | Life for power | `steel_stamp`, `steel_tackle` | cost in life | strike_beatdown | mid | Both buy damage or Energy with the top card of the Life Deck |
| `steel_big_hits` | Big hits | `steel_battering_ram`, `steel_piston_slam` | stage damage, Focused | strike_beatdown | mid | 8 stages, and 5 Focused |
| `steel_draconic_pair` | Draconic Strikes | `steel_rake`, `steel_talon` | stage damage | strike_beatdown | mid | Draconic only. Dead in a deck whose Duelist has no bloodline |
| `steel_stall` | Stall | `steel_standoff`, `steel_iron_knee` | ends the Combat, Endurance | control | mid | Standoff ends Combat and the turn and keeps your hand. Iron Knee is Endurance 2 and -1 Fervor; its Seal rider is blank in a deck with no Seals |
| `steel_focused_finish` | Focused Arts | `steel_triple_shock` x2, `steel_reverse` | Focused, draw | art_beatdown | mid | Steel's Arts, which go around Shields |
| `steel_remain_late` | Remain package | `steel_tempering`, `steel_immovable_guard` | Remain | strike_beatdown | late | Immovable Guard is limit 1 and Remain 9 while you out-Might them |
| `steel_finishers` | Finishers | `steel_cross`, `steel_skull_crack` | one-shot, unpreventable | strike_beatdown | late | A flat 10 Energy, and 3 wounds that cannot be prevented |
| `steel_lockouts` | Steel lockouts | `steel_bull_charge`, `steel_shockwave`, `steel_plating` | lockout | strike_beatdown | late | Two are Draconic only. Shockwave turns off their Mastery and Drills |

### 5.3 Tide (13)

| id | name | cards | theme | wants it | tier | why |
|---|---|---|---|---|---|---|
| `tide_fervor_blows` | Fervor blows | `tide_bearing_down` x2, `tide_pressure_wave` | Fervor denial | control | early | -2 Fervor a hit is how Tide polices the Ascension clock |
| `tide_fervor_guards` | Fervor guards | `tide_sweep_aside` x2, `tide_deep_guard` | stop by kind, Fervor denial | control | early | One stop per attack kind, and both strip Fervor |
| `tide_strike_floor` | Strike floor | `tide_heavy_water` x2, `tide_deep_sweep` | static modifier | strike_beatdown | early | Tide's only standing damage bonus |
| `tide_tempo_guard` | Tempo guards | `tide_undersweep` x2, `tide_ebb` | floating effect, Fervor denial | control | early | Undersweep stops the next attack after it; Ebb converts spare Energy into Fervor denial |
| `tide_fervor_arts` | Fervor Arts | `tide_black_water`, `tide_full_weight` | Fervor denial, life damage | art_beatdown, control | mid | -3 and -2 Fervor from range |
| `tide_two_way` | Two-way cards | `tide_surge`, `tide_undertow` | stop by kind | all Tide | mid | Each is an attack on your turn and a stop on theirs, one per kind |
| `tide_board_strip` | Board strip | `tide_drowning`, `tide_pull_under` | board removal | control | mid | Pull Under gains Remain while Moth Seal 3 or 4 is in play |
| `tide_energy_swing` | Energy swing | `tide_welling_deep`, `tide_held_under` | Energy gain, Energy drain | control | mid | Fill your gauge, empty theirs |
| `tide_ally_reach` | Ally reach | `tide_springwater`, `tide_confluence`, `tide_twin_breaker` | Ally support | allies | mid | Springwater returns an Ally from the discard at full Energy; the other two pay more with Allies out |
| `tide_setup_dig` | Setup dig | `tide_dredge`, `tide_depths` | draw and search | control, allies | mid | Dredge puts a Non-Combat from the top five straight into play |
| `tide_art_cost` | Cheap Arts | `tide_torrent`, `tide_twin_swell` | cost in Energy, Remain | art_beatdown | mid | Torrent costs no stages and buys wounds with them instead |
| `tide_finishers` | Finishers | `tide_crushing_depth`, `tide_high_water` | life damage | art_beatdown | late | 6 wounds, and a 5-wound Art that fetches a Grounds |
| `tide_denial_late` | Denial package | `tide_breakwater`, `tide_deadweight`, `tide_deep_anchor` | lockout | control | late | Breakwater is limit 1 and makes Arts deal no wounds for the Combat |

### 5.4 Storm (7 — everything the school honestly supports)

| id | name | cards | theme | wants it | tier | why |
|---|---|---|---|---|---|---|
| `storm_art_volley` | Art volley | `storm_lash` x2, `storm_palm_surge` | life damage | art_beatdown | early | The 5-wound workhorse at playset count |
| `storm_fervor_arts` | Fervor Arts | `storm_arc_bolt` x2, `storm_earthing_rod` | Fervor gain, stop by kind | art_beatdown, ascension | early | Arc Bolt pays 2 Fervor; Earthing Rod is the school's only pure Art stop |
| `storm_art_guard` | Art guards | `storm_charged_ward` x2, `storm_static_field` | stop by kind, static modifier | art_beatdown | early | Charged Ward stops an Art and then adds 2 stages to your attacks for the Combat. Static Field is the school's only Strike answer |
| `storm_energy_loop` | Energy loop | `storm_recharge`, `storm_overcharge` | Energy gain, draw and search | art_beatdown | mid | Storm's only refill, and the only card that digs for an Art |
| `storm_board_bolts` | Board bolts | `storm_smiting_bolt` x2, `storm_thunderhead` | board removal, Empower | art_beatdown, control | mid | Storm's whole answer to Drills, Allies and Non-Combats |
| `storm_finishers` | Finishers | `storm_chain_lightning`, `storm_maelstrom` | Remain, unpreventable | art_beatdown | late | Maelstrom makes the rest of the Combat unpreventable and wipes Freestyle Drills |
| `storm_late_lock` | Phase lock | `storm_plasma_beam` x2 | lockout | art_beatdown | late | Costs them an attack phase on a hit |

**What Storm is missing, by type and theme.** This is the gap list if the school pool is widened.
It runs 13 cards where Steel runs 33.

| Missing | Count wanted | Why |
|---|---|---|
| Strike answers | 4 | One card in the school stops a Strike, and it is also an attack. An Art deck that cannot answer a Strike deck loses on the 1:1 conversion |
| Drills | 3 | Zero. `storm_volley` is a `drills`-adjacent plan with no school Drill to put down |
| Non-Combats | 3 | Zero. No school tutor, no school setup card, nothing to place in step 2 |
| Combat cards | 2 | Zero. Every trick and every universal stop has to be Freestyle |
| Energy gain / recovery | 3 | One card. An Art deck spends 2 Energy a shot and has nothing to refill with |
| Hand attack or Fervor denial | 2 | Zero of each. The school has no way to interact with the opponent outside damage and board removal |
| Cheap or variable-cost Arts | 2 | Nine of ten Arts cost the flat 2. There is no low-Energy option for a dry gauge |

### 5.5 Root (5 — everything the school honestly supports)

| id | name | cards | theme | wants it | tier | why |
|---|---|---|---|---|---|---|
| `root_stops` | Root stops | `root_firm_stance` x2, `root_energy_catch` | stop by kind | seals, control | early | One stop per kind, and Rain Catch refills 3 Energy |
| `root_foresight` | Foresight | `root_preparation_drill` x2 | draw and search | seals | early | Looks at the opponent's top five on entering Combat and reorders it |
| `root_art_chain` | Art chain | `root_bolt` x2, `root_energy_focus` | draw and search | art_beatdown, seals | mid | Both fetch an Art, so one card is two |
| `root_recycle` | Recycle | `root_dash`, `root_energy_deflection` | recursion, Energy gain | seals | mid | Boar Rush refills Energy and shuffles 4 back. Barkskin is Verdant only |
| `root_seal_payoff` | Seal payoff | `root_dragon_blast`, `root_destruction_blast` | Seal support, life damage | seals | late | Wyrmwood Blast deals a wound per Marble Seal and recycles the same number. Verdant only |

**What Root is missing, by type and theme.** 9 cards, 2 of them Verdant-gated.

| Missing | Count wanted | Why |
|---|---|---|
| Non-Combats | 4 | Zero. Root is the Seal school and has no school card that places or fetches one |
| Strikes | 4 | Two, one of which is a stop. A `seals` deck needs a way to pressure while it assembles |
| Board removal | 2 | Zero. It cannot answer a Seal guard, a Drill or an Ally with a school card |
| Fervor interaction | 2 | Zero of either direction. Its duelist wants Aspect 4 and 5 and the school gives no help |
| Universal stops | 2 | Zero. Every stop it has names one attack kind |
| Ungated recursion | 2 | Two of its four recursion cards are Verdant only, which halves the school for a non-Verdant Duelist |

### 5.6 Shade (13)

| id | name | cards | theme | wants it | tier | why |
|---|---|---|---|---|---|---|
| `shade_hand_strip` | Hand strip | `shade_unraveling`, `shade_oblivion_touch` x2 | hand attack, board removal | control, allies | early | Oblivion Touch removes from hand rather than discarding, so it beats recursion |
| `shade_art_answer` | Art answers | `shade_turned_whisper` x2, `shade_cutting_hand` | stop by kind | all Shade | early | Shade's Art stops, two of which also pay Fervor |
| `shade_strike_answer` | Strike answers | `shade_umbral_lash` x2, `shade_dread_grip` | stop by kind | all Shade | early | Both are attacks on your turn and Strike stops on theirs |
| `shade_hand_keep` | Hand keep | `shade_composure_drill` x2, `shade_takedown_drill` | Drill engine, draw | drills, control | early | Composure Drill raises the Discard step floor to 2, which is the deck's hand size |
| `shade_whisper_engine` | Whisper engine | `shade_returning_whisper`, `shade_lingering_whisper` | recursion | control | mid | Returning Whisper puts three whisper cards from the discard on top of the Life Deck |
| `shade_empty_them` | Empty the hand | `shade_emptying_whisper`, `shade_stinging_palm`, `shade_silenced_whisper` | hand attack, Focused | control | mid | Down to two cards, your pick of the rest, one to the removed pile |
| `shade_any_stop` | Universal stops | `shade_veil` x2, `shade_hex_recall` | universal stop, recursion | all Shade | mid | Hex Recall stops anything and fetches a hand-attack card back |
| `shade_big_arts` | Big Arts | `shade_rending_palm`, `shade_swelling_whisper` | life damage, Energy drain | art_beatdown | mid | 6 wounds each; Rending Palm also takes 3 stages |
| `shade_mind_press` | Mind press | `shade_mind_rot`, `shade_recoil` | hand attack | control | mid | Two more discards on a hit, and a block that trades a card for one of theirs |
| `shade_attach` | Attachment | `shade_fixed_gaze` x2 | attachment, Empower | art_beatdown | mid | Sticks to their Duelist and keeps attacking unpreventably |
| `shade_energy_push` | Energy push | `shade_gathering_dark` x2, `shade_sifting_whisper` | cost in Energy | strike_beatdown | mid | Gathering Dark turns spare stages into damage 1:1 |
| `shade_marked_pair` | Gated pair | `shade_bitter_trade`, `shade_nightmare_hold` | board removal, hand attack | control | mid | Bitter Trade needs the `marked` keyword; Insistent Whisper is Pact only |
| `shade_late_denial` | Late denial | `shade_warding_burst`, `shade_snaring_web`, `shade_faltering_drill` | lockout | control | late | Faltering Drill empties their whole hand every Discard step for 1 Energy |

### 5.7 Freestyle (29)

Schoolless and non-signature, so legal in every run. This is Caedan Vale's school pool as well as
everyone else's shared one. The last four carry a gate and are offered only to a run that meets it.

| id | name | cards | theme | wants it | tier | why |
|---|---|---|---|---|---|---|
| `free_any_stops` | Universal stops | `braced_guard` x2, `last_ward` | universal stop | all | early | Last Ward is one of two cards in the set that can answer a Focused attack |
| `free_answer_fetch` | Answer fetch | `clear_mind`, `foresight` x2 | draw and search | control | early | Both put a Combat card in hand, Foresight out of the discard pile |
| `free_draw_checks` | Draw checks | `keen_eye` x2, `quiet_study` | draw | drills, control | early | Cheap card flow that any deck can run |
| `free_recovery` | Recovery | `second_wind` x2, `parley` | Energy gain, recursion | all | early | Second Wind stops a Strike, refills the gauge and shuffles 3 back |
| `free_tutors` | Limit-1 tutors | `lucky_find`, `recalled_lesson`, `respite` | draw and search | all | mid | Recalled Lesson fetches any attack from deck or discard. All three are limit 1 |
| `free_engine_drills` | Engine Drills | `revision_drill`, `bravado_drill` | Drill engine, starts in play | drills | mid | Bravado Drill starts in play and drains 2 of their Fervor every Combat. Both limit 1 |
| `free_damage_floor` | Damage floor | `the_long_year` x2, `assembly_drill` | static modifier | strike_beatdown, drills | mid | The Long Year is +1 stage for the rest of the game and never comes off |
| `free_board_strip` | Board strip | `spoiled_rite`, `rites_unmade`, `clean_sweep` | board removal | control | mid | Rites Unmade takes every Drill they hold. Two are limit 1 |
| `free_ally_sweep` | Ally sweep | `dismissal` x2 | board removal | anti-allies | mid | Removes every Ally on both sides, so it is a cost in an Ally deck |
| `free_fervor_swing` | Fervor swing | `declaration`, `provocation` | Fervor gain, Fervor denial | ascension | mid | Declaration is +2 and -2 in one card, limit 1 |
| `free_fervor_denial` | Fervor denial | `sharp_rebuke`, `sword_lunge`, `headlong_plunge` | Fervor denial | control | mid | -3 Fervor each, and Sharp Rebuke deals 8 wounds doing it |
| `free_unstoppable` | Unstoppable Art | `unerring_bolt` x2 | unstoppable | art_beatdown | mid | Cannot be stopped and cannot be prevented |
| `free_art_burst` | Art burst | `captains_barrage` x2, `knife_volley` | life damage, Ally support | art_beatdown, allies | mid | Knife Volley deals 2 wounds per Ally you control |
| `free_seal_reach` | Seal interaction | `sleight`, `defacement`, `seal_seizure` | Seal support | anti-seals | mid | All three aim at the **opponent's** Seals, so they work in a deck holding none. Opponent ladder decks run Seals from tier 1 |
| `free_ally_call` | Ally call | `rallying_call`, `hired_blades`, `warding_call` | Ally support | allies | mid | All three put an Ally into play from the deck or the discard |
| `free_lone_blade` | Lone Blade | `lone_blade_drill` x2 | static modifier | drills | mid | +5 stages to Strikes, and it discards itself while you hold any other Non-Combat, so it does not mix with `free_damage_floor` |
| `free_tempo_tax` | Tempo tax | `open_challenge`, `ashmarks_choke_hold` | Energy denial | control | mid | Choke Hold drains 1 Energy at the start of each of their attack phases |
| `free_recycle_attacks` | Attack recycling | `old_habit` x2, `old_trick` | recursion | all | mid | Old Trick reads the Reserve and is blank until a run owns a Relic |
| `free_lobbed_setup` | Non-Combat swap | `lobbed_bolt` x2 | draw and search | control, drills | mid | Discards one of **your own** Non-Combats and fetches another into play, so a spent Non-Combat becomes the one you need |
| `free_grounds_answer` | Grounds answer | `riftcry` x2 | board removal | all | mid | The only card in the set that removes a Grounds. Worth more once the Grounds track exists |
| `free_late_locks` | Late locks | `stillness`, `kept_at_bay`, `dead_air` | lockout | control | late | Stillness stops every attack for the Combat and is limit 1 |
| `free_late_locks_2` | Late locks 2 | `blinding_flare`, `no_retreat_drill`, `warding_drill` | lockout | control, anti-seals | late | Warding Drill turns Seals off for both players, which is pure gain for a deck holding none |
| `free_late_one_shots` | One-shot bombs | `last_gasp`, `gates_boon` | one-shot | allies, control | late | Last Gasp deals 5 wounds and sets your own Energy to 0. Both limit 1 |
| `free_board_reset` | Board reset | `the_watch_goes_dark`, `breakers_yard`, `spent_to_the_last` | board removal | control | late | Spent to the Last wipes every Non-Combat and Ally in play and empties your gauge |
| `free_gambles` | Aspect gambles | `overreach`, `mutual_escalation`, `reckless_ascent` | aspect movement | ascension | late | All three give up the Ascension win or an Aspect for a burst. Only correct in a losing race |
| `free_vigil_answers` | Vigil answers | `watchful_eye` x2, `kins_rescue` | hand attack, unpreventable | Vigil decks | early | Watchful Eye puts a card back on their deck rather than in the discard. Kin's Rescue prevents all damage for the Combat and is limit 1 |
| `free_vigil_drills` | Vigil Drills | `guardian_drill` x2, `counterplay_drill` | Drill engine, lockout | Vigil, drills | late | Guardian Drill puts a Non-Combat from hand into play once a Combat. Counterplay names a card out of the game |
| `free_pact_pressure` | Pact pressure | `sever_the_leyline`, `terms_of_the_pact` | aspect movement, lockout | Pact | late | Sever drops their Duelist to Aspect 1. Both limit 1 |
| `free_draconic_push` | Draconic push | `closing_ranks` x2 | Ally support | Draconic, allies | mid | +2 wounds per Ally on one attack, and a card. Draconic Duelist only |

### 5.8 Allies (2 core, 4 follow-up)

An Ally is a Personality card in the Life Deck, limit 1, alignment-matched. Every Ally printing in
the set is Aspect 1 only, so all 15 are legal from 2 Aspects upward.

**The rule.** An Ally bundle is the personality plus exactly two of its named cards, meaning cards
whose `character` is that Ally or whose `only` gate names it. An Ally's named cards are offerable
only inside its bundle or after that Ally is in the run deck. Follow-up bundles hold named cards
alone and unlock once the Ally is in the deck.

**Only two Allies have enough named cards to form a bundle**, Sir Edric Rooke with 9 and Gideon
Mourne with 7. The other 13 have one or none.

| id | name | cards | theme | alignment | tier | why |
|---|---|---|---|---|---|---|
| `edric_ally_core` | Edric as Ally | `companion_beta` (Sir Edric Rooke), `quick_retreat`, `edrics_truce` | Ally support, universal stop | Vigil | mid | His power is a Focused Strike paying 2 wounds per Seal the opponent holds. The two cards are the strongest of his nine and neither needs him in control. Illegal in his own run |
| `mourne_ally_core` | Mourne as Ally | `salvage_gamma` (Gideon Mourne), `mournes_quickness_drill`, `mournes_frantic_rush` | Ally support, recursion | Pact | mid | His Drill draws from the bottom of the discard on entering Combat, which pays whether or not he ever takes control |

Follow-up bundles, eligible once that Ally is in the deck:

| id | name | cards | needs | tier | why |
|---|---|---|---|---|---|
| `edric_ally_draw` | Edric discard draw | `edrics_training`, `edrics_opening_strike` | Sir Edric Rooke | mid | Both draw from the bottom of the discard pile on a hit |
| `edric_ally_board` | Edric board fetch | `committed_cut` x2, `edrics_low_water` | Sir Edric Rooke | mid | Committed Cut fetches a Drill into play; Low Water puts every Non-Combat in the top seven into play |
| `edric_ally_vow` | Edric's vow | `edrics_vow` x2 | Sir Edric Rooke, plus Dame Alder Rooke in the deck | mid | The Vow attaches to Dame Alder and draws from the discard each Combat. Blank without her |
| `mourne_ally_answers` | Mourne answers | `mournes_stance`, `mournes_jolting_arc`, `mourne_takes_measure` | Gideon Mourne | late | Takes the Measure is the only card in the set that answers an Ascension win. Two of the three are lockouts |

#### Allies that cannot form a bundle yet

Each needs two named cards and does not have them. This table is the Ally half of the
card-expansion work: until it is filled, none of these 13 can be offered at all, and neither can
their named cards.

| Ally | Alignment | Named cards today | Which |
|---|---|---|---|
| `henchman_alpha` Vesna Draik | Pact | 1 | `vesnas_ambush` |
| `henchman_beta` Brann Draik | Pact | 1 | `branns_shakedown` |
| `henchman_delta` Halvard Draik | Pact | 1 | `halvards_twin_cut` |
| `salvage_alpha` Cull | Pact | 1 | `absorbing_drill` |
| `companion_epsilon` Dame Alder Rooke | Vigil | 1, and it is dead | `rookes_deluge`, which needs her as the Duelist |
| `henchman_gamma` Quill Draik | Pact | 0 | — |
| `henchman_epsilon` Pim | Pact | 0 | — |
| `henchman_zeta` Tithe | Pact | 0 | — |
| `salvage_beta` Orvath Kell | Pact | 0 | — |
| `companion_alpha` Wren Rooke | Vigil | 0 | — |
| `companion_gamma` Tavin Vale | Vigil | 0 | — |
| `companion_delta` Ansel Rooke | Vigil | 0 | — |
| `bonded_pair` Ansel and Tavin | Vigil | 0, and it lives in a Reserve | — |

With 2 of 15 Allies offerable, the `allies` archetype has almost no reward path today. Five Allies
are one named card short, so five new cards would double the Ally bundle count.

### 5.9 Seals

Not a bundle reward. Seals are held for a different reward route, so nothing in section 5 places
one. Cards that aim at the **opponent's** Seals stay in the pool and work in a deck holding none
(`sleight`, `defacement`, `seal_seizure`, `the_watch_goes_dark`, `warding_drill`). Cards that place
or guard your own are listed in section 6 as offering nothing yet. `root_seals` is the exception
that needs no reward: its starter ships all seven Marble Seals, which is why `root_dragon_blast`
stays in `root_seal_payoff`.

### 5.10 Grounds (7)

A block of 3 copies of one Grounds. Shared between both players, forces a Combat skip on the turn it
is placed, and a new Grounds removes the old one from the game. No card text anywhere reads Grounds
except `riftcry`, which removes one.

| id | name | cards | effect | wants it | tier |
|---|---|---|---|---|---|
| `grounds_the_high_watch` | Draw ground | `the_high_watch` x3 | Both draw 1 on entering Combat | any deck that enters Combat every turn | early |
| `grounds_weighted_hollow` | Strike tax | `weighted_hollow` x3 | Strikes cost 2 more Energy | art_beatdown, control | mid |
| `grounds_frostbound_moor` | Fervor cap | `frostbound_moor` x3 | Fervor gain capped at 1 | anyone racing an ascension deck, never an ascension deck | mid |
| `grounds_the_marked_ring` | Marked ground | `the_marked_ring` x3 | +1 stage and +1 wound to `marked` attacks only, and strips an Ally and a Non-Combat | Bram Ashmark, Gideon Mourne | mid |
| `grounds_ancient_grove` | Drill ground | `ancient_grove` x3 | +2 stages to your attacks and fetches a schoolless Drill into play each Combat | drills, strike_beatdown | late |
| `grounds_tollgate_yard` | Double costs | `tollgate_yard` x3 | All costs doubled, both players | a deck that pays nothing, against a deck that pays | late |
| `grounds_trampled_crossroads` | No Non-Combats | `trampled_crossroads` x3 | Neither player may play Non-Combats | strike_beatdown against a setup deck | late |

`ancient_grove` and `trampled_crossroads` are the two that read as bombs: the Grove is a standing +2
with a free Drill every Combat, and the Crossroads carries a card-level `forbid`, which is the
lockout marker.

### 5.11 Signature bundles, per playable duelist

**Bram Ashmark** (`pyre_beatdown_start`, Pyre, Pact, `marked`, 3 Aspects) — 6

| id | name | cards | theme | tier | why |
|---|---|---|---|---|---|
| `ashmark_fuel` | Refuel | `stokes_the_coals` x2, `pyre_flashpoint` | Energy gain, Fervor gain, recursion | early | Full Energy, 5 cards shuffled back and a Fervor, then Flashpoint spends the Energy for 2 more |
| `ashmark_guards` | Focused answers | `wall_of_flame` x2, `pyre_warding_stance` | universal stop, Focused | early | Wall of Flame is the only card this run can own that stops a Focused attack |
| `ashmark_marked_line` | Marked line | `ashmarks_ember_spray`, `marked_lightning`, `marked_demise` | recursion, board removal | mid | Ember Spray fetches a `marked` Art back out of the discard, and the other two are those Arts |
| `ashmark_discard_denial` | Discard denial | `scattered_ashes`, `scatters_the_ashes` | removal from the game | mid | One removes 5 from their discard pile, the other removes all of it. Answers every recursion deck |
| `ashmark_late` | Late package | `ashmarks_unmaking_whisper`, `will_not_break`, `relentless_fury` | aspect movement, lockout | late | Unmaking Whisper takes an Aspect when their Fervor is 0; Will Not Break prevents all damage for the Combat and is limit 1 |
| `ashmark_marked_pressure` | Marked pressure | `marked_strength` x2 | lockout, Energy drain | late | Takes 4 Energy and forbids their Combat cards on a hit |

**Sir Edric Rooke** (`pyre_ascent_start`, Pyre, Vigil, Draconic, 5 Aspects) — 3

| id | name | cards | theme | tier | why |
|---|---|---|---|---|---|
| `edric_discard_draw` | Discard draw | `edrics_training`, `edrics_opening_strike`, `edrics_vow` | recursion | early | All three draw from the bottom of the discard pile. The Vow attaches to Dame Alder, who is already this starter's Ally |
| `edric_guards` | Edric's guards | `quick_retreat` x2, `edrics_truce` | universal stop, Fervor gain | early | The Truce is the only card in the set that answers an attack that has already got through |
| `edric_board_fetch` | Board fetch | `committed_cut` x2, `edrics_low_water` | draw and search | mid | Committed Cut fetches a Drill into play on a hit and this run owns no Drill until one arrives; Low Water puts every Non-Combat in the top seven into play at once |

His other two named cards, `first_cut` and `keepers_drill`, place and guard your own Seals and are
held back with the rest of the Seal cards (section 6).

**Siphon** (`storm_volley_start`, Storm, Pact, `construct`, 3 Aspects) — 3

| id | name | cards | theme | tier | why |
|---|---|---|---|---|---|
| `siphon_sidestep` | Sidestep | `siphons_sidestep` x2, `storm_earthing_rod` | stop by kind, draw and search | early | Sidestep stops a Strike and fetches a Storm card, so it replaces itself. It is one of two Strike answers the run can own |
| `siphon_sabotage` | Sabotage | `sabotage` x2, `storm_smiting_bolt` | board removal | mid | Sabotage removes a Drill from the game; the Bolt takes a Non-Combat or an Ally |
| `siphon_dig` | Art dig | `siphons_sidestep`, `storm_overcharge` | draw and search | mid | Both fetch an Art, which is the whole deck |

Siphon has **two** signature cards in the whole set. Three bundles is the honest ceiling and two of
them share a card. If signature bundles are meant to feel personal, Siphon needs more printings.

**Caedan Vale** (`freestyle_swords_start`, Freestyle Style, Vigil, Draconic, 5 Aspects) — 4

| id | name | cards | theme | tier | why |
|---|---|---|---|---|---|
| `vale_answers` | Vale's answers | `vales_riposte` x2, `cut_short` | stop by kind, counter | early | Riposte stops a Strike and copies it. Cut Short is the only `counter` card in the set |
| `vale_sword_chain` | Sword chain | `vales_sword_draw` x2, `heirloom_blade` | draw and search, attachment | mid | Sword Draw fetches a "Sword" card on a hit; the Blade pays those attacks +3 wounds |
| `vale_signature_dig` | Signature dig | `vales_insight`, `vales_quickstep` | draw and search, recursion | mid | Insight fetches two signature cards from the deck, Quickstep one from the discard |
| `vale_pressure` | Vale pressure | `vales_pommel_bash` x2, `lone_blade_drill` | Endurance, static modifier | mid | Pommel Bash costs them an attack phase when they stopped him last phase |

Freestyle is Vale's school, so the 29 bundles in 5.7 are his school bundles. He sees no Pyre, Steel,
Tide, Storm, Shade or Root bundle at any point in a run.

### 5.12 How many distinct bundles each playable run can see

An 8-stage ladder shows 3 bundles a stage, 24 slots. "Ally" counts core bundles; follow-ups in
brackets unlock only after that Ally is in the deck.

| Run | School | Freestyle | Gated Freestyle | Ally | Grounds | Signature | Total |
|---|---|---|---|---|---|---|---|
| Bram Ashmark, `pyre_beatdown_start` | 12 (Pyre) | 25 | 1 (Pact) | 1 (+1) | 7 | 6 | **52 (+1)** |
| Sir Edric Rooke, `pyre_ascent_start` | 12 (Pyre) | 25 | 3 (Vigil, Draconic) | 0 | 7 | 3 | **50** |
| Siphon, `storm_volley_start` | 7 (Storm) | 25 | 1 (Pact) | 1 (+1) | 7 | 3 | **44 (+1)** |
| Caedan Vale, `freestyle_swords_start` | — | 25 | 3 (Vigil, Draconic) | 1 (+3) | 7 | 4 | **40 (+3)** |

Every run clears the 24 slots, Vale's by the smallest margin. Sir Edric's run sees **no Ally bundle
at all**: the only Vigil Ally with enough named cards is his own printing, which an Ally may not
share with the Duelist, and Gideon Mourne is Pact.

---

## 6. Coverage check

244 reward-eligible cards: the five hand types plus Grounds, excluding Masteries, Relics, Seals
(not a bundle reward), `shade_ransoming_hand` (Reserve only) and the 28 signature cards of
characters no run can field (section 2). Personality cards are counted separately below.

| Bundles containing it | Count | Cards |
|---|---|---|
| 0 | 12 | see the two lists below |
| 1 | 218 | everything not named in this table |
| 2 | 13 | `committed_cut`, `edrics_low_water`, `edrics_opening_strike`, `edrics_training`, `edrics_truce`, `edrics_vow`, `lone_blade_drill`, `pyre_flashpoint`, `pyre_warding_stance`, `quick_retreat`, `siphons_sidestep`, `storm_earthing_rod`, `storm_overcharge` |
| 3 | 1 | `storm_smiting_bolt` |
| more than 3 | 0 | — |

**In no bundle, because they need Seals you no longer earn** (6 cards): `first_cut`, `keepers_drill`,
`mournes_plans`, `mournes_smirk`, `wardens_measure` place or guard your own Seals, and
`eyes_beyond_the_gate` turns a successful Art into a placed Seal. Each is live again the moment a
Seal reward route exists, and `first_cut` and `keepers_drill` are live now in a `root_seals` run,
which ships its set.

**In no bundle, because nothing can carry them** (6 cards): `vesnas_ambush`, `branns_shakedown`,
`halvards_twin_cut`, `absorbing_drill` are the lone named card of an Ally that cannot form a bundle
(5.8), so under the Ally rule they cannot be offered at all. `bonding_rite` needs `bonded_pair`,
which lives in a Reserve. `rookes_deluge` reads `only: {duelist_character: "Dame Alder Rooke"}` and
needs her as the Duelist, which no run has; it should be filtered out in code.

**Why the repeats repeat.** The 14 cards in more than one bundle are cards two different plans
genuinely want. Six of Sir Edric's named cards appear twice, once in his own run's signature bundles
and once in the Ally follow-ups for a run that fields him; `siphons_sidestep`, `storm_overcharge`,
`storm_smiting_bolt` and `storm_earthing_rod` because Storm has 13 cards in total;
`lone_blade_drill` because it is both a Vale piece and a generic modifier; `pyre_warding_stance` and
`pyre_flashpoint` because Pyre has so few Art stops and Energy sinks. A cap of 3 appearances holds
everywhere.

**Personalities.** 15 Ally printings exist and 2 are in a bundle; the other 13 are in the table in
5.8. The 12 Duelist printings are in none, because a Duelist printing is only legal as an Ally in a
5-Aspect deck and none of the four playable runs would want one.

**Cards that are legal but do nothing in the runs that can take them**, flagged rather than dropped:
`old_trick` (searches the Reserve), `riftcry` (needs a Grounds in play), `pyre_sword_cleave` (lends
the "Sword" title, and the cards that read it are Emrys and Vale signatures), `warding_drill` (turns
Seals off for both players, so it is an answer and not an engine), `edrics_vow` (needs Dame Alder in
the deck; she is in `pyre_ascent_start` already).

---

## 7. Open questions

Each is a choice guessed in this document. The Freestyle core list, the Ally rule and the Seal
question were settled on 2026-09-20 and are recorded at the head of section 5.

1. May a bundle contain a lockout or a limit-1 card at all, or only from a stated stage onward?
2. When one card of a bundle cannot legally be added, the working default is to **drop the whole bundle from the offer** rather than substitute the card. Confirm, or should a substitution be tried first?
3. Should bundle size vary by stage, for example 2 cards early and 3 late, or stay fixed at 2 to 3?
4. Should Grounds be a separate reward slot rather than competing with cards, since a block of 3 is a much larger deck change than 2 or 3 cards?
5. Should `rookes_deluge` and `shade_ransoming_hand` be filtered out of the reward pool in code, since no run can ever use them?
6. Are the 28 unreachable signature cards meant to stay that way, or should Emrys Rooke, Corin Thrace, The Fortress, Torvan Hask, Scorn, Sledge, Mercy, Sable Draik, Halden Quarr and Marrow get Aspect-1 Ally printings?
7. The 6 Ally-named cards in no bundle (5.8) are unreachable under the Ally rule. Should they instead join the normal Freestyle pool as ordinary cards, or stay locked until their Ally has two named cards and can be bundled?
8. Storm and Root are too thin to bundle well, and five Allies are one named card short. The gap lists in 5.4, 5.5 and 5.8 name what each is missing; is widening those pools the next step?
