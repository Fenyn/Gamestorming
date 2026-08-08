# Bulwark — Content Authoring Guide

Step-by-step for adding two kinds of content: a new **NPC** (a villager you can walk up to and
talk to at the outpost) and a new **enemy/encounter** for an expedition (territory) map. Everything
here is verified against the code as it stands; where a pipeline is missing or awkward it says so
plainly rather than inventing a name. Companion to `design/building_authoring_guide.md` (same house
style: data + editor-placed markers, systems already wired).

Conventions (CLAUDE.md): PascalCase C# files, snake_case scene/resource names, no UTF-8 BOM, the
user hand-places markers/instances in the Godot editor. IDs are lowercase snake_case strings.

---

## Part 1 — Authoring a new NPC

### Where an NPC comes from — two sources, one registry

`Villagers.All` (`scripts/data/Villagers.cs`) is the arrival-gated cast. It is built from two feeds
concatenated (`Characters.AllVillagerDefinitions().Concat(HandAuthored)`, last-id-wins per
`DefinitionRegistry`):

1. **Character profiles** — `CharacterProfile` objects in `scripts/data/characters/` (one file per
   character, registered in `Characters.cs`). Every non-`StartingPC` profile auto-emits a
   `VillagerDefinition` via `CharacterProfile.ToVillagerDefinition()`. This is the richer path — the
   profile also carries bio, personality, class/ancestry, portrait. **Prefer this for named cast.**
2. **Hand-authored `VillagerDefinition`s** — the `HandAuthored` array in `Villagers.cs`, for
   characters that only need arrival + placement data and no full profile yet.

The non-player **starting residents** (Tharr, Elara, Fenwick) are `StartingPC` profiles; they are
placed unconditionally from day one via `Characters.StartingResidents()` and never "arrive." The
player avatar (`PlayerCharacter`, id `"player"`) is excluded — it is controlled, not talked to. The
current registry is `PlayerCharacter, Tharr, Elara, Fenwick, Arkus` (the founding four are
player/tharr/fenwick/elara).

### CharacterProfile — the fields (`scripts/data/characters/CharacterProfile.cs`)

Copy `_Template.cs`, rename the class, fill in, then add `<Name>.Profile` to the `Characters.cs`
registry constructor. Required: `Id`, `DefaultName`, `ClassName`, `AncestryName`, `Kind`
(`CharacterKind.StartingPC | RecruitablePC | Townsfolk`). Optional but useful: `PlayerNamed`,
`Pronouns`, `Bio`, `Personality` (used as the talk fallback — see below), `RoleDescription`,
`AssociatedBuildingId`, `Arrival` (an `ArrivalTrigger`; `null` only for starting PCs), `PortraitId`,
`SpriteId`, `Build` (deferred — leave `null`). `MarkerName` is derived: `Villager_{Id}`. Worked
example: `Arkus.cs` (RecruitablePC, `Arrival = ArrivalTrigger.StoryFlag("arkus_found")`).

### VillagerDefinition (`scripts/data/VillagerDefinition.cs`)

If you skip the profile, author one directly in `Villagers.cs`: `Id`, `DisplayName`, `Arrival`
(required); `AssociatedBuildingId`, `Recruitable`, `JoinPresetKey`, `SpriteId` (optional). Derived:
`MarkerName => Villager_{Id}`, `ScenePath => res://scenes/villagers/{Id}.tscn`.

### ArrivalTrigger factories (`scripts/data/ArrivalTrigger.cs`)

`BuildingReached(id, minTier)`, `StoryFlag(flagId)`, `DateReached(season, day, year=1)`,
`ItemCountReached(itemId, minCount)`, `FriendshipReached(characterId, minHearts)`,
`All(...)`, `Any(...)`. Empty `All`/`Any` never fires. A `StoryFlag` trigger only works if something
actually sets that flag — several authored triggers reference flags GameState does not yet raise
(documented per-character in `Villagers.cs`); that wiring is a separate GameState task.

### Spawning & placement (`scripts/cozy/VillagerLoader.cs`)

For each present villager the loader instances `res://scenes/cozy/npc.tscn` (a `VillagerNpc`) at the
marker, then calls `VillagerNpc.Setup(id, spriteId, position)`. Marker lookup order:
`%Villager_<id>` → `Villager_<id>` → the associated building's `%Building_<id>`. **You hand-place a
`Villager_<id>` Marker3D in `scenes/outpost/outpost.tscn`** and right-click → *Access as Unique
Name* (the outpost already has `Villager_tharr`, `Villager_elara`, `Villager_fenwick`). No marker
and no building fallback → the villager is skipped with a log line (state still works). A per-villager
override scene at `scenes/villagers/<id>.tscn` is honored if present; none ship today.
`GetPlaced(id)` hands the live NPC node to the cutscene director for staging.

### Sprite & portrait art (`scripts/cozy/VillagerNpc.cs`)

The NPC renders a Mana Seed hero sheet: `res://assets/sprites/heroes/<SpriteId>/p1.png`. A
null/missing `SpriteId` falls back to folder `veteran`. So a new NPC needs **either** a hero sheet
folder named to match its `SpriteId` **or** nothing (it shows the `veteran` fallback — always
visible). `PortraitId` on the profile feeds the dialogue portrait; there is no fallback enforced in
this file, so author the portrait alongside the talk pool.

### Wander AI and daily schedules (`scripts/data/Schedules.cs`, `scripts/cozy/VillagerNpc.cs`)

`VillagerNpc` wanders: it idles at its **home marker** (the spawn position), then walks to a random
point within `WanderRadius` of home and returns to idle. Exported tunables (all on the NPC node):
`WanderRadius` (96), `WanderSpeed` (40), `WanderIdleMinSeconds` (3), `WanderIdleMaxSeconds` (7),
`WanderArriveDistance` (4), `WanderStuckGiveUpSeconds` (1). Wander is **suppressed** (halts, no new
target) via a host-supplied predicate wired by the loader (`SetWanderSuppression`) — active while a
dialogue/modal is open, a cutscene plays, or this NPC is the talk target. A cutscene director can
also hard pin/unpin with `SetWanderEnabled`.

**Daily schedules are real, data-only.** A `VillagerSchedule` (`scripts/data/Schedules.cs`) is an
ordered list of `ScheduleEntry { MinuteOfDay, MarkerName }` keyed by villager id in the `Schedules`
registry (same `DefinitionRegistry` pattern as `Villagers`). `Schedules.ResolveMarker(id, minuteOfDay)`
picks the entry with the **latest `MinuteOfDay` ≤ now**; before the first slot — or with no schedule
entry at all — it returns `null`, meaning "stay home," so a villager absent from `Schedules` behaves
exactly as before (home marker + local wander, the unchanged default). Worked example, Tharr's routine:

```csharp
public static readonly VillagerSchedule Tharr = new()
{
    VillagerId = "tharr",
    Entries = new ScheduleEntry[]
    {
        new() { MinuteOfDay = At(8),  MarkerName = SpotCommandPost },
        new() { MinuteOfDay = At(13), MarkerName = SpotGate },
        new() { MinuteOfDay = At(19), MarkerName = SpotTavern },
    },
};
```

Markers are the five `%Spot_*` nodes in `outpost.tscn` (`Spot_command_post`, `Spot_gate`,
`Spot_farm_field`, `Spot_trading_post`, `Spot_tavern`) — plain hand-placed/repositionable Marker3Ds,
same convention as `Villager_<id>` and `Building_<id>`. Reuse one marker across villagers where the
fiction calls for it: all three shipped routines converge on `Spot_tavern` in the evening, and
`Spot_gate` covers both Tharr's midday patrol and Elara's afternoon supply run. `VillagerLoader` spawns
each NPC **directly at its current slot's anchor** (no walk-in on scene load/save load) and calls
`VillagerNpc.SetAnchor(pos)` whenever the resolved marker changes; `SetAnchor` re-centers wander on the
new anchor and, if not already there, **commutes** — walks at `CommuteSpeed` (70, brisker than
`WanderSpeed`) instead of wandering. If a commute makes no progress for `CommuteTeleportSeconds` (4s —
wedged on geometry), the NPC **warps** straight to the anchor rather than getting stuck forever; this
is a deliberate prototype-grade Stardew-style off-screen teleport, not pathfinding. `OutpostScene`
drives the re-anchor pass off `GameState.MinuteChanged`/`DayStarted` (`VillagerLoader.ApplySchedules`,
cheap — a villager whose slot hasn't flipped is skipped). Commuting obeys the same
suppression/`SetWanderEnabled` gates as wander (a dialogue or cutscene halts a mid-commute NPC in
place; it resumes on release). A schedule marker missing from the scene warns once (`GD.PushWarning`)
and keeps the previous anchor rather than crashing. Shipped routines: Tharr, Fenwick, and Elara
(`Schedules.cs`) — any other villager id with no entry there just wanders its home marker as always.

### Talk pools (`data/dialogues/**/*.json`, `scripts/data/dialogues/DialogueData.cs`)

`DialogueDatabase` recursively loads every `*.json` under `data/dialogues/` (GameState points it at
`res://data/dialogues`). A **TalkPool** file is indexed by its `character` id. Schema (see
`tharr_tutorial.json`):

```json
{
  "id": "mynpc_talk", "type": "TalkPool", "character": "mynpc",
  "entries": [
    { "priority": 50,
      "conditions": { "flags_required": ["some_flag"], "flags_blocked": ["other_flag"],
                      "hearts": { "mynpc": 4 }, "season": "spring" },
      "lines": [ { "speaker": "mynpc", "text": "...", "emotion": "neutral" } ],
      "effects": [ { "type": "flag", "set": "mynpc_greeted" } ],
      "choices": [ { "text": "...", "effects": [...], "next_id": "..." } ] }
  ]
}
```

On talk, `DialogueDatabase.GetTalkEntry` picks the **highest-`priority` entry whose conditions
pass** (all `flags_required` set, no `flags_blocked` set, all `hearts` met, `season` matches). All
condition fields are optional; `"conditions": {}` always passes — make that your priority-0 fallback
line. `effects` latch up front (types: `flag` / `friendship` / `item`); `choices` reuse the sequence
`DialogueOption` shape. `OutpostScene.TryTalkToVillager` tries the talk pool first; with no pool (or
no passing entry) it falls back to a one-line toast from the profile's `Personality`.

### Validation you must satisfy (`scripts/data/DataValidation.cs`, dev builds only)

- **Speakers** (`CheckDialogueSpeakers`): every `speaker` in a line/step must be a **registered
  `Characters` profile**. A talk pool for `"mynpc"` therefore requires a `mynpc` CharacterProfile —
  a hand-authored-only `VillagerDefinition` is not enough to speak.
- **Flags** (`CheckDialogueFlags`): every `flags_required`/`flags_blocked` id must resolve — either
  a **derived family** (building tier, villager-arrived, quest state; see `DerivedFlags`) or a member
  of the hardcoded `KnownStoryFlags` set. **If you introduce a new real story flag, add it to
  `KnownStoryFlags` in `DataValidation.cs`** or the check fails the build.

### Friendship (`scripts/cozy/FriendshipSystem.cs`, `characters/FriendshipProfile.cs`)

Optional and real but light: a `FriendshipProfile` (e.g. `Tharr.Friendship`) lists loved/liked/hated
items, birthday, and a `HeartUnlock[]` mapping a `Heart` threshold to an `EventId` string. The event
ids are hooks only — the consuming content is authored later. One mention; not required for a talkable NPC.

### Cutscene staging (pointer)

`DialogueStep` carries `actor` / `marker` / `direction` fields for staged sequences; the director
looks up a resident actor's live node through `VillagerLoader.GetPlaced(id)` to hide/reveal/walk it
in. See the intro/story sequences under `data/dialogues/` for shape. Out of scope for a basic NPC.

### Recruitability — honest status

`Recruitable` + `JoinPresetKey` name a PC preset in `PartyPresets`
(`scripts/presets/PartyPresets.cs`). **That registry ships EMPTY** (`PartyPresets.IsEmpty == true`) —
only the founding four (player/tharr/fenwick/elara) are assembled. So a recruitable villager can
arrive, be placed, and be talked to, but **nothing actually joins the combat squad in shipped play**.
The mechanism exists for future content; authoring a joinable recruit means also authoring a
`PartyPresetSpec` (builder + variant combo) and `Register`-ing it under the `JoinPresetKey`.

### Checklist — "Adding villager `x`"

1. **Profile** (preferred): copy `characters/_Template.cs` → `X.cs`, set `Id="x"`, `Kind`, and an
   `Arrival` trigger; add `X.Profile` to the `Characters.cs` registry. (Or a `VillagerDefinition` in
   `Villagers.cs` if no profile is warranted.)
2. **Marker**: in `outpost.tscn`, add a `Villager_x` Marker3D at the spot, *Access as Unique Name*.
3. **Sprite/portrait**: add `assets/sprites/heroes/<SpriteId>/p1.png` (or omit `SpriteId` for the
   `veteran` fallback); author the portrait for `PortraitId`.
4. **Talk pool**: add `data/dialogues/<area>/x_talk.json` (type `TalkPool`, `character:"x"`,
   priority-0 empty-condition fallback line). Requires a registered `x` profile for the speaker check.
5. **Daily routine** (optional): add a `VillagerSchedule` for `"x"` to `Schedules.cs`, entries in
   strictly ascending `MinuteOfDay` order, each naming a `%Spot_*` marker (reuse one of the five in
   `outpost.tscn` or place a new one). `CheckSchedules` requires: the id resolves in `Villagers` or
   `Characters`, at least one entry, non-empty marker names, minutes strictly ascending and within
   `DayClock.DayStartMinute`..`DayRolloverMinute` (6:00–30:00). Skip this step and `x` just wanders
   its home marker, same as every villager before this system existed.
6. **New flags**: any new real story flag used in a trigger or condition → add to `KnownStoryFlags`
   in `DataValidation.cs`, and wire whatever sets it in GameState.
7. **Verify**: build; headless boot runs `DataValidation.RunAll` (must report 0 violations); load the
   outpost, fire the arrival condition, walk up and press interact.

---

## Part 2 — Authoring a new enemy / encounter for expedition scenes

### The chain (read once)

Territory scene has hand-placed `%Roamer_<id>` markers → `TerritoryScene` spawns a `RoamingEnemy`
body at each → on contact it calls `GameState.BeginTerritoryEncounter` → `TerritorySystem.BeginEncounter`
rolls the roamer's **weighted encounter table**, resolves each `CreatureRef` through DataManager, and
builds a `CombatSetup` + return context → `SceneRouter.GoToCombat`. On victory,
`StoryDirector.OnCombatVictory` latches the roamer's `ClearsStoryFlag` if any.

### Creature refs & the PF2e packs (`scripts/data/EncounterTables.cs`)

A `CreatureRef` is `DisplayName`, `Pack`, `Slug`, optional `DropTableId`. It resolves via
`DataManager.FindCreature(DisplayName)` with a `LoadCreatureFile(Pack, Slug)` fallback. Creatures
come from the two packs on disk under `F:/dev/Pf2e.Core/Data/pf2e-source/packs/pf2e`
(`DataManager.Pf2eDataPath`): `pathfinder-monster-core` and `pathfinder-bestiary`. **The slug is the
kebab-cased compendium name** and `DisplayName` must be the real stat-block name (e.g.
`"Dire Wolf"` / `"dire-wolf"`) so `FindCreature` hits directly — the fiction's proper name lives on
the *encounter's* `DisplayName`, not the creature's. Verify the slug file exists in a pack before
using it; there is no plain "human bandit," so Brigands reskin dwarf/bugbear stat blocks (a
documented pattern).

`EncounterCreature` = `{ Creature, Count }`. `EncounterDefinition` = `{ Id, DisplayName, Creatures }`
— `DisplayName` is the "X attacks!" HUD line. `WeightedEncounter` = `{ EncounterId, Weight }`. Boss
example: `DireWolf` (1 `DireWolfBoss` + 2 `DireWolfPackmate`, a Severe-budget one-shot). Add new
`EncounterDefinition`s to the `Registry` array at the bottom of the file.

### Drop tables (`scripts/data/DropTables.cs`)

Keyed by `CreatureRef.DropTableId`. `DropTable` = `{ Id, Entries, CoinMin, CoinMax }`; `DropEntry` =
`{ ItemId, MinQty, MaxQty, Weight }` — a single weighted item pick plus a coin band, rolled once per
defeated creature. Common tables use a widened 1–3 band on the family's common part; elite/boss
tables weight the **trophy** heavily (weight 3, low qty) against a bonus common haul (weight 1).
Every `ItemId` must be a defined `Items` id (validated). Add the table to the `Registry` array.

### Roamer + weights (`scripts/data/Territories.cs`)

Add a `TerritoryRoamer` to the target territory's `Roamers` array: `RoamerId`, `Encounters`
(weighted list), optional `ClearsStoryFlag`, optional `IsBoss`. Mirror the existing weighting: common
variants weight 2–3, elite weight 1. A single-entry table is deterministic. Validation
(`CheckTerritories`) requires every `EncounterId` to resolve in `EncounterTables` and every
creature's `DropTableId` to resolve in `DropTables`.

### Marker placement (`scenes/territory/forest.tscn`, `scripts/territory/TerritoryScene.cs`)

**You hand-place a `Roamer_<id>` Marker3D in the .tscn** and *Access as Unique Name* (the forest
already has `Roamer_gob_1`…`Roamer_wolf_lair`, plus `%Node_<id>`, `%PlayerSpawn`, `%ExitTrigger`).
One cell is ONE METRE: cell (x, y) covers world X ∈ [x, x+1), Z ∈ [y, y+1). For each non-boss roamer
`TerritoryScene` instances `roaming_enemy.tscn` at `%Roamer_<id>`: `RoamingEnemy` (a
`CharacterBody3D` drawn as a billboarded rat) random-walks on the XZ plane inside a home radius,
chases within `SightRange`, and raises `PlayerContacted` once on contact (tunables in metres:
`WanderSpeed` 1.1, `ChaseSpeed` 2, `WanderRadius` 3, `SightRange` 3.8). A roamer beaten today stays
despawned until day start. Missing marker/scene → the roamer is silently skipped.

### Boss variant (optional)

Set `IsBoss = true` and give a `ClearsStoryFlag`. Boss sites are **not** spawned by the wandering
pass — `RefreshWolfLair` instances `wolf_lair.tscn` (a stationary `WolfLair`) at the boss's
`%Roamer_<id>` marker only while `WolfLair.ShouldAppear(questActive, wolfSlain)` is true (its quest
is active AND the flag is not yet latched — persists across save/load, so a slain boss never returns).
The boss-quest id is the scene export `WolfQuestId`. The lair uses the same `PlayerContacted` →
encounter hand-off as a roamer. Use `ExplorationTrigger` (an Area3D placed in the .tscn with a
`StoryFlag` or `QuestEvent` export) to latch "the party reached here" beats independently of combat.

### Combat visuals — what a NEW creature needs (`scripts/combat/EnemySpriteMap.cs`)

**Reality (2026-07): the only enemy combat art that exists is three rat variants** under
`res://assets/sprites/enemies/` (`rat_v1`/`v2`/`v3`, each an 8-frame side-view idle sheet
`idle_1.png`…`idle_8.png`). `EnemySpriteMap.FolderForCreature(displayName)` slugifies the creature's
**display name** and looks it up in a table that only has the three rat slugs; everything else —
including the Dire Wolf boss — falls back to `DefaultFolder` (`rat_v1`) and **renders as a rat.** So a
new creature works mechanically the moment its data is in, but to render as itself you must (a) add
`assets/sprites/enemies/<folder>/idle_1..8.png`, and (b) add a `["<slugified-display-name>"] =
Root + "<folder>"` row to `EnemySpriteMap.BySlug`. Note the key is the slugified DisplayName, not the
`CreatureRef.Slug` field.

### Story hook on kill (`scripts/quests/StoryDirector.cs`)

`OnCombatVictory(territoryId, roamerId)` latches `first_combat_victory`, records the
`combat_victory` quest event, then — if the beaten roamer has a `ClearsStoryFlag` — sets that flag
through the normal one-way latch, which drives quest completion and villager arrivals (e.g.
`first_expedition_cleared` → Arkus arrives; `dire_wolf_slain` → opens the Elderwood). That is the only
wiring needed to make a kill drive story: put the flag on the roamer.

### Checklist — "Adding enemy family `y` to the forest"

1. **Verify slugs**: confirm each creature's `Slug` file exists in `pathfinder-monster-core` or
   `pathfinder-bestiary` under `Pf2eDataPath`, and set `DisplayName` to the exact stat-block name.
2. **Encounters**: add `CreatureRef`(s) + `EncounterDefinition`(s) to `EncounterTables.cs` and the
   `Registry` array. Set the fiction name on the encounter `DisplayName`.
3. **Drops**: add `DropTable`(s) to `DropTables.cs` + `Registry`; point each `CreatureRef.DropTableId`
   at one. All item ids must exist in `Items`.
4. **Roamer**: add a `TerritoryRoamer` to `Territories.Forest.Roamers` with weighted `Encounters`.
5. **Marker**: hand-place `Roamer_y_1` Marker3D in `forest.tscn`, *Access as Unique Name*.
6. **Boss (optional)**: `IsBoss = true` + `ClearsStoryFlag`, place its `%Roamer_<id>` marker, and rely
   on the lair pattern (or add a dedicated lair scene modeled on `wolf_lair.tscn`).
7. **Visuals**: add the 8-frame idle sheet under `assets/sprites/enemies/<folder>/` and a
   `EnemySpriteMap.BySlug` row — otherwise it fights as a rat.
8. **Verify**: build; headless boot `DataValidation.RunAll` = 0 violations; travel to the forest and
   walk into the roamer to confirm the encounter and drops.
