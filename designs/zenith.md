# Zenith

A two-player dueling card game. Great houses vie for the king's favor through structured duels, and each house sends a named fighter into the lists. Fighters are spellswords: every guild weaves magic into medieval arms, some more than others. A duel is fought with Strikes and Arts, wears down the fighter's Vigor and Health, and the king watches. Bold play earns Acclaim, and enough Acclaim raises the fighter in the king's Favor until he ends the duel in their name.

**Engine:** Godot 4.6, GDScript, 3D playspace with 2D hand and HUD
**Genre:** Collectible card duel, Arena-style client
**Players:** 2 (hotseat first, online later), plus AI opponents for an adventure mode
**Presentation target:** a full digital client in the style of MTG Arena: a 3D table, animated card movement, response prompts, combat log
**Rules baseline:** the reference game's final pre-reboot rulebook (2003) and its rulings document, plus four rules from the 2014 relaunch: a mandatory Mastery with nothing declared at setup, the Favor win at max Acclaim on the top tier, critical damage, and Fighter Powers that do not refresh on a tier change. Nothing else from the relaunch is adopted: deck sizes stay variable, Fighters keep 3 to 5 tiers (mostly 3), and Surge Rates and Might ladders stay varied per fighter. Card text beats rulebook (the Golden Rule). Reboot-era changes (16 stages, no Acclaim leveling) are out of scope.

**IP rule:** all names, characters, art, styles, and lore are original. No source-material terms appear in code, data, assets, or this doc. Mechanics are emulated; flavor is not.

---

## Setting

Grounded chivalric fantasy: heraldry, mud, steel, and magic woven into the swing rather than hurled from a tower. Houses and the king's favor are why the duel happens and what the adventure mode is about. Inside the duel, everything is the fighter.

| Mechanic | In-world |
|---|---|
| Champion | A named fighter sworn to a house. Portrait, guild, alignment |
| Champion levels | Tiers of the king's Favor for this duel: Noticed, Regarded, Esteemed, Honored, Chosen. Every duel starts at Noticed |
| Acclaim 0 to 5 | Bold strikes, flourishes, and taunts earn it. Humiliation and foul play lose it. At 5 the king raises the fighter one tier |
| Level-up sets Vigor to full | The crowd's roar puts the wind back in you |
| Level-up discards Drills | The fight has changed character; your preparation is spent |
| Losing a level | The king's regard turns |
| Vigor stages, Might rating | The fighter's stamina, and how hard they hit at that stamina |
| Strike | Blade, fist, grapple. Base damage from the Strike Table, dealt to Vigor |
| Art | A woven technique: a bolt down the blade, a step through shadow, a shield of wind. Spends 2 Vigor, wounds directly |
| Life Deck, life cards | The fighter's Health. Every card lost is a wound. Survival win is the fighter yielding |
| Allies | Companions and seconds who take a wound for you or step in when your Vigor is spent |
| Drills | Training |
| Royal Tokens, seven per set | Marks the king awards through the tourney. Three sets: Crown, Sword, Scepter. Capture is taking one off a beaten rival |
| Grounds | The dueling grounds: the Lists, the Melee Field, the Castle Yard |
| Master, Armory | Your master-at-arms and the side deck they bring |
| Mastery, Style | The guild a fighter trains in. Every deck follows one Style and carries that guild's Mastery |
| Alignment | Knight, Knave, or Hedge (declares at setup). See Houses below |
| Favor win | The king's Favor peaks for your fighter and he ends the duel in their name |
| Token win | The king crowns the fighter holding all seven Tokens of one set |

Tone: earnest, a little grim, no jokes on the cards. Nothing with a voice gets written until approved.

### Houses, Knights, and Knaves

The court is split in two. The **Chivalry** are the houses that hold their seats by oath and open combat; their champions are **Knights**. The **Knavery** are the houses that hold theirs by intrigue, debt, and favors owed; the Chivalry call their champions **Knaves**, and the name stuck. The king needs both and trusts neither fully. In the lists a Knave must win favor the same way everyone does, in the open, which is exactly why the king insists they enter. Knights go first because precedence at court is theirs. "Knights only" cards are privileges of standing; "Knaves only" cards are the tricks a Knight's champion would lose the king's regard for using. Retinues share their house's side, which is why Allies match alignment. **Hedge** fighters are hedge-knights and free companies with no seat at all; they declare a side at setup.

Starter houses (approved 2026-09-15):

| House | Side | Guild | Champion | Retinue |
|---|---|---|---|---|
| House Ashmark, the eastern march | Knave | Ember | Bram Ashmark, a prodigy who rides momentum | none |
| House Quarr, iron roads and debts | Knave | Steel | Halden Quarr, a grinder who reads the last blow | none |
| The Draik Company, a sworn band kept alive by the Knavery | Knave | Shade | Sable Draik, captain | Vesna, Brann, Quill, Halvard Draik, and Pim |
| House Rooke, an old household of many heirs | Knight | Tide | Dame Alder Rooke, matriarch | Wren, Sir Edric, Ansel Rooke, Tavin Vale |
| House Vale, keepers of the crown's fencing tradition | Knight | Freestyle | Caedan Vale, the last heir | none |
| House Corven, the court's arcanists | Knave | Storm | The Ninth Vessel, a warded construct | The Fourteenth Vessel |

Masters: Master of the North and Master of the South are the two royal fencing schools; Master Steadfast is a champion turned teacher.

---

## Setup

1. Favor tiers stacked face up, Noticed on top. Announce your highest tier. That tier is your Favor win target.
2. Hedge fighters declare Knight or Knave.
3. Place Master and Mastery. The Mastery's guild is the deck's Style. Nothing is declared.
4. Fighter starts at Vigor 5 above 0. Acclaim starts at 0.
5. **Bracket rule.** If only one fighter's starting Might sits in Strike Table band D or above, the weaker fighter goes first. Otherwise the Knight goes first; same alignment goes random. No stage changes.
6. Shuffle the Life Deck. Opponent may cut.
7. Armory swap: bring any number of Armory cards into the Life Deck; each pushes a random Life Deck card into the Armory. Shuffle.
8. No opening hand. First draw happens in the Draw Step.

---

## Fighter and Favor

- **Fighter card** has 3 to 5 Favor tiers. Each tier lists a Surge Rate, stages 0 to 10 each with a Might rating, a Power (once per turn, Combat only; a tier change mid-Combat does not refresh it), and optionally a Constant Power (mandatory while that personality is in control of Combat).
- **Vigor stage** is the current position on the stage table. **Might** is the number in that stage. Might feeds the Strike Table.
- **Wild Might.** A stage showing Wild instead of a number always yields base damage 2 on the Strike Table, attacking or defending. Double Power Rule ignores Wild.
- **Acclaim** runs 0 to 5, tracked once per player. At 5 or more: put the current tier at the bottom of the stack, reveal the next tier, set Vigor to highest, discard all your Drills, Acclaim to 0. Excess does not carry over.
- **At top tier** with Acclaim 5 or more (or the current requirement): Favor win. If a card effect has forbidden your Favor win, instead set Vigor to highest, Acclaim to 0, keep Drills, no extra Power use.
- **Losing a tier** (card effects only): set Vigor to 5 above 0, Acclaim unchanged, discard Drills.
- Tier changes by any means other than Acclaim do not change Acclaim.

---

## Turn (7 steps)

| Step | Who | What happens |
|---|---|---|
| 1 Draw | Active | Draw 3 |
| 2 Non-Combat | Active | Place Allies, Tokens, Grounds, Non-Combat cards and Drills into play. Token powers resolve immediately. Any number may be placed |
| 3 Power Up | Active | Fighter gains Vigor equal to Surge Rate +1. Each Ally gains exactly 1. Never above highest stage |
| 4 Declare | Active | Choose Combat or skip. Playing Grounds this turn forces a skip |
| 5 Combat | Both | See below |
| 6 Discard | Both | Active player discards down to 1 card, then the opponent does the same |
| 7 Recover | Active | If Combat was not declared, may move the top discard card to the bottom of the Life Deck. The step always occurs; effects can hook it |

---

## Combat (6 phases)

| Phase | What happens |
|---|---|
| a Active Prepares | Active player resolves all "when entering Combat" effects in any order |
| b Opposing Prepares | Opposing player does the same |
| c Opposing Draws | Opposing player draws 3 |
| d Attacker Attacks | Attack, use a card in place of an attack, or pass. Pass or non-attack goes straight to phase f |
| e Defender Defends | Only if an attack was performed. Play one thing that stops or prevents, or do nothing |
| f Fight Back | Swap roles and return to d. Combat ends when both players pass consecutively in phase d |

Player types (active, opposing) never change during Combat. Roles (attacker, defender) swap every phase f.

**Attack sources.** Strike and Art cards from hand, Fighter Power, Ally Power if that Ally is in control, or a **Final Strike**: discard any card from hand to perform a bare Strike with Strike Table damage plus Drill and other in-play modifiers, then pass for the rest of Combat. Once per player per Combat. Shields and floating effects still work after it.

**In place of an attack.** Non-attack Combat cards, non-attack Fighter or Ally Powers, Grounds effects, face-up Non-Combat cards in play (discarded after use), Master power (each Master says whether its power is a Non-Combat step action, a Combat action, or either).

**Ally control.** When the Fighter is at Vigor 0 or 1, the player may put an Ally in control at the start of their own attack phase, and must say who is in control when defending (battle sequence step 4). Once the Fighter is back above that, it resumes control. After a Final Strike the player neither attacks nor defends for the rest of Combat. A skipped attack phase never happened, so passes around it are not consecutive.

**Defenses.** A Strike, Art, or Combat card from hand, a Fighter or in-control Ally Power, or a face-up Non-Combat in play, and only if it stops the attack or prevents damage. Then Defense Shields auto-activate on any still-unstopped attack, defender chooses order. Cards that end Combat can only be played as an attack action.

### Battle sequence (one attack)

1. Attacker plays or uses the card or Power, or passes.
2. Attacker pays costs, declares Empower.
3. Attacker's secondary effects resolve.
4. Defender declares which personality is in control (Ally takeover allowed only when the Fighter is at Vigor 0 or 1).
5. Defender plays a defense.
6. Defender's secondary effects resolve.
7. If not stopped, Defense Shields activate.
8. If still not stopped, the attack is successful, even at 0 damage.
9. Base damage: Strike Table for a Strike, 4 life cards for an Art, or the printed number.
10. Modifiers: adds, reductions, one multiplier at most, then caps at deal time.
11. In-control Ally may choose Token capture instead of life-card damage, if that Ally has the capture trait.
12. Vigor damage is dealt.
13. Life card damage is dealt one card at a time. Endurance may be used as each card flips.
14. **Critical damage.** If the attack dealt 5 or more life cards, attacker may choose one: capture a Token the defender controls, discard an Ally the defender controls, or lower the defender's Acclaim by 1. This is a game rule, so effects that protect Allies or Acclaim from card effects do not stop it.
15. "If successful" effects resolve, attacker picks the order.

"Use when needed" cards fit between steps, never inside one. Outside Combat they can be used at any time.

---

## Attacks and damage

- **Strike.** Base damage from the Strike Table in Vigor stages. Successful hits do not raise Acclaim by themselves; Acclaim comes from card text.
- **Art.** Costs 2 Vigor, deals 4 life cards, unless printed otherwise. Cost is paid before any effect and is not refunded if stopped. Cannot perform if the cost would take you below 0.
- **Vigor damage past 0** converts to life cards 1:1 at deal time, and counts as both damage types for prevention.
- **Life card damage** flips the top Life Deck card to discard. A Token flipped this way does not count and goes to the bottom of the Life Deck (or is removed from the game if that Token is in play). Life cards lost to non-damage effects do count Tokens.
- **"+X" modifiers** add their type even if the attack does not deal that type.
- **Reduce** modifies damage. **Prevent** blocks it. Attacks can forbid either separately. Unstoppable attacks can still be "stopped" for the defense card's secondary effects.
- **Losing** happens when you must flip or draw a life card and cannot, or when only Tokens remain and damage is dealt.

### Strike Table

Base damage = clamp(attackerBand - defenderBand + 1, 0, cap). Bands are index ranges over Might. Zenith keeps the final-era shape, nine bands A to I with cap 9, on a compact Might scale: band A is 0 and every ten points is a band (B 1 to 9, C 10 to 19, up to I at 70). Thresholds and cap live in `data/strike_table.json`.

Ladders follow the relaunch's lesson without its four tiers: fighters at the same tier sit within a band or two of each other, so equal-Vigor fights deal 0 to 2 stages and a fully charged fighter over an exhausted one deals 4 at most. Tier 1 tops in C or D, tier 2 in D or E, tier 3 in E or F; a 5-tier fighter climbs the same rungs more slowly. Each fighter keeps its own shape: a brute crosses into the tier's band early, a caster late, and Surge runs the other way.

---

## Card types

| Type | Zone | Rules |
|---|---|---|
| Fighter | Tier stack | Not in the Life Deck. Counts toward deck size |
| Ally | In play | Placed in Non-Combat at Vigor 3. Tier must be at most the Fighter's current tier. Overlay next tier directly, set to highest stage. Powers up 1 per turn. Absorbs all damage of one attack when chosen at step 4 or after damage calculation. Takes over Combat when the Fighter is at Vigor 0 or 1, then uses its own Might. Power once per Combat. Acclaim never applies to Allies. No same-tier duplicate of an Ally in play across both players |
| Strike | Hand | Performs or stops a Strike, or a utility. Endurance often printed |
| Art | Hand | Performs or stops an Art. Non-attack uses cost no Vigor |
| Combat | Hand | Utility. All effects are secondary. Used in place of an attack or as a defense if it stops or prevents |
| Non-Combat | In play | Placed in Non-Combat, used once in Combat in place of an attack, then discarded. Cannot be used during the Non-Combat step. Cards drawn in Combat wait for the next Non-Combat step |
| Drill | In play | Non-Combat that stays. One guild of Drills per player at a time. No duplicate guild Drill. Freestyle and Signature Drills unrestricted. Restricted Drills (cannot be used with other X Drills). Always-active Drills are mandatory. All Drills discard when the Fighter changes tier. An unplayable drawn Drill may be shown and shuffled back |
| Token | In play | Three sets of seven. One set per deck, one copy each. Power resolves on play, must be used. Unique in play. Immune to card effects unless named, random effects excepted. Capturable |
| Grounds | In play, shared | Placed in Non-Combat, forces Combat skip that turn. New Grounds removes the old one from the game. No duplicate Grounds in play |
| Mastery | Side card | Exactly one per deck. Its guild is the deck's Style. Never discarded or removed. Effects come from the Mastery, not the cards it modifies |
| Master | Side card | One per deck. Holds an Armory up to its printed size, outside deck size. Only "Armory" cards live there. Owner may look through it any time |

---

## Guilds and Style

The first word of a card title sets its guild. Everything else is Freestyle. Signature cards carry a fighter's name anywhere in the title. Every guild has some Arts; the guilds differ in how much magic they weave and what they do with it.

| Style word | Guild | Identity | Trades away |
|---|---|---|---|
| Ember | Berserker | Acclaim engine. Strikes that raise Acclaim, cards that protect it, fast Favor climbs. Mastery drives Acclaim every Combat | Thin defense, weak Arts |
| Tide | Warden | Guard and leverage. Parries and sidesteps, Vigor manipulation on both fighters, stop-all-attacks floats. Mastery is a standing block or Vigor swing | Slow damage, few Acclaim gains |
| Storm | Evoker | Arts. Cheaper and bigger Arts, Drill support, Focused Arts. Mastery discounts or boosts Arts | Poor Strikes, dry-Vigor weakness |
| Shade | Rogue | Cunning. Hand peeks, forced and random discards, denial, off-balance Strikes. Mastery taxes the opponent's hand | Modest raw damage |
| Steel | Juggernaut | Brute Might. Biggest Strike modifiers, Vigor gains, Strikes that also wound. Mastery boosts or shields the first attack each Combat | Little disruption, no recovery |
| Root | Ranger | Regeneration and foresight. Wounds return from discard to the deck bottom, top-deck looks and reorders, 90-card allowance. Mastery recovers cards every Combat | Low burst |
| Freestyle | none | Signature cards, Allies, Tokens, unstyled Drills, Desperation moves. Fits any deck | Weak Mastery |

- **Style.** Every deck carries exactly one Mastery, and that Mastery's guild is the deck's Style. All guild cards in the deck share that guild. A Freestyle Mastery allows no guild cards. Nothing is declared at setup. The old single-guild Surge bonus stays as a flat +1 at Power Up for every deck.
- **No gates.** Any fighter may train in any guild. "Guild only" text does not exist; gating comes from alignment and fighter names only.
- **Alignment.** Knight, Knave, or Hedge. Allies must match the Fighter. "Knights only" and "Knaves only" text.

---

## Deck construction

- 50 to 85 cards including Fighter tiers, Mastery, Master. A Root Mastery allows 90.
- Exactly one Mastery. Its guild is the deck's Style.
- At least 3 consecutive Fighter tiers from Noticed, up to 5.
- 3 copies max. 4 for Signature cards matching your Fighter. "Limit N per deck" and the restricted list override.
- Allies: at least 2 tiers below the Fighter's highest tier, 1 copy of each printing, none sharing the Fighter's character, matching alignment.
- Tokens: one set, no duplicates.
- Armory must obey the same Style and construction rules.

---

## Win conditions

| Win | Condition |
|---|---|
| Survival | Opponent cannot flip or draw a life card |
| Favor | Your Fighter is at your highest tier and reaches Acclaim 5 (or the current requirement). A 3-tier stack needs 15 Acclaim in all, a 5-tier stack 25 |
| Token | You control all 7 Tokens of one set. If you placed the 7th yourself, instant. If you captured it, you win at the start of your next turn if you still hold all 7 |

Token capture: critical damage (battle sequence step 14), an in-control capture-trait Ally choosing capture over damage, or card text. Captured Token powers may be used on capture. Floating effects from a captured Token end.

---

## Keywords and text patterns

| Keyword | Meaning |
|---|---|
| Endurance N | When this card flips as attack damage, may prevent N of the remaining damage and remove this card from the game. Not against unpreventable damage, not for non-damage discards. Endurance X reads a game value |
| Focused (attack) | Cannot be stopped by Defense Shields, Masteries, or cards that stop both attack types. Triggers all matching Shields |
| Empower N | On attack, may add N life cards and drop all text after the Empower |
| Defense Shield | Auto-stops the first unstopped attack of its type. Types: Strike, Art, both |
| Constant Power | Continuous, only while that personality is in control, mandatory |
| Floating effect | "For the remainder of Combat / turn / game". Card discards when its last effect resolves; the effect persists |
| Use when needed | Between battle sequence steps, or any time outside Combat. Can be answered by another Use when needed |
| Remain N | Stays in play to be used N more times this Combat |
| Secondary effect | Anything not the attack, its cost, Endurance, "if successful", a stop, or parenthetical text. Resolves before the opponent acts |
| If successful | Resolves at step 15 |
| Unstoppable / cannot be prevented / cannot be reduced | Three separate flags |
| Cost vs requirement | Only the word "cost" makes a cost. Cost-modifying effects ignore requirements |
| "X only" | Fighter name or alignment gate. For Strike, Art, and Combat cards the gated personality must be in control; Non-Combats may be placed but not used otherwise |
| Remove from the game after use, Limit N per deck | Self explanatory |
| Desperation moves | Freestyle cards with heavy costs, tagged so cards can reference them |
| Cards under cards | Face-down stacks under an in-play card, discarded when the host leaves play |
| Copied attacks | A virtual card with the copied text, vanishes after use |
| Cherry picking | Deck searches reveal the chosen cards and reshuffle |
| Bond | Two named Allies fight back to back as one. A Bonding card folds them under their Bond card, which enters at full Vigor with its own power. At the start of each of the owner's turns a life card goes under it; at 5 the Bond ends, the Allies return at 3 Vigor, and the Bond card goes back to the Armory. A Bond that leaves play takes both Allies with it. Implemented 2026-09-15 for House Rooke (Ansel and Tavin) |

**Timing rules.** No simultaneous effects: the active player resolves all of theirs first in any order, then the opponent. "Entering Combat" effects resolve before the opposing player draws. Card effects resolve in printed order. Cards discard immediately after their last effect. Skipped phases never happened for "beginning of phase" effects. Only one damage multiplier applies.

---

## Engine hooks

The rules engine exposes these as trigger windows, prompts, or state flags. Every card effect attaches to one of them.

**Trigger windows**
turn_start, draw, noncombat_place, powerup_begin, powerup_end, declare, entering_combat (active, then opposing), opposing_draw (replaceable), attack_phase_begin, attack_declared, costs_paid, secondary_resolved, control_choice, defense_window, shields, attack_resolved (successful or stopped), base_damage, modify_damage, vigor_damage, life_card_flip (per card), capture_window, if_successful, attack_end, fight_back, combat_end, discard_step, recover_step, turn_end, acclaim_changed, tier_up, tier_down, token_placed, token_captured, card_placed, card_leaves_play, search, reveal, use_when_needed (between steps).

**Prompts**
choose action (attack / in place / pass / Final Strike), choose defense or nothing, choose in-control personality, redirect damage to an Ally, Endurance yes/no per flipped card, capture Token yes/no and which, order If-successful effects, order Shields, order simultaneous own effects, Empower yes/no, choose targets, choose "or" branches, look-at and rearrange top N, random discard, Recover yes/no, Discard down to 1.

**State flags and counters**
must_pass_rest_of_combat, skip_next_attack_phase, cannot_declare_combat, cannot_play (card type / attack type / end-Combat cards), power_used_this_turn per tier, ally_power_used_this_combat, final_strike_used per player, once_per_combat and once_per_turn per card, floating effects with duration and owner, attachments to personalities, cards_under host, token_victory_pending (captured 7th), hand and Life Deck as hidden information with reveal permissions.

**Replacement effects**
draw 3 from discard instead of Life Deck, damage caps, convert damage type, keep cards in Discard step, alternative cost payment, blank text boxes.

---

## Client architecture

Rules engine and presentation are separate so the same engine drives hotseat, AI, online, and adventure.

- **Engine** (`engine/`, RefCounted only, no Nodes). Game state, zones, card instances, phase machine, legality checks, effect resolver, seeded RNG. Input is a **Command** (play card, choose, pass). Output is an **Event** stream. Deterministic: same seed plus same commands gives the same game.
- **Card definitions** are JSON under `data/cards/<set>/`, loaded into `CardDef` at boot. Effects are lists of typed steps bound to the hooks above, with conditions and durations. A `script_hook` field covers the few cards that need custom code.
- **Card faces** render procedurally in v1: guild color frame, name, type line, cost, text, Endurance badge. No art dependency. Each face is drawn once by a 2D `CardFace` control into a `SubViewport` and cached as a texture, so the same face serves the 2D hand and the 3D table.
- **Playspace** (`scenes/duel/`). A 3D table scene, the way a digital duel client stages a battlefield: fixed perspective `Camera3D` looking down the table toward the opponent, subtle camera drift on mouse position, a themed environment around the table (the Grounds card in play swaps the backdrop), lighting and ambient particles. Cards on the table are quads (`MeshInstance3D` with the cached face texture, unshaded, mipmapped) that tween through 3D space between zones. Zones are `Marker3D` layouts for both players: Fighter, Allies, Drills, Non-Combats, Tokens, Grounds, Mastery, Master, Life Deck, discard, removed pile, Acclaim meter, Vigor gauge. Stacks (Life Deck, discard) render as real stacks whose height tracks card count.
- **Hand and HUD** are 2D on a `CanvasLayer`: hand fan at the bottom, prompts, combat log, phase tracker, pass button. Dragging a card lifts it off the hand, raycasts onto the table plane, and hands it to the 3D layer when dropped in a legal zone. Hover on any card, 2D or 3D, shows a full-size 2D zoom. Hotseat hides the hand between turns.
- **Animation queue.** Events from the engine become queued 3D and 2D tweens: card flight, flip, attack lunge toward the target, wound flips off the Life Deck, Vigor gauge slide, Acclaim meter fill, tier-up reveal. The queue can be skipped by the player.
- **Referee and seat views.** `Referee` owns the one engine and speaks to seats only in `SeatView` (zones as uids, hidden cards as uid plus zone), `PromptView` (labelled options) and `SeatUpdate` (lines, view, prompt). Clients render from views and never touch the engine. Uids are dealt after the shuffle. Same object in three placements: in-process for hotseat and AI, in the hosting client for P2P (the host can still read everything, so P2P is friends-only), in a headless process for hosted play.
- **Player drivers.** `LocalHuman`, `Ai`, `Remote`. Online, the joiner sends Commands over ENet and receives its own `SeatUpdate`; it never holds the seed or the other seat's hidden cards.

**Risks.** Card text legibility on 3D quads at table distance: mitigate with a high-resolution face texture and the hover zoom, and keep the camera angle shallow. `SubViewport` per card face is memory-heavy at scale: render once per card definition, not per instance. Spike the drag from 2D hand to 3D table early, since that hand-off is the piece most likely to feel wrong.

---

## Adventure mode (later)

- Node map through the tourney season and the houses' intrigues. Each node is a duel against a fixed Fighter and deck.
- Rewards: cards, packs, new Fighters. Collection and deckbuilder screens.
- AI is one evaluator and a short lookahead search for every deck (`zenith/ai/`). An opponent's playstyle is a weight profile in `data/ai/profiles/`, tuned per opponent; no per-deck scripts.
- Saves through `godot-base` SaveFileHandler.

---

## Milestones

1. Engine plus headless test scene. Full 7-step turn, 6-phase Combat, 15-step battle sequence, all three wins reachable, Strike Table and damage conversion, Allies, Drills, Tokens, Grounds. Done 2026-09-15.
2. Playspace spike: 3D table, camera, card faces rendered to texture, card flight tweens. Done 2026-09-15 with click-to-play; drag from the 2D hand is still open.
3. Hotseat duel client on the spike, with deck select and placeholder decks. Done 2026-09-15.
3b. Full rule support for the six starter decks: effect queue with choice prompts, Remain, Empower, counter window, floating forbids, attachments, constant powers, Master powers, named-card locks, attack variants, "you may" and pay-any-Vigor prompts, look-at-N inspection, chosen searches, instead-of-damage choices, two-stop attacks, Ally powers without control, Drill self-maintenance. Done 2026-09-15; the few remaining approximations are listed in `zenith/README.md`.
4. AI opponent. First pass done 2026-09-17: fair AI through `Referee.sim_for`, scorer plus lookahead search, Easy, Normal and Hard, Duel the AI on the title. Open: per-deck playstyle profiles, an offline weight tuner over `tests/ai_arena.gd`, memory of cards the AI has seen.
5. Online over ENet. Done 2026-09-15: host or join from the title, the select screen as lobby. Reworked 2026-09-16 from lockstep to host-authoritative seat views: the joiner holds no engine. Open: a headless referee process, encrypted transport, matchmaking or relay, reconnects and turn timers.
6. Deckbuilder and collection.
7. Adventure mode.
8. Later keywords: Brawl format (Survival only), Bond Fighters (a Bond that replaces the fighter rather than two Allies).

Starter pool as built 2026-09-15: six Fighters, ten Allies, three Masters, six Masteries, two Token sets, and 193 functional-name cards in all, with six starter loadouts modelled card-for-card on a community set of sample decks for the reference game: two physical beatdowns, two ally decks, a Freestyle drill deck, and an energy deck. Counts and roles are kept and each card carries the real mechanics of the card it stands in for, written in the effect schema. The set is generated by `zenith/tools/gen_starters.py`.

---

## Open items

- Portraits and card flavor text. House and champion names for the six starters are approved (see Setting); everything else waits on tone approval.
- Deck size default for v1 (50 minimum is legal).
- Favor pacing with unequal stacks: a 3-tier Fighter wins Favor at 15 Acclaim, a 5-tier one at 25. Accepted for now; taller stacks trade a slower Favor win for stronger top tiers.
- Might ladders were compressed onto the compact scale on 2026-09-16 (Ashmark no longer reaches band H at tier 2, Corven now climbs to D). Per-fighter variety in Surge and Might stays; tune further from play.
- Restricted list policy: none in v1.
- Tide or Bastion as the Warden style word.
