# delve core concept

The single design document. Decisions only; tunable numbers live in code records (`RunMapConfig`, `RecoveryRules`).

## Setting

- The outpost stands in a pocket of the world. Fog closes every horizon. No road leads out. The delve below is the only direction that goes somewhere.
- The set-apartness is overt. The game states effects, never mechanisms. No horror register.
- The fort above the delve belonged to an order of the faith of Aveline. The order kept a chapel, a light and a watch. The order is gone.
- Aveline's doctrine: she made the first light so that the dead can rest. In the delve this is fact. Where light does not go, the dead do not rest.
- Every character walks out of the fog: the player, roster recruits, run guests. Why the fog took a character is material for that character's quest arc.
- The economy is closed. Gold has one purpose: the camp.

## Opening

1. A solo traveler rests at a camp. They wake surrounded by fog.
2. They venture out alone. A wolf fight teaches basic combat.
3. They find the Dire Wolf. It is juiced far past their level and kills them.
4. They reawaken at the camp. A second character is there, waiting. They join permanently.

## Soulbinding

- A night's rest at the outpost binds a character to it. The source is a crystal in the vaults. No one knows who made it; the game never answers.
- Death in the dungeon destroys the body and everything carried. The bound reawaken at the outpost anew.
- Goods banked at the outpost are untouched by death. Extraction converts carried goods to banked goods.
- Guests are not bound. Between runs they return to their idle location.
- Recruitment = the character stays a night at the outpost.

## Story stages

Told across runs through the meta progression:

1. **Salvage.** Loot the upper strata. Bank gold. Repair the outpost. Companions arrive.
2. **The order.** Deeper strata hold the order's works. The records show the true task: watch the dark below, keep a light burning. Then the records stop.
3. **The watch.** The delve cannot be cleared. Left alone, it pushes up. The Depths Warden waits at the bottom of the known dark.
4. **Resolution.** Something below does not sleep. The light holds it. The crystal returns the watchers. The restored outpost takes up the watch. The endless run cycle is the canon ending.

## Run flow

```
Outpost -> Floor 1 tree -> floor boss -> Floor 2 tree -> floor boss -> Floor 3 tree -> Depths Warden -> RunEnd
           (each tree: Map -> [Combat | Elite | Event | Rest | Meeting | Boss] -> Map ...; ShortRest from the map)
```

- A run descends through 3 floors (code: strata). Each floor is one full node tree ending in its authored floor boss; beating it fully recharges the Wardstone and opens the next floor's tree. The last floor's boss is the Depths Warden; beating it wins the run.
- The wilderness crawl: floor 1 grasslands and light forest (The Fringe), floor 2 deep spooky forest (The Deep Wood), floor 3 swamp (The Drowning Dark). Cave or underground floors can mix in later. `FloorThemes` is the per-floor table: identity, terrain biome, creature roster, base threat weights.
- Level flow across a run: party levels 1-4 on floor 1, 5-7 on floor 2, 8-10 on floor 3. Levels are per-run and reset with it.
- Leveling is XP-based and RAW: a won fight awards its encounter XP total (the budget IS the award), relative to the party's level. The threshold is heavily accelerated (tunable in `LevelingRules`) so three small floors carry the 1-10 flow. The whole party levels together, in place, mid-run; a newcomer joins at the party's current level.
- One `RunState` per run: seed, stratum, map, current node, party, day clock, Wardstone, history, outcome.
- One `combat.tscn` instance per run. Every fight goes through `CombatScene.StartEncounter`; the result arrives on `EncounterFinished`.
- A run has at most 4 characters, total.
- The player starts with 1 slot. Start slots 2, 3 and 4 are outpost unlocks; slot 2 unlocks early.
- Open slots fill from random meetings during the run. The characters drawn for a run are the only possible additions that cycle; run end sends them back to idle, and the next run redraws from the pool.
- Run ends on a TPK (defeat), the won Depths Warden fight (victory), or extraction.
- TPK: bodies destroyed, everything carried is lost, party reawakens at the outpost.

## Node map

- One tree per floor. Slay the Spire shape: `Floors` rows x `Lanes` columns, several upward paths with lane drift of at most 1, merged where they cross.
- Lines never cross. A walk refuses a lane swap when the opposite edge between those two rows already exists, so two paths trade lanes only by merging.
- Deterministic per floor from `(runSeed, stratum)`. Same seed, same trees.
- Kind rules (rows within one tree): row 0 = Combat; last row = Boss; the row before Boss = Rest; no Elite before row 3; no Rest before row 3, because a night's rest is a dead pick until the party has spent HP, slots or focus; no Rest on the row feeding the forced Campsite; no Rest or Elite adjacent on one path; remaining nodes weighted Combat > Event > Rest > Elite.
- Floors carry a minimum: at least one Elite and at least one Rest outside the forced pre-boss row. The weighted roll alone left about 40% of maps with no Elite, so a top-up pass re-kinds Combat or Event nodes that have no neighbour of that kind.
- At least two entrances. The second walk always starts on a different lane from the first.
- Kinds: Combat = Skirmish, Elite = Lair, Event = Happenstance, Rest = Campsite, Meeting = Wayfarer, Boss = the floor's boss (the Depths Warden on the last floor).
- Wayfarer rows are taken whole, the way row 0 is Combat, so every path hits them. Party size is a guarantee, not a lane the player can miss: encounter budgets count every member, so a short party pays for the gap in every fight. Rows are per floor in `RunMapConfig.MeetingFloorsByStratum`.

## Day and time

- Travel between nodes costs no tracked time.
- Ten-minute short rests are taken from the map, as many as the ward pays for. Activities, one per block, whole party: Treat Wounds, Refocus, Repair Shield. Ward is the only cost. Each block burns ward and the thinner ward makes every later generated fight harder. A rest that would put the ward out is refused, so the party can never rest itself to death. No daily allowance.
- A Campsite node = night's rest: heal Con mod x level (min 1) per member, remove Wounded, refresh daily spells and focus, start a new day.
- Spell slots come back only at a Campsite.

## After a fight

- Every member: reset turn state, clear temp HP, clear condition floors, remove non-persisting conditions, clear cooldowns.
- A member at 0 HP is set to 1 HP and alive. Wounded stays at its current value; a revived dead member gets Wounded at least 1.
- Only a TPK ends the run: if anyone survives, they stabilize the rest.

## Party

- Starting character: Aldric (Fighter).
- Early permanent joins in the first runs: Elara (Rogue), Tharr (Cleric), Fenwick (Wizard). Join order open.
- The rest of the roster is effort-based: quests, reputation, or camp purchases from extracted currency.
- Roster target is somewhat large. Source for characters and classes: the Bulwark cast (`bulwark/design/characters/`).
- `CharacterCatalog` is the single table of characters; `Party.AddMember` joins a newcomer at party level and refuses an unknown, locked, duplicate or overflowing id. Max size 4.
- Party members are live `PF2eCharacter` objects for the whole run. Nothing is rebuilt between fights.

## Wardstone

- The party carries the Wardstone, a device that holds off the fog and the dark. The ward is the run's health meter.
- Each floor sets a base threat distribution for generated fights (floor 1 low/moderate with rare severe; deeper floors drop low and add severe and extreme). As the ward burns down, every rolled tier is upshifted, by up to 3 steps, into a custom Lethal tier above the book budgets.
- A Lair adds a further tier on top of its roll (Slay the Spire elite; the bonus is tunable).
- Encounter budgets count every party member, dead or alive.
- A party of one drops a generated fight by one tier. The opening rows are walked alone and a book-Moderate fight against a single character is not one. Size and relief are tunable in `EncounterGenRules`; bosses ignore it like they ignore the ward.
- Board size scales with the party. The forest biome's 18x18 to 24x24 is a long walk for one character, so a generated fight halves the side at a party of one and rises to 0.85 of it at four, floored at 12 (`BattleMapRules`). The size roll runs on its own seed stream, so it never shifts the terrain a node already generated.
- Short rests consume ward. That burn is the whole price of resting, so healing up now buys harder fights later. Resting stops once the ward is down to one rest's worth.
- Ward 0 ends the run in defeat, party alive or not. The fog takes them. Only passive burn can get there, since resting stops short of it (`NodeBurn` is 0 today, so nothing reaches 0 yet).
- A Campsite night's rest restores part of the ward; beating a floor's boss restores all of it.
- Outpost upgrades increase ward power and duration.
- The floor's roster and the depth ramp set which creature levels fill a budget; a party below a floor's roster still fights that roster's nearest levels.

## Bosses

- A floor boss is a static encounter: a fixed creature list, authored once against a yardstick of 4 members at a set level. The book difficulty rating is a design-time check only; the runtime applies no scaling.
- Bosses ignore the Wardstone. Only generated encounters read it.
- The actual party (size and state) faces the static fight as-is. Arriving under strength is the player's risk.
- The three authored bosses (`BossEncounters`, one row per floor):
  - Floor 1, the Dire Wolf lair: Elite Dire Wolf + three Wolves (4@3, 120 XP).
  - Floor 2, the Regent's grove: Arboreal Regent + Forest Troll (4@6, 110 XP).
  - Floor 3, the Depths Warden: Adult Horned Dragon + two Marsh Giants (4@10, 120 XP). The dragon is unnamed.

## Meetings

- A Wayfarer node is a fight already in progress: one character out of the fog against this floor's creatures. They fight as an AI ally on the party's team and the player does not command them.
- They join at the end of a won fight, keeping the wounds they took. If they die, nobody joins and they come up again at the next Wayfarer.
- Draw order is `RecruitPool`: catalog order, minus the leader and anyone already in the party. With the four-character catalog that is the three the player did not lead with, one per meeting.
- Pacing: floor 1 fills slots 2 and 3, floor 2 fills slot 4. Nothing joins on floor 3. A companion arriving at level 8 gets one floor of play and the party spent two floors under strength to get them.
- A Wayfarer met with a full party is a plain fight today. Later it becomes the FF Tactics guest unit: an ally for that fight only.
- Allies fight cautiously, which is a survival check and not a fear of contact. They weigh a round of incoming damage against the HP they have left, and pay a plan score penalty only when that round could kill them (`AllyAiRules.SurvivalMargin`, 0.6 of remaining HP). A healthy ally charges a pack the same way a monster would; the same ally at a third HP strikes and steps back out. Party members standing near a tile take a share of the danger. Enemies keep the old behaviour: caution is off by default in the engine.

## Recruitment pattern

1. Meet a character randomly in the delve; they join the party for this run.
2. An event or combat hook prompts their quest or request.
3. During their quest: some wait at the outpost, others must be found again in the delve (whichever fits their story).
4. Quest or request complete: the character stays a night, is bound, and becomes start-eligible.

- Some characters gate on a reputation system and require sustained effort to unlock.

## Events

- `EventDefinition`: id, title, body, options. `EventOption`: label, optional check (skill, DC, may pick the actor), outcomes by degree of success. `EventOutcome`: data-only effects.
- The resolver rolls `SkillCheckResolver.ResolveVsDC` for the chosen (or best) party member and applies the outcome.

## Loot

- No relic system. Per-run variation comes from PF2e items: runes, invested worn items, consumables, scrolls, staves and wands.
- Loot generation is level and threat based. The Wardstone has no effect on loot.
- Data-driven from the Pf2e.Core equipment pack (~5,600 items with level, price, rarity, category).
- Per-node gp budget from the Treasure by Encounter curve, scaled by node kind and party size.
- A run-level expectation tracker compares granted vs expected value and adjusts later budgets to keep the run on the official treasure curve.
- Item level band: depth level -2 to +1; +2 reserved for Lair and Warden drops. Rarity as drop weights (common > uncommon > rare); frame-breaking items blacklisted.
- Party-fit weighting on candidate items (proficiency, armor category, spell tradition), blended with pure random.
- Weapon/armor generator composes items legally: base item + fundamental runes per level gates + property runes within level band; item level = highest component, price = sum of parts.

## Meta progression

- Meta currency is extracted from the delve and spent at the outpost.
- Outpost upgrades unlock: new items, runes and equipment; start slots 2, 3 and 4; character recruitment costs; Wardstone improvements.
- Character unlocks persist forever regardless of run outcome.
- Feat attunement: characters permanently master abilities by using them across runs (Final Fantasy 9 skills). Time spent using a feat attunes it; an attuned feat is available forever after, so classes stack up significant bonuses over many runs. Character levels do NOT carry over; attunement is the per-character permanence axis.

## Ungilded link

- Delve is self-contained and shares one universe with Ungilded. The only hook is Aveline's public mythology: name, dawn symbols, edicts, anathema, the faith as practiced.
- Never on Delve's surface: Lanric in any form, the fragments, the amalgamations, a NAMED dragon or any tie between a dragon and the hidden layer, the real-vs-fake Aveline distinction, the capital, timeline dates. An unnamed dragon may appear as a monster (the Depths Warden is one).
- All playable characters are Delve-only. No cast crossover in either direction.

## Open

- Feat attunement mechanics: what counts as "use", attunement progress and thresholds, how attuned feats slot in (extra grants vs pre-unlocked picks), caps; requires the persistence layer.
- Level-up choice UI (auto-assigned boosts/skills today; combo scripts carry the feats); L6-10 archetype feats without compiled engine features stay unscripted.
- Terrain biomes for the floor themes: grassland dress, deep-forest dress, swamp (new); all floors generate forest boards until then.
- Node roster expansion (proposed: Cache; Campsite doubles as extraction point) and extraction flow.
- Food / fatigue mechanics (seam: DayClock, which still counts days and blocks).
- Wardstone details: passive burn unit; whether the upshift governs events and guest encounters.
- Reputation system mechanics.
- Slot unlock costs; upgrade tracks and currency amounts.
- Tone / register (required before narrative content).
