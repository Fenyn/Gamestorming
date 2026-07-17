using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Data.Characters;
using Bulwark.Data.Dialogues;
using Bulwark.Territory;
using CharacterRegistry = Bulwark.Data.Characters.Characters;
using Godot;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Import;

using Bulwark.Save;
using Bulwark.Quests;
using Bulwark.Dialogue;
namespace Bulwark.Autoload;

/// <summary>
/// The single authoritative mutable state root. Thin Node adapter per CLAUDE.md: it hosts the plain
/// C# game systems (<see cref="DayClock"/>, <see cref="Inventory"/>, <see cref="FarmSystem"/>),
/// ticks the clock each frame, wires their events up as a single subscription hub for UI/world
/// scenes, and owns the file-path side of save/load. All mutation goes through intent-named command
/// methods that validate and let the systems raise change events — UI never mutates directly.
/// </summary>
public partial class GameState : Node, IArrivalContext
{
    public static GameState Instance { get; private set; } = null!;

    private const string SaveDir = "user://save";
    private const string SavePath = "user://save/slot0.json";

    /// <summary>One-generation backup of the previous save, rotated in by <see cref="SaveGame"/>'s
    /// atomic replace. <see cref="LoadGame"/> falls back to it when the primary save fails to parse.</summary>
    private const string BackupSavePath = "user://save/slot0.json.bak";

    /// <summary>Preset squad level for a NEW save (uniform). Banked level-ups applied on sleep move
    /// members past it (cap: <see cref="SquadRoster.MaxAppliedLevel"/>); saved members rebuild at
    /// their persisted level on load. Public: standalone scenes build fallback presets at this level.</summary>
    public const int SquadStartLevel = 2;

    /// <summary>
    /// Minute-of-day the squad becomes Fatigued when still awake. House-tuned to midnight (18 hours
    /// after the 6:00 wake) — softer than PF2e RAW's 16-hour mark so evenings stay cozy. Latched
    /// once per day; the 30:00 rollover re-applies as a backstop. Cleared only by a full night's
    /// rest (<see cref="Sleep"/>).
    /// </summary>
    public const int FatigueMinuteOfDay = 24 * 60;  // 1440 (midnight)

    /// <summary>Real seconds per in-game minute (fed to <see cref="DayClock"/>). ~18 real min/day at 0.75.</summary>
    [Export] public double RealSecondsPerGameMinute { get; set; } = 0.75;

    // --- Owned systems ---
    public DayClock Clock { get; private set; } = null!;
    public Inventory Inventory { get; private set; } = null!;
    public FarmSystem Farm { get; private set; } = null!;

    /// <summary>Phase-2 build loop: commission → tier-upgrade buildings via resource bundles.</summary>
    public BuildingSystem Building { get; private set; } = null!;

    /// <summary>
    /// Phase-4 building-effect aggregator: turns commissioned buildings' declarative effects into the
    /// queryable capability state the game systems consult (smithy tier, infirmary heal, farm caps,
    /// unlock sets). Derived from building state (never itself serialized); recomputed on
    /// BuildingChanged and load. Baseline (no buildings) → every query returns its ungated default.
    /// </summary>
    private OutpostEffects _effects = null!;

    /// <summary>The gold purse (Phase-1 combat-economy currency). Mutated only via commands.</summary>
    private Wallet _wallet = null!;

    /// <summary>The Trading Post (gold store): owns the general BUY (catalog) + SELL (any sellable) economy.
    /// Buy offerings widen as the smithy upgrades (reads the effect aggregator's smithy tier).</summary>
    private StoreSystem _store = null!;

    // Loot-roll RNG (own instance so it never perturbs other seeded systems). The Phase-1 forest
    // drop tables are min == max, so victory loot is deterministic regardless of this stream.
    private readonly Random _lootRng = new();

    /// <summary>Territory loop (M3): travel/party selection, resource nodes, roaming encounters.</summary>
    public TerritorySystem Territory { get; private set; } = null!;

    /// <summary>Forage daily-spawn system (design/forage.md). Private: scenes go through the
    /// SyncTerritoryForage command and GetLiveForage query below.</summary>
    private ForageSystem _forage = null!;

    /// <summary>Per-save world seed anchoring deterministic rolls (forage). Generated fresh for a
    /// new game; persisted in SaveData (pre-v12 saves adopt the generated one on their next save).</summary>
    private int _worldSeed;

    /// <summary>Phase-5 crafting loop: raw→refined artisan chains + kitchen meals, gated on station
    /// CategoryUnlocks. Charges craft-minutes on the clock and moves items through the inventory.</summary>
    public CraftingSystem Crafting { get; private set; } = null!;

    /// <summary>Phase-5 meal buff system: one day-long roster buff at a time; cleared on day rollover.</summary>
    private MealSystem _meals = null!;

    /// <summary>Per-fight/instant consumable layer (potions/elixirs/antidotes): the out-of-combat
    /// <see cref="UseItem"/> command and the in-combat "Use Item" action both route through it. Combat-scoped
    /// buffs only (no new persistence). Exposed so the combat layer can drive its round tick / cleanup.</summary>
    public ConsumableSystem Consumables { get; private set; } = null!;

    /// <summary>
    /// The live squad — four preset PCs built ONCE per save and reused across encounters so HP,
    /// conditions and spell-slot usage persist between fights (attrition). Null only when PF2e
    /// content failed to load (headless tooling without the data drive).
    /// </summary>
    public SquadRoster? Squad { get; private set; }

    /// <summary>Player-chosen name for the main character (persisted in save). Falls back to
    /// the profile default when null (pre-v7 saves or before the name-entry UI is built).</summary>
    public string? PlayerName { get; private set; }

    // Out-of-combat Treat Wounds (validation, immunity clock, view-models). Private: UI goes
    // through the TreatWounds command and GetSquadPanelView query below.
    private TreatWoundsSystem? _treatWounds;

    /// <summary>Phase-6 quest log: tracks tutorial and narrative quests with objectives and progress.</summary>
    private QuestLog _questLog = null!;

    /// <summary>Phase-3 bulwark story flags (a trigger source for villager arrivals + future quests).</summary>
    private StoryFlags _storyFlags = null!;

    /// <summary>Resolver for the DERIVED (virtual) flag families consulted by
    /// <see cref="HasFlagForConditions"/> before the real <see cref="_storyFlags"/> store. Built once
    /// over the static building/villager/quest catalogs, reading live system state via delegates.</summary>
    private DerivedFlags _derivedFlags = null!;

    /// <summary>
    /// Phase-3 static-cast arrivals: tracks which hand-authored villagers have shown up. Built over
    /// the SHIPPED (empty) catalog, so a no-op in shipped play — the framework the user fills later.
    /// </summary>
    private VillagerSystem _villagers = null!;

    /// <summary>
    /// The friendship / heart system (design/friendship.md): per-character points earned by gifts,
    /// daily talks, and quest/help awards. No decay. Heart thresholds fire once and feed the
    /// dialogue hook + the friendship effect source registered into <see cref="_effects"/>.
    /// </summary>
    private FriendshipSystem _friendship = null!;

    /// <summary>
    /// Dialogue session (design/dialogue.md): owns the loaded dialogue database, the once-only SEEN
    /// set (captured/restored by the save pipeline), the IsDialogueActive flag, and the
    /// start/end/mark commands. Empty database (no files) is the shipped baseline — a clean no-op.
    /// </summary>
    private DialogueSession _dialogue = null!;

    /// <summary>Smithy forge loop (rune application + weapon buying). Constructed only when the squad
    /// exists (PF2e content loaded); the forwarders null-guard on it (the <see cref="_treatWounds"/>
    /// precedent).</summary>
    private SmithySystem? _smithy;

    /// <summary>Hand-wired story / quest-trigger orchestrator: the tutorial quest chain, per-item and
    /// per-building quest hooks, milestone latches, repair-lodging rules, deliver-set resolution, and
    /// the single home of every recorded quest-event key. Owns the story content knowledge that used
    /// to live inline in this autoload.</summary>
    private StoryDirector _story = null!;

    // Once-per-day latch for the up-past-midnight fatigue rule (reset when a new day starts).
    private bool _squadFatigueLatched;

    // Running tally of the current day for the end-of-day summary. Transient by design: not
    // saved, so a mid-day quit loses the tallies (the next summary covers post-load play only).
    private readonly DayLedger _ledger = new();

    // One-shot hand-offs across the combat → world scene swaps (consumed by the arriving scene).
    private DefeatSummaryView? _pendingDefeatSummary;
    private DaySummaryView? _pendingDaySummary;
    private (string TerritoryId, Vector2 Position)? _pendingTerritoryReturn;

    // --- Event hub (UI/world subscribe here; systems remain the source of truth) ---
    public event Action? MinuteChanged;
    public event Action? HourChanged;
    public event Action? DayStarted;
    public event Action<Vector2I>? PlotChanged;
    public event Action<string>? InventoryChanged;

    /// <summary>Raised after the gold balance changes (loot, sale, smithy spend), with the new balance.</summary>
    public event Action<int>? GoldChanged;

    /// <summary>Raised after a smithy purchase resolves (rune applied or weapon bought) — UI refresh seam.</summary>
    public event Action? SmithyChanged;

    /// <summary>Raised after a successful <see cref="SellItem"/>, with the item id and quantity sold.</summary>
    public event Action<string, int>? ItemSold;

    /// <summary>Raised after a Trading Post transaction resolves (buy or sell) — UI refresh seam.</summary>
    public event Action? TradingPostChanged;

    /// <summary>Raised after a save file is loaded (initial autoload or explicit LoadGame).</summary>
    public event Action? GameLoaded;

    /// <summary>Raised after a building's state changes (commissioned / contributed / upgraded), with
    /// the building id — the loader re-places/refreshes that building's visual, the UI refreshes.</summary>
    public event Action<string>? BuildingChanged;

    /// <summary>Raised ONLY when a building's construction timer completes, with the building id — the
    /// world scene's one-shot "«Name» is complete." toast seam (distinct from the broader
    /// <see cref="BuildingChanged"/>, which also fires on commission/contribute/upgrade).</summary>
    public event Action<string>? ConstructionCompleted;

    /// <summary>Raised after the building-effect aggregator recomputes (commission/upgrade/load) — the
    /// UI/systems refresh capability-gated state (smithy shelf, farm caps, unlocked categories).</summary>
    public event Action? EffectsChanged;

    /// <summary>Raised after a story flag is newly set, with the flag id.</summary>
    public event Action<string>? StoryFlagChanged;

    /// <summary>Raised when a villager's arrival trigger first fires, with the villager id — the NPC
    /// loader spawns that character. Never fires in shipped play (empty catalog).</summary>
    public event Action<string>? VillagerArrived;

    /// <summary>Raised after a character's friendship points changed, with the character id — the
    /// friendship panel refresh seam.</summary>
    public event Action<string>? FriendshipChanged;

    /// <summary>Raised ONCE per (character, heart) the first time that heart level is reached —
    /// the future dialogue system consumes it (heart events); perk/recipe unlocks apply beneath it
    /// via the friendship effect source (already recomputed when this fires).</summary>
    public event Action<string, int>? HeartThresholdReached;

    /// <summary>Raised after a successful gift (charId, itemId, points delta) — HUD toast seam.</summary>
    public event Action<string, string, int>? GiftGiven;

    /// <summary>Raised after a villager joins the roster pool (pool grown), with the villager id.</summary>
    public event Action<string>? RosterMemberJoined;

    /// <summary>Raised after any squad-state change (encounter completion, rest, restore).</summary>
    public event Action? SquadChanged;

    /// <summary>Raised after a Treat Wounds command resolves, with the outcome view for the UI.</summary>
    public event Action<TreatWoundsResultView>? TreatWoundsResolved;

    /// <summary>Raised after a resource node's depleted state changes (harvest or respawn).</summary>
    public event Action<string>? TerritoryNodeChanged;

    /// <summary>Raised after a territory's forage spawn set changed (daily pass / sweep), with the
    /// territory id — the territory scene re-syncs its forage node views.</summary>
    public event Action<string>? ForageChanged;

    /// <summary>Raised after a successful craft, with the recipe id — UI refresh seam.</summary>
    public event Action<string>? RecipeCrafted;

    /// <summary>Raised after the active meal buff changes (eaten, replaced, cleared on rest).</summary>
    public event Action? MealChanged;

    /// <summary>Raised after a successful harvest, with the HUD view.</summary>
    public event Action<HarvestResultView>? ResourceHarvested;

    /// <summary>
    /// One-shot squad status lines for the HUD toast — the midnight exhaustion notice and the 30:00
    /// all-nighter dawn rollover. Passive UI seam (ResourceHarvested precedent): world scenes show
    /// the text, nothing consumes state.
    /// </summary>
    public event Action<string>? SquadStatusNotice;

    /// <summary>
    /// Raised by the sleep command when banked XP converted into level-ups overnight (member,
    /// from → to), after the rest resolved and the day was saved — UI announces on wake.
    /// </summary>
    public event Action<IReadOnlyList<SquadLevelUpView>>? SquadLeveledUp;

    /// <summary>Raised when a dialogue sequence starts playing, with the dialogue id.</summary>
    public event Action<string>? DialogueStarted;

    /// <summary>Raised when a dialogue sequence finishes playing.</summary>
    public event Action? DialogueEnded;

    /// <summary>Raised after a quest is started, with the quest id.</summary>
    public event Action<string>? QuestStarted;

    /// <summary>Raised after a quest is completed, with the quest id.</summary>
    public event Action<string>? QuestCompleted;

    /// <summary>Raised after a quest objective progresses, with the quest id and objective index.</summary>
    public event Action<string, int>? QuestObjectiveProgressed;

    public override void _Ready()
    {
        Instance = this;

        Clock = new DayClock { RealSecondsPerGameMinute = RealSecondsPerGameMinute };
        Inventory = new Inventory();
        Farm = new FarmSystem(Inventory, () => Clock.Season);
        _wallet = new Wallet();
        // Gold seam: building commission/upgrade can charge gold alongside the material bundle
        // (Stardew carpenter model). BuildingSystem stays a plain accounting class — it reads/spends
        // gold only through these injected delegates, never a direct Wallet reference.
        // flagSatisfied: the character-first commissionability gate resolves through HasFlagForConditions
        // (real + derived flags), so gated buildings (Smithy → arkus_arrived, Infirmary → josen_arrived)
        // stay hidden from the planning table until their arrival flag is set.
        Building = new BuildingSystem(Inventory, () => _wallet.Gold, _wallet.TrySpendGold, null, HasFlagForConditions);
        // Tutorial pacing (design/tutorial.md): each commission occupies Tharr for 1-2 days. The
        // one-at-a-time constraint keeps the player gathering/adventuring between builds.
        Building.SetConstructionDays(new Dictionary<string, int>
        {
            { "trading_post", 2 },
            { "farmhouse", 2 },
            { "smithy", 2 },
            { "infirmary", 2 },
            { "tavern", 2 },
        });

        // Phase-4 effect aggregator over the commissioned buildings' cumulative active effects, and
        // the farm capability provider that reads it. Built before the systems that consult it; the
        // source is empty until a building is commissioned, so every query starts at its baseline.
        _effects = new OutpostEffects(Building.ActiveEffects);
        _effects.Changed += () => EffectsChanged?.Invoke();
        Farm.SetCapabilities(() => _effects.FarmCapabilities);

        // Trading Post (gold store): buy from the catalog (stock widens with the smithy tier) + sell any
        // sellable carried item. Sale gold routes through the ledger-aware EarnGold; spends via the wallet.
        // Buy prices honour the aggregator's StorePriceDiscount (baseline 0 — a friendship heart perk seam).
        _store = new StoreSystem(Inventory, _wallet, EarnGold, () => _effects.SmithyTier,
            () => _effects.StorePriceDiscountPercent);
        // ItemSold feeds Share the Harvest's "Sell 3 goods to Elara" counter (routed through the story director).
        _store.ItemSold += (id, qty) => { ItemSold?.Invoke(id, qty); TradingPostChanged?.Invoke(); _story.OnItemSold(qty); };
        // A bought SEED ticks First Harvest's guidance "Buy seeds" objective (the story director owns the seed check).
        _store.GoodBought += (id, _) => { TradingPostChanged?.Invoke(); _story.OnGoodBought(id); };

        // The squad needs the PF2e packs (equipment/conditions/spells). DataManager is the first
        // autoload, so content is already loaded — the guard only trips when the data drive is
        // missing, in which case the cozy layer still runs without a squad.
        var dataManager = GetNodeOrNull<DataManager>("/root/DataManager");
        if (dataManager != null && dataManager.IsLoaded)
        {
            Squad = SquadRoster.BuildNew(SquadStartLevel, PlayerName);
            Squad.Changed += () => SquadChanged?.Invoke();

            _treatWounds = new TreatWoundsSystem(Squad, Clock, () => _effects.InfirmaryHealingBonus);
            _treatWounds.Resolved += view =>
            {
                _ledger.RecordTreatWounds();
                TreatWoundsResolved?.Invoke(view);
                _story.OnTreatWounds(); // Mend the Wounded completes on the first Treat Wounds
            };

            // Smithy forge loop (needs the live squad). Raises Changed on a successful rune/weapon
            // purchase — re-exposed as SmithyChanged, and the story director records the smithy_craft
            // quest event off the same signal (both purchase paths counted, exactly as before).
            _smithy = new SmithySystem(Squad, _wallet, Inventory, () => _effects.SmithyTier);
            _smithy.Changed += () => { SmithyChanged?.Invoke(); _story.OnSmithyCraft(); };
        }
        else
        {
            GD.PushWarning("[GameState] PF2e content not loaded — squad unavailable this session.");
        }

        // Forage spawns (design/forage.md): built before the territory system so harvests can
        // resolve forage node ids. The world seed anchors deterministic daily passes; a load
        // below overwrites it with the persisted seed.
        _worldSeed = Random.Shared.Next(1, int.MaxValue);
        _forage = new ForageSystem();
        _forage.SetWorldSeed(_worldSeed);
        _forage.ForageChanged += id => ForageChanged?.Invoke(id);

        // Territory loop runs even without a squad (harvest still works); encounters need both the
        // squad and the creature resolver, so BeginTerritoryEncounter degrades to a clean refusal.
        Territory = new TerritorySystem(
            Inventory, Clock, Squad,
            Squad != null ? @ref => dataManager!.ResolveCreature(@ref) : null,
            _forage);
        Territory.SetWorldSeed(_worldSeed);
        Territory.NodeChanged += id => TerritoryNodeChanged?.Invoke(id);
        Territory.ResourceHarvested += view => ResourceHarvested?.Invoke(view);

        // Phase-5 provisions: crafting (station-gated on the effect aggregator's unlocked categories)
        // and the roster meal buff (applied to the live squad; a no-op eater when the squad is absent).
        Crafting = new CraftingSystem(Inventory, Clock, IsCategoryUnlocked);
        Crafting.Crafted += id => RecipeCrafted?.Invoke(id);
        _meals = new MealSystem(Squad);
        _meals.Changed += () => MealChanged?.Invoke();
        Consumables = new ConsumableSystem(Squad);

        // Phase-3 story flags + villager arrivals. Built here (before the event wiring) so the
        // trigger-source closures below can drive EvaluateArrivals. The villager system reads this
        // GameState as its IArrivalContext (building tiers, flags, calendar) over the SHIPPED
        // (empty) catalog — a no-op in shipped play.
        _storyFlags = new StoryFlags();
        _villagers = new VillagerSystem(this);
        _storyFlags.FlagSet += id =>
        {
            StoryFlagChanged?.Invoke(id);
            _villagers.EvaluateArrivals();
            _story.EvaluateQuests();
        };
        _villagers.Arrived += id =>
        {
            VillagerArrived?.Invoke(id);
            // An arrival flips the derived "<id>_arrived" flag (see HasFlagForConditions) — re-evaluate
            // quests so arrival-gated quests (The Smith's Fire, Mend the Wounded) auto-start no matter
            // which trigger source produced the arrival (story flag, building tier, or calendar/day).
            _story.EvaluateQuests();
        };

        // Friendship / hearts (design/friendship.md): points per character, earned by gifts (from
        // the party inventory), daily talks, and quest awards. Presence = starting PC (always at
        // the outpost) or an ARRIVED villager. Its earned heart perks/unlocks register as an
        // ADDITIONAL effect source in the aggregator (additive with building effects; empty at
        // baseline, so shipped behaviour is unchanged until hearts are earned).
        _friendship = new FriendshipSystem(Inventory, Clock, IsCharacterPresent);
        _friendship.FriendshipChanged += id => FriendshipChanged?.Invoke(id);
        _friendship.GiftGiven += (id, item, delta) => GiftGiven?.Invoke(id, item, delta);
        _friendship.HeartThresholdReached += (id, heart) =>
        {
            // Recompute BEFORE announcing so subscribers observe the settled unlock state
            // (perk effects landed, categories unlocked). The eventId on the profile's unlock
            // entry is the Phase-4 dialogue hook — consumed by the future dialogue system.
            _effects.Recompute();
            HeartThresholdReached?.Invoke(id, heart);
            // A heart crossing is a villager-arrival trigger source (FriendshipReached) — the
            // StoryFlagChanged/BuildingChanged pattern. No-op over the shipped (empty) catalog.
            _villagers.EvaluateArrivals();
        };
        _effects.AddSource(_friendship.ActiveEffects);

        // Dialogue session: load all JSON files from res://data/dialogues/ into the database (missing or
        // empty directory is a clean no-op — the shipped baseline, framework only), then hand it to the
        // DialogueSession that owns the seen-set / active flag / start-end commands. Re-expose its
        // start/end events through the hub.
        string dialoguePath = ProjectSettings.GlobalizePath("res://data/dialogues");
        var dialogueDb = new DialogueDatabase(dialoguePath);
        _dialogue = new DialogueSession(dialogueDb, HasFlagForConditions, HeartsOf, Clock);
        _dialogue.DialogueStarted += id => DialogueStarted?.Invoke(id);
        _dialogue.DialogueEnded += () => DialogueEnded?.Invoke();

        // Wire heart-event auto-play: when a heart threshold fires with a non-null EventId, queue
        // the dialogue to play AFTER the threshold handler finishes (CallDeferred so the threshold
        // event completes before the dialogue starts). No-op if the dialogue doesn't exist (the
        // EventId is a HOOK — content is authored later).
        _friendship.HeartThresholdReached += (charId, heart) =>
        {
            var profile = Friendships.Get(charId);
            foreach (var unlock in profile.Unlocks)
            {
                if (unlock.Heart == heart && !string.IsNullOrEmpty(unlock.EventId))
                {
                    string eventId = unlock.EventId;
                    Callable.From(() => StartDialogue(eventId)).CallDeferred();
                }
            }
        };

        // Phase-6 quest log: register all tutorial quest definitions and wire events. The quest
        // log is a plain C# system; the definitions come from the data registry.
        _questLog = new QuestLog();
        _questLog.RegisterAll(Bulwark.Data.Quests.All);
        _questLog.QuestStarted += id => QuestStarted?.Invoke(id);
        _questLog.QuestCompleted += id => QuestCompleted?.Invoke(id);
        _questLog.ObjectiveProgressed += (id, idx) => QuestObjectiveProgressed?.Invoke(id, idx);

        // Derived (virtual) flag resolver: consulted by HasFlagForConditions before the real flag
        // store. Built once over the static catalogs; reads live building/villager/quest state through
        // these delegates. Constructed after the systems it queries (Building, _villagers, _questLog).
        _derivedFlags = new DerivedFlags(
            anyUnderConstruction: Building.AnyUnderConstruction,
            buildingTier: Building.GetTier,
            buildingUnderConstruction: Building.IsUnderConstruction,
            villagerArrived: _villagers.HasArrived,
            questCompleted: _questLog.IsCompleted,
            questActive: _questLog.IsActive);

        // Story / quest-trigger orchestrator: owns the hand-wired tutorial chain, the per-item /
        // per-building quest hooks, the milestone latches, the repair-lodging rules, the deliver-set
        // resolution, and every recorded quest-event key. Narrow delegates (flag get/set, building /
        // trophy queries, the saving SetStoryFlag command, the casualty predicate) plus the QuestLog +
        // Inventory it drives — never this GameState. Constructed after the systems it queries
        // (Building, _questLog, _derivedFlags via HasFlagForConditions).
        _story = new StoryDirector(
            _questLog, Inventory,
            hasFlagForConditions: HasFlagForConditions,
            hasFlagRaw: _storyFlags.Has,
            setFlagRaw: _storyFlags.Set,
            setStoryFlag: SetStoryFlag,
            buildingTier: Building.GetTier,
            commissionedCount: Building.CommissionedCount,
            anyCasualty: () => Squad?.Members.Any(m =>
                (m.Health?.IsDead ?? false) || (m.Conditions?.HasCondition(Condition.Wounded) ?? false)) ?? false,
            // Day-1 tutorial time freeze: the story director pauses/resumes the day clock via a named
            // reason (intro_complete freezes; the scripted day close's first_rest resumes).
            setClockPaused: Clock.SetPaused);

        // Re-expose system events through the hub (minutes also feed the fatigue latch; a new
        // day resets it).
        Clock.MinuteChanged += OnClockMinuteChanged;
        Clock.HourChanged += () => HourChanged?.Invoke();
        Clock.DayStarted += OnClockDayStarted;
        Clock.DayEnded += OnClockDayEnded;
        Farm.PlotChanged += tile => PlotChanged?.Invoke(tile);
        Inventory.InventoryChanged += id => InventoryChanged?.Invoke(id);
        // Building tier changes recompute the effect aggregator (capabilities may have shifted) and
        // are a villager-arrival trigger source (both re-evaluated after the BuildingChanged event).
        Building.Changed += id =>
        {
            _effects.Recompute();
            BuildingChanged?.Invoke(id);
            _villagers.EvaluateArrivals();
        };
        Building.ConstructionCompleted += id => ConstructionCompleted?.Invoke(id);
        Building.ConstructionCompleted += _story.OnConstructionCompleted;
        _wallet.GoldChanged += gold => GoldChanged?.Invoke(gold);

        // Bind the squad so gains distribute per-member (PF2e Bulk carry) and encumbrance applies.
        // Unbound (no squad — data drive missing) the inventory degrades to a single flat pool.
        if (Squad != null)
            Inventory.BindSquad(Squad);

        // Refinement 1: the warehouse is physical outpost-only storage — reachable in the Outpost mode,
        // out of reach in the field (Territory/Combat). Mirror SceneRouter's mode onto the inventory so
        // field reads/consumes see only what members physically carry. Deferred: SceneRouter autoloads
        // after GameState, so its Instance isn't live yet in _Ready (and this also sets the boot state).
        Callable.From(WireWarehouseAccess).CallDeferred();

        // Auto-load or seed: the title screen routes to outpost (Continue) or calls StartNewGame
        // (which clears and re-seeds). This ensures spikes and other standalone paths still work.
        if (SaveExists())
            LoadGame();
        else
            SeedStarterInventory();

        // Day-ledger capture attaches AFTER the initial load/seed, so neither the starter
        // inventory nor anything a restore repopulates counts as "gained today" (belt and
        // suspenders: SaveState.Restore refills via Inventory.LoadFrom, which never raises
        // ItemAdded). Every later gain — farm harvest, territory node yield, direct grant —
        // flows through this single choke point.
        Inventory.ItemAdded += (id, qty) => _ledger.RecordItemGained(id, qty);
        // Framework seam (eight_trophies_collected): re-check the trophy-count milestone on every gain
        // (loot; sale reversal N/A — sells remove, never add). CountEverywhere-based in the story
        // director, so it self-corrects regardless of which trophy id(s) pushed the total over.
        Inventory.ItemAdded += (_, _) => _story.CheckEightTrophiesMilestone();

        // Quest trigger wiring: story flags and inventory changes drive quest progress through the
        // story director (intro_complete → start repair_lodging; wood/stone → repair_lodging progress).
        _storyFlags.FlagSet += _story.OnStoryFlag;
        Inventory.ItemAdded += _story.OnItemAdded;

        // Building commission hook: first building commissioned → complete first_building quest.
        Building.Changed += _story.OnBuildingChanged;
    }

    public override void _Process(double delta)
    {
        Clock.Tick(delta); // no-op while paused (SceneRouter pauses during combat)
    }

    // ===================== Commands (validate → delegate → systems raise events) =====================

    public bool TillPlot(Vector2I tile) => Farm.TillPlot(tile);

    /// <summary>
    /// Wiring, not state: the farm world scene binds its tillability predicate (farmable tiles
    /// minus occupied cells) on enter and clears it (null) on exit, so farm commands are gated by
    /// what the current map allows and a freed scene is never queried.
    /// </summary>
    public void BindFarmWorld(Func<Vector2I, bool>? isTillable) => Farm.SetTillable(isTillable);

    public bool PlantCrop(Vector2I tile, string cropId) => Farm.PlantCrop(tile, cropId);
    public bool WaterPlot(Vector2I tile) => Farm.WaterPlot(tile);

    /// <summary>Harvest a mature farm plot. A success also tallies the day ledger's crop count
    /// (the yield items themselves are counted by the inventory's ItemAdded choke point).</summary>
    public bool HarvestPlot(Vector2I tile)
    {
        bool harvested = Farm.HarvestPlot(tile);
        if (harvested)
        {
            _ledger.RecordCropHarvested();
            _story.OnCropHarvested(); // First Harvest counter (one tick per harvested plot)
        }
        return harvested;
    }

    public void AddItem(string itemId, int qty) => Inventory.AddItem(itemId, qty);
    public bool RemoveItem(string itemId, int qty) => Inventory.RemoveItem(itemId, qty);

    // ===================== Per-member carry: warehouse offload (outpost) =====================

    /// <summary>
    /// Command: move items from a member's carry into the shared outpost warehouse — the way to shed
    /// Bulk and clear encumbrance. Delegates to the inventory facade (validates ownership, recomputes
    /// encumbrance); on success emits <see cref="SquadChanged"/> so a squad/inventory panel refreshes
    /// (the member's Encumbered state may have just changed). InventoryChanged rides the facade's event.
    /// </summary>
    public bool DepositToWarehouse(string memberId, string itemId, int qty)
    {
        bool ok = Inventory.DepositToWarehouse(memberId, itemId, qty);
        if (ok)
            SquadChanged?.Invoke();
        return ok;
    }

    /// <summary>
    /// Command: move items from the warehouse into a member's carry. Delegates to the facade, which
    /// rejects a withdrawal that would break the member's hard cap (10 + Str mod) and recomputes
    /// encumbrance. Emits <see cref="SquadChanged"/> on success.
    /// </summary>
    public bool WithdrawFromWarehouse(string memberId, string itemId, int qty)
    {
        bool ok = Inventory.WithdrawFromWarehouse(memberId, itemId, qty);
        if (ok)
            SquadChanged?.Invoke();
        return ok;
    }

    /// <summary>Query: per-member carry + warehouse + gold view-model (future inventory screen seam).</summary>
    public InventoryView GetInventoryView() => Inventory.BuildView(_wallet.Gold);

    // ===================== Phase-2 build loop: planning table =====================

    /// <summary>
    /// Command: commission a building from the planning table — validate the construction bundle AND
    /// its gold cost are fully affordable, consume the bundle and spend the gold (via the wallet
    /// delegates wired into <see cref="Building"/>), mark the building Built at tier 1. Rejects
    /// cleanly (false, nothing consumed) otherwise. Emits <see cref="BuildingChanged"/>, latches the
    /// eight-buildings milestone (if just reached) BEFORE saving — mirroring
    /// <see cref="CompleteEncounter"/>'s flag-then-save ordering — so a flag latched by THIS
    /// commission rides the same save as the building itself, and saves so the freshly commissioned
    /// building survives a crash.
    /// </summary>
    public bool CommissionBuilding(string buildingId)
    {
        if (!Building.Commission(buildingId))
            return false;
        // Friendship quest-award hook: restoring a character's associated building grants that
        // character a point chunk (before the save below, so the award persists with the tier).
        FriendshipAwards.OnBuildingAdvanced(buildingId, isCommission: true, CharacterRegistry.All, _friendship);
        // Framework seam (eight_buildings_constructed): check BEFORE the save below, not after — a flag
        // latched here must persist in THIS save, not float in memory only until some unrelated later
        // save (or be lost entirely if the player quits first). The story director owns the rule.
        _story.CheckEightBuildingsMilestone();
        SaveGame();
        return true;
    }

    /// <summary>
    /// Command: contribute items toward a building's next-tier upgrade bundle — consumes from the
    /// party inventory and accumulates on the building (partials allowed). Rejects cleanly when the
    /// contribution is invalid (not commissioned, at max tier, item not in the bundle, overshoot, or
    /// insufficient inventory). Emits <see cref="BuildingChanged"/>.
    /// </summary>
    public bool ContributeBundle(string buildingId, string itemId, int qty)
        => Building.Contribute(buildingId, itemId, qty);

    /// <summary>
    /// Command: advance a building to its next tier once the upgrade bundle is complete AND the
    /// tier's gold cost is affordable (charged all-at-once, via the same wallet delegates). Rejects
    /// cleanly when incomplete, gold-short, or already at max tier. Emits <see cref="BuildingChanged"/>
    /// (the loader swaps the building's visual stage) and saves.
    /// </summary>
    public bool UpgradeBuilding(string buildingId)
    {
        if (!Building.Upgrade(buildingId))
            return false;
        // Friendship quest-award hook: a tier upgrade grants the associated character a smaller chunk.
        FriendshipAwards.OnBuildingAdvanced(buildingId, isCommission: false, CharacterRegistry.All, _friendship);
        SaveGame();
        return true;
    }

    /// <summary>Query: current tier of a building (0 = not commissioned). Used by the placement loader.</summary>
    public int GetBuildingTier(string buildingId) => Building.GetTier(buildingId);

    /// <summary>Query: the planning-table view-model (per building: state, tier, target bundle
    /// have/need, gold cost + affordability, commission/upgrade affordability, effects).</summary>
    public PlanningTableView GetPlanningTableView() => Building.BuildView();

    /// <summary>Query: whether any building is currently under construction.</summary>
    public bool AnyBuildingUnderConstruction => Building.AnyUnderConstruction();

    /// <summary>
    /// Command: repair the outpost lodging — the simple "bring materials to Tharr" task before the full
    /// building system. Forwards to the story director, which owns the material rule (15 wood + 10 stone)
    /// and the lodging story beats. Returns false (clean reject) when the materials are insufficient or
    /// the lodging is already repaired.
    /// </summary>
    public bool RepairLodging() => _story.TryRepairLodging();

    // ===================== Phase-4: building-effect capability queries + grant seams =====================

    /// <summary>Query: the smithy catalog/rune unlock ceiling (baseline <see cref="SmithyTier.Base"/>).</summary>
    public SmithyTier SmithyTier => _effects.SmithyTier;

    /// <summary>Query: additive Treat-Wounds/rest healing bonus from the infirmary (baseline 0).</summary>
    public int InfirmaryHealingBonus => _effects.InfirmaryHealingBonus;

    /// <summary>Query: whether a category id is unlocked by an active CategoryUnlock effect (generic
    /// seam — future features gate on membership without new framework). Baseline: nothing unlocked.</summary>
    public bool IsCategoryUnlocked(string categoryId) => _effects.IsCategoryUnlocked(categoryId);

    /// <summary>Query: every unlocked category id (empty at baseline).</summary>
    public IReadOnlyCollection<string> UnlockedCategories => _effects.UnlockedCategories;

    /// <summary>Query: whether a territory/biome id is opened for travel — either by an active
    /// BiomeUnlock building effect (no shipped building grants one currently; the Sunken Reach's unlock
    /// is TBD, deferred with the Command Post's upgrade tiers) OR by the territory's own
    /// <see cref="TerritoryDefinition.UnlockFlagId"/> story-flag gate (the Elderwood → dire_wolf_slain:
    /// the wolf guards the passage). The territory-side deep-forest sign gates travel on this. Baseline:
    /// nothing unlocked.</summary>
    public bool IsBiomeUnlocked(string territoryId)
        => _effects.IsBiomeUnlocked(territoryId)
           || (Territories.TryGet(territoryId, out var def)
               && !string.IsNullOrEmpty(def.UnlockFlagId)
               && HasFlagForConditions(def.UnlockFlagId));

    /// <summary>Query: whether the farm's auto-watering capability is active (baseline false).</summary>
    public bool FarmAutoWater => Farm.AutoWaterEnabled;

    /// <summary>Query: whether the farm's greenhouse capability is active (baseline false).</summary>
    public bool FarmGreenhouse => Farm.GreenhouseEnabled;

    /// <summary>Query: the farm TILLABLE-AREA expansion level (Refinement 2) — unlocks farmable tile
    /// zones ≤ level; the outpost scene's IsTillable gate reads this. Baseline 0 (base zone only).</summary>
    public int FarmTillableAreaLevel => Farm.TillableAreaLevel;

    /// <summary>
    /// Command (PF2e feature-grant seam): grant a spell (by SpellDatabase id) to a squad caster's
    /// known list via <see cref="SpellAccessSeam"/> — a bulwark CALL into the engine, no engine edit.
    /// Plumbing for a future Arcane Study spell-unlock effect; not driven by any committed content.
    /// Rejects cleanly when the member is unknown/not a caster, the id is unknown, or already known.
    /// Emits <see cref="SquadChanged"/> on success.
    /// </summary>
    public bool GrantSpellToMember(string memberId, string spellId)
    {
        var member = Squad?.FindMember(memberId);
        if (member == null || !SpellAccessSeam.GrantSpell(member, spellId))
            return false;
        SquadChanged?.Invoke();
        return true;
    }

    // ===================== Phase-3: story flags + villager arrival + party join =====================

    /// <summary>
    /// Command: set a bulwark story flag (a story beat happened). Idempotent — re-setting an
    /// already-set flag is a no-op (false). On a NEW set, emits <see cref="StoryFlagChanged"/>,
    /// re-evaluates villager arrivals (a story flag is a trigger source), and saves so the beat
    /// survives a crash.
    /// </summary>
    public bool SetStoryFlag(string flagId)
    {
        if (!_storyFlags.Set(flagId))
            return false;
        SaveGame();
        return true;
    }

    /// <summary>Query: whether a story flag is set (also serves the villager IArrivalContext).</summary>
    public bool HasStoryFlag(string flagId) => _storyFlags.Has(flagId);

    /// <summary>Query: whether a villager has arrived at the outpost (always false in shipped play).</summary>
    public bool IsVillagerArrived(string villagerId) => _villagers.HasArrived(villagerId);

    /// <summary>Query: ids of every arrived villager (empty in shipped play).</summary>
    public IReadOnlyCollection<string> ArrivedVillagers => _villagers.ArrivedIds;

    /// <summary>
    /// Command: an arrived, recruitable villager joins the ROSTER POOL — inserts its referenced PC
    /// preset as an additional roster member (pool grows by one). This does NOT enlarge the
    /// adventuring party: the party is always a selection of ≤4 from the pool, formed at the gate
    /// (GetPartySelectView / TravelToTerritory). Validates via <see cref="RosterJoin"/> (arrived +
    /// recruitable + preset registered + not already present). Rejects cleanly (false) otherwise —
    /// including EVERY call in shipped play, where the villager catalog and PartyPresets are empty.
    /// On success emits <see cref="SquadChanged"/> + <see cref="RosterMemberJoined"/> and saves so
    /// the grown roster survives a crash.
    /// </summary>
    public bool JoinRoster(string villagerId)
    {
        if (Squad == null || !_villagers.TryGet(villagerId, out var def))
            return false;

        var member = RosterJoin.TryAdd(Squad, _villagers, def, Squad.Level);
        if (member == null)
            return false;

        SquadChanged?.Invoke();
        RosterMemberJoined?.Invoke(villagerId);
        SaveGame();
        return true;
    }

    // ===================== Friendship / hearts (design/friendship.md) =====================

    /// <summary>
    /// Command: give one unit of a carried item to a present character. Validates befriendable +
    /// present + item carried + weekly gift cadence (2/character/week) — a rejected gift consumes
    /// NOTHING. On success consumes the item from the party inventory and applies the character's
    /// preference-tier points (×8 on their birthday; floor 0 on a bad gift). Emits
    /// <see cref="GiftGiven"/> + <see cref="FriendshipChanged"/> (+ threshold events as crossed).
    /// Not saved here — friendship rides the sleep/encounter save cadence (crafting precedent).
    /// </summary>
    public bool GiveGift(string charId, string itemId) => _friendship.GiveGift(charId, itemId);

    /// <summary>
    /// Command: talk to a present character — the first conversation each day grants +12 points;
    /// repeats the same day are a clean no-op (false). Emits <see cref="FriendshipChanged"/>.
    /// </summary>
    public bool TalkTo(string charId) => _friendship.Talk(charId);

    /// <summary>
    /// Command: award friendship points to a character from dialogue effects. Routes through the
    /// friendship system's quest/help award seam.
    /// </summary>
    public bool AddDialogueFriendship(string charId, int amount)
        => _friendship.AddFriendship(charId, amount, "dialogue");

    /// <summary>Query: the friendship-panel view — every befriendable, PRESENT character (starting
    /// PCs and arrived villagers) with hearts/points/cadence/birthday state, plus carried gift
    /// options. Engine-free view-model.</summary>
    public FriendshipView GetFriendshipView()
        => _friendship.BuildView(CharacterRegistry.All.Select(p => (p.Id, p.DefaultName)));

    /// <summary>A character is present at the outpost when they are a starting PC (there from day
    /// one) or an arrived villager (recruitables/townsfolk after their trigger fires).</summary>
    private bool IsCharacterPresent(string charId)
        => (CharacterRegistry.TryGet(charId, out var p) && p.Kind == CharacterKind.StartingPC)
           || _villagers.HasArrived(charId);

    // --- IArrivalContext (the villager triggers read live state through these) ---

    /// <summary>Absolute day ordinal for DateReached triggers (28 days/season, 4 seasons/year).</summary>
    public int CurrentDayOrdinal => ArrivalTrigger.Ordinal(Clock.Year, Clock.Season, Clock.Day);

    /// <summary>Query: the party's total CURRENT count of an item — carry + warehouse, regardless of
    /// scene mode (also serves the villager IArrivalContext's ItemCountReached trigger).</summary>
    public int CountItem(string itemId) => Inventory.CountEverywhere(itemId);

    /// <summary>Query: a character's current friendship heart level (0 when never befriended or the
    /// friendship system isn't built yet — defensive; it is constructed in _Ready). Also serves the
    /// villager IArrivalContext's FriendshipReached trigger.</summary>
    public int HeartsOf(string characterId) => _friendship?.HeartsOf(characterId) ?? 0;

    // ===================== Dialogue / cutscene (design/dialogue.md) =====================
    // Thin forwarders to the DialogueSession owner; the session raises DialogueStarted / DialogueEnded,
    // re-exposed through the hub (wired in _Ready).

    /// <summary>True while a dialogue sequence is actively playing (forwards to the session).</summary>
    public bool IsDialogueActive => _dialogue.IsDialogueActive;

    /// <summary>
    /// Command: start a dialogue sequence by id. Validates the sequence exists, conditions pass, and it
    /// has not been seen (if once-only). Returns false (clean reject) otherwise. On success fires
    /// <see cref="DialogueStarted"/> and sets <see cref="IsDialogueActive"/>. The caller (world scene)
    /// wires the runner to a dialogue box and a cutscene director.
    /// </summary>
    public bool StartDialogue(string sequenceId) => _dialogue.StartDialogue(sequenceId);

    /// <summary>
    /// Command: start a talk-pool dialogue for a character. Returns false if no talk pool exists or no
    /// entry passes conditions (caller falls back to toast). On success fires <see cref="DialogueStarted"/>.
    /// </summary>
    public bool StartTalkDialogue(string charId) => _dialogue.StartTalkDialogue(charId);

    /// <summary>Called by the dialogue system when a sequence ends.</summary>
    public void EndDialogue() => _dialogue.EndDialogue();

    /// <summary>Query: whether a dialogue id has been seen (for once-only gating).</summary>
    public bool HasSeenDialogue(string id) => _dialogue.HasSeenDialogue(id);

    /// <summary>Mark a dialogue as seen (called by the runner when a once-only sequence ends).</summary>
    public void MarkDialogueSeen(string id) => _dialogue.MarkDialogueSeen(id);

    /// <summary>The seen dialogue ids (for save capture).</summary>
    public IReadOnlyCollection<string> SeenDialogues => _dialogue.Seen;

    /// <summary>Query: the dialogue database (for talk-pool queries by the world scene).</summary>
    public DialogueDatabase DialogueDb => _dialogue.Db;

    /// <summary>Build a condition context from the current game state.</summary>
    public DialogueConditionContext BuildConditionContext() => _dialogue.BuildConditionContext();

    /// <summary>
    /// Flag lookup shared by dialogue conditions (<see cref="BuildConditionContext"/>) AND building
    /// visual rules (the <see cref="Bulwark.Cozy.BuildingLoader"/> hasFlag delegate, wired in
    /// OutpostScene). Consults the <see cref="DerivedFlags"/> resolver first — the DERIVED (virtual)
    /// flag families, live-queried off <see cref="Building"/>/<see cref="_villagers"/>/<see cref="_questLog"/>
    /// and never persisted / never settable via <see cref="SetStoryFlag"/> — then falls through to the
    /// real <see cref="_storyFlags"/> store when no derived family resolves true. See
    /// <see cref="DerivedFlags"/> for the family list and semantics (and the uniform fall-through rule
    /// that keeps a directly-set "&lt;villager&gt;_arrived" real flag reading true).
    /// </summary>
    public bool HasFlagForConditions(string flagId)
        => _derivedFlags.Resolve(flagId) || _storyFlags.Has(flagId);

    // ===================== Economy: gold, selling, smithy =====================

    /// <summary>Query: current gold balance.</summary>
    public int Gold => _wallet.Gold;

    /// <summary>
    /// Command: credit gold (loot coin, item sales) and tally it into the day ledger — the single
    /// choke point every gain flows through, so the end-of-day summary's gold line stays accurate.
    /// Non-positive amounts are a no-op (the wallet would throw; this guards the internal callers).
    /// </summary>
    public void EarnGold(int amount)
    {
        if (amount <= 0)
            return;
        _wallet.EarnGold(amount);
        _ledger.RecordGoldEarned(amount);
    }

    /// <summary>
    /// Command: sell <paramref name="qty"/> of a sellable item for gold — the Trading Post's SELL path
    /// (reframe: the store owns buy/sell, not the smithy). Delegates to <see cref="StoreSystem.Sell"/>,
    /// which validates the item is defined + sellable and the stack covers the quantity BEFORE any
    /// mutation, removes the items, and credits the gold through the day-ledger choke point. Rejects
    /// cleanly (false, no change) otherwise. Emits <see cref="ItemSold"/> + <see cref="TradingPostChanged"/>
    /// + <see cref="GoldChanged"/>.
    /// </summary>
    public bool SellItem(string itemId, int qty) => _store.Sell(itemId, qty);

    /// <summary>
    /// Command: buy <paramref name="count"/> units of a Trading Post catalog good for gold. Delegates to
    /// <see cref="StoreSystem.Buy"/>, which validates the offer is stocked at the current smithy tier
    /// (smithy upgrades widen the stock), gold covers the cost, AND the goods fit the party's Bulk carry
    /// cap — all BEFORE spending. A rejected buy (locked / unaffordable / won't-fit) consumes NOTHING.
    /// Emits <see cref="TradingPostChanged"/> + <see cref="GoldChanged"/> + <see cref="InventoryChanged"/>.
    /// </summary>
    public bool BuyGood(string itemId, int count = 1) => _store.Buy(itemId, count);

    /// <summary>Query: the Trading Post view-model — gold, buy offers (with unlock/afford/fit), and the
    /// sell shelf (carried sellable stacks).</summary>
    public TradingPostView GetTradingPostView() => _store.BuildView();

    /// <summary>
    /// Command: apply a fundamental rune to a member's main-hand weapon. Thin forwarder to
    /// <see cref="SmithySystem"/> (null-guarded on the squad's presence, the TreatWounds precedent),
    /// which owns the reagent-before-gold validation and applies the rune in place. On success the
    /// system raises Changed, re-exposed here as <see cref="SmithyChanged"/> (the story director records
    /// the smithy_craft quest event off the same signal). Not saved here — the applied rune rides the
    /// sleep/encounter save cadence additively.
    /// </summary>
    public bool ApplyWeaponRune(string memberId, RuneKind kind) => _smithy?.ApplyWeaponRune(memberId, kind) ?? false;

    /// <summary>
    /// Command: buy a catalog weapon and equip it to a member. Thin forwarder to
    /// <see cref="SmithySystem"/>, which owns the shelf lookup, metal-before-gold validation, and
    /// re-equip. On success the system raises Changed (re-exposed as <see cref="SmithyChanged"/>). Null
    /// (squad unavailable) → clean reject.
    /// </summary>
    public bool BuyWeapon(string memberId, string weaponSlug) => _smithy?.BuyWeapon(memberId, weaponSlug) ?? false;

    /// <summary>Query: smithy view-model (gold, per-member rune options, weapon shelf). Null when the
    /// squad is unavailable. Forwards to <see cref="SmithySystem.BuildView"/>.</summary>
    public SmithyView? GetSmithyView() => _smithy?.BuildView();

    /// <summary>
    /// Voluntary sleep at the outpost: the ONLY full night's rest (level-ups apply, the squad
    /// rests fully — Fatigued/Wounded cleared, HP/slots/daily preps refreshed), then overnight
    /// growth resolves, the day advances and the game saves. Sleeping at any hour counts as a
    /// full night's rest (cozy simplification of PF2e "Rest and Daily Preparations").
    /// </summary>
    public void Sleep()
    {
        // Sleep always tucks the squad in at the outpost with the gate selection cleared.
        Territory.OnSlept();

        // Banked level-ups apply BEFORE the nightly rest so RestFully refills HP/slots/font to
        // the NEW maxima and re-prepares the refreshed daily loadout (e.g. the Scholar's rank-3
        // Fireballs at L5). See SquadRoster.ApplyBankedLevelUps for the cap/consumption contract.
        var levelUps = Squad?.ApplyBankedLevelUps();

        // Full night's rest for the squad: HP to full, spell slots refilled / re-prepared,
        // Wounded + Fatigued removed, Doomed/Drained tick down (see SquadRoster.RestFully).
        Squad?.RestFully();

        // Carried weight is unchanged by rest, so reconcile the derived Encumbered condition against
        // it (a rest that cleared conditions must not leave an overloaded member wrongly unencumbered).
        Inventory.RecomputeEncumbrance();

        // Tutorial (design/tutorial.md Step 5 — "Flag set: first_rest"): the FIRST night's rest latches
        // first_rest through the story director (idempotent past the first night) so it rides
        // AdvanceDay's save below rather than triggering a second one. FlagSet still runs the
        // quest/arrival re-evaluation.
        _story.OnFirstRest();

        AdvanceDay(levelUps);

        // Announce after the night fully resolved (rest applied, day advanced, save written) so
        // subscribers observe the settled post-sleep state.
        if (levelUps is { Count: > 0 })
            SquadLeveledUp?.Invoke(levelUps);
    }

    /// <summary>
    /// Command: record the outcome of a tactical encounter on the live squad. Post-combat cleanup
    /// stabilizes downed allies (1 HP + Wounded), clears encounter-scoped state (MAP, temp HP,
    /// combat-only conditions), keeps attrition (HP, slots, Wounded/Drained/Doomed/Fatigued), and
    /// awards encounter XP on victory. Saves immediately so attrition survives a crash.
    /// See <see cref="SquadRoster.CompleteEncounter"/> for the exact clear/keep contract.
    /// </summary>
    public void CompleteEncounter(BattleResult result, IReadOnlyList<ICharacter>? defeatedEnemies)
    {
        if (Squad == null)
            return;

        int xpAwarded = Squad.CompleteEncounter(result, defeatedEnemies);
        // Combat-scoped consumable buffs (elixirs) do not survive the fight — clear them alongside the
        // roster's encounter-scoped cleanup (temp HP, MAP, combat conditions).
        Consumables.ClearCombatEffects();
        // Post-combat cleanup strips encounter-scoped conditions (Encumbered is one) — reconcile the
        // derived Encumbered state with the still-carried weight so it persists past the fight.
        Inventory.RecomputeEncumbrance();
        _ledger.RecordXpAwarded(xpAwarded);

        // Framework seam (first_casualty): latch it the FIRST time any member ends an encounter dead or
        // Wounded. Delegated to the story director, whose injected predicate reads the post-cleanup
        // squad state (a downed ally already stabilized to 1 HP + Wounded) AFTER the roster's own
        // cleanup ran. One-shot latch that rides this method's save below.
        _story.OnEncounterCompleted();

        SaveGame();
    }

    /// <summary>
    /// Command: out-of-combat Treat Wounds (RAW Player Core). Validates via
    /// <see cref="TreatWoundsSystem"/> (living healer/target, DC within the healer's Medicine
    /// proficiency, target injured or Wounded, not immune), spends 10 game-minutes, applies the
    /// engine-resolved outcome to the live member, and starts the 1-hour immunity window.
    /// Emits <see cref="TreatWoundsResolved"/> + <see cref="SquadChanged"/>. Not saved here —
    /// persistence stays on the sleep/encounter cadence; immunity rides the save additively.
    /// </summary>
    public bool TreatWounds(string healerId, string targetId, int dc)
        => _treatWounds?.TreatWounds(healerId, targetId, dc) ?? false;

    /// <summary>Query: squad-panel view-model (null when the squad is unavailable).</summary>
    public SquadPanelView? GetSquadPanelView() => _treatWounds?.BuildPanelView();

    // ===================== Territory commands (M3) =====================

    /// <summary>
    /// Command: travel from the outpost gate to a territory with the FULL living roster — every
    /// living member marches (the current gate contract; no party-select step). Spends the constant
    /// 30 game-minute travel cost. The caller (world scene) routes via SceneRouter on success —
    /// commands never change scenes.
    /// </summary>
    public bool TravelToTerritory(string territoryId) => Territory.TravelWithFullParty(territoryId);

    /// <summary>
    /// Command: travel from the outpost gate to a territory with an explicit selection of up to 3
    /// living companions (the Veteran avatar always goes). The capability-limited path — kept for
    /// future flows; the gate itself uses the all-hands overload above.
    /// </summary>
    public bool TravelToTerritory(string territoryId, IReadOnlyList<string> companionIds)
        => Territory.Travel(territoryId, companionIds);

    /// <summary>Command: travel from a territory back to the outpost (same 30-minute cost).</summary>
    public bool TravelToOutpost() => Territory.TravelToOutpost();

    /// <summary>Command: march directly from the current territory into a LINKED one without the
    /// outpost round-trip (the Verdant Fringe ⇄ Elderwood deep-forest seam), keeping the marching
    /// party. Same constant travel cost. Rejects when not in a territory or the destination is
    /// undefined / the territory already occupied. The caller routes via SceneRouter on success.</summary>
    public bool TravelToLinkedTerritory(string territoryId) => Territory.TravelToLinkedTerritory(territoryId);

    /// <summary>
    /// Command: harvest a resource node in the current territory with the active tool. Validates
    /// tool gate + depletion, charges the node's harvest minutes, adds the yield to the inventory,
    /// depletes the node (respawn per its definition on day change). Emits
    /// <see cref="TerritoryNodeChanged"/> + <see cref="ResourceHarvested"/>.
    /// </summary>
    public bool HarvestResourceNode(string nodeId, ToolKind tool) => Territory.Harvest(nodeId, tool);

    /// <summary>
    /// Command: a territory scene announces the resource-node prefabs placed directly in its .tscn
    /// (design/forage.md — save identity is territory id + node name). Called at scene ready,
    /// before the scene queries depletion state; idempotent per territory.
    /// </summary>
    public void RegisterTerritoryPlacements(
        string territoryId, IReadOnlyList<(string NodeId, string ResourceId)> placements)
        => Territory.RegisterScenePlacements(territoryId, placements);

    /// <summary>
    /// Command: run every owed forage daily pass for a territory (deterministic catch-up through
    /// today — see <see cref="ForageSystem.CatchUp"/>). The scene calls it at ready and on day
    /// change while inside, passing its cell adapter; changes emit <see cref="ForageChanged"/>.
    /// </summary>
    public void SyncTerritoryForage(string territoryId, IForageCellProvider cells)
        => _forage.CatchUp(territoryId, CurrentDayOrdinal, cells);

    /// <summary>Query: the live (uncollected) forage spawns in a territory.</summary>
    public IReadOnlyList<ForageSpawn> GetLiveForage(string territoryId) => _forage.GetLive(territoryId);

    /// <summary>Query: the live (uncleared) debris pieces in a territory (design/forage.md).</summary>
    public IReadOnlyList<ForageSpawn> GetLiveDebris(string territoryId) => _forage.GetLiveDebris(territoryId);

    /// <summary>
    /// Command: a roamer touched the player — build the pending territory encounter (weighted table
    /// roll, creatures resolved through DataManager, party = Veteran + gate selection, sit-outs
    /// absent) with its return context. The scene then routes to combat via SceneRouter.GoToCombat,
    /// which pauses the day clock (the existing combat seam).
    /// </summary>
    public bool BeginTerritoryEncounter(string roamerId, Vector2 playerPosition)
    {
        if (!Territory.BeginEncounter(roamerId, playerPosition))
            return false;

        // Refinement 1 — the encounter-START seam: re-grant the active day-long meal's PER-COMBAT
        // components (temp HP) to the live squad before combat reads them. Post-combat cleanup wiped
        // temp HP after the last fight; a well-fed squad gets a fresh cushion every fight, all day.
        // Persistent stat/attack/AC modifiers were applied on eat and are untouched (still active).
        _meals?.RefreshPerCombat();
        return true;
    }

    /// <summary>
    /// Command: close out the pending territory encounter with the combat result. Always runs the
    /// existing <see cref="CompleteEncounter"/> (stabilization, cleanup, XP on victory, save).
    /// Victory: the roamer despawns for the day and the return context is staged for the territory
    /// scene. Defeat (or draw): next-morning wake at the outpost — the 25% resource penalty applies,
    /// the calendar advances WITHOUT the sleep flow's full-rest benefits (no RestFully, no level-up
    /// application — the squad wakes as combat left it: stabilized at 1 HP, Wounded), and the wake
    /// summary is staged for the outpost toast. Returns where the scene should route.
    /// </summary>
    public TerritoryEncounterOutcome? CompleteTerritoryEncounter(BattleResult result)
    {
        bool victory = result == BattleResult.Team1Wins;
        var encounter = Territory.CompleteEncounter(victory);
        if (encounter == null)
            return null;

        // Loot lands BEFORE the post-combat save below, so victory drops (parts + coin) persist
        // with the XP rather than being stranded until the next save.
        if (victory)
            RollVictoryLoot(encounter);

        // Existing post-combat contract: stabilize, clear encounter state, bank XP, save.
        CompleteEncounter(result, encounter.Enemies);
        _ledger.RecordEncounter(victory);

        if (victory)
        {
            // Story beats on a territory victory (first_combat_victory latch, the First Blood
            // combat_victory counter, and the designated-encounter ClearsStoryFlag latch) are owned by
            // the story director — it holds the flag/event ids and the roamer lookup.
            _story.OnCombatVictory(encounter.TerritoryId, encounter.RoamerId);

            _pendingTerritoryReturn = (encounter.TerritoryId, encounter.ReturnPosition);
            return new TerritoryEncounterOutcome { Victory = true, TerritoryId = encounter.TerritoryId };
        }

        // Defeat wake: penalty, wake at the outpost next morning WITHOUT full-rest benefits
        // (no RestFully, no level-up application — the squad wakes as combat left it).
        _pendingDefeatSummary = Territory.ApplyDefeatPenalty();
        Territory.OnSlept();
        AdvanceDay();
        return new TerritoryEncounterOutcome { Victory = false, TerritoryId = encounter.TerritoryId };
    }

    /// <summary>Query: gate party-selection view-model.</summary>
    public PartySelectView GetPartySelectView(string territoryId)
        => Territory.BuildPartySelectView(territoryId);

    /// <summary>One-shot: the position to respawn the player at when re-entering a territory after
    /// a victorious encounter (null = spawn at the entry marker).</summary>
    public Vector2? ConsumeTerritoryReturn(string territoryId)
    {
        if (_pendingTerritoryReturn is not { } ret || ret.TerritoryId != territoryId)
            return null;
        _pendingTerritoryReturn = null;
        return ret.Position;
    }

    /// <summary>One-shot: the defeat wake summary (losses) for the outpost toast, or null.</summary>
    public DefeatSummaryView? ConsumeDefeatSummary()
    {
        var summary = _pendingDefeatSummary;
        _pendingDefeatSummary = null;
        return summary;
    }

    /// <summary>
    /// One-shot: the end-of-day summary staged by <see cref="AdvanceDay"/> for the summary panel
    /// (the ConsumeDefeatSummary precedent). World scenes consume it on DayStarted, or in _Ready
    /// after a scene swap (e.g. the defeat wake lands at the outpost with the summary staged).
    /// </summary>
    public DaySummaryView? ConsumeDaySummary()
    {
        var summary = _pendingDaySummary;
        _pendingDaySummary = null;
        return summary;
    }

    /// <summary>
    /// Roll the defeated encounter's loot and bank it: monster parts flow through
    /// <see cref="AddItem"/> (so the day ledger + end-of-day summary count them automatically), coin
    /// through <see cref="EarnGold"/>. Unknown items are skipped defensively. Deterministic for the
    /// Phase-1 forest tables (min == max), so the spike asserts exact yields.
    /// </summary>
    private void RollVictoryLoot(TerritoryEncounter encounter)
    {
        if (!EncounterTables.TryGet(encounter.EncounterId, out var encDef))
            return;

        var drop = LootRoller.RollEncounter(encDef, _lootRng);
        foreach (var (itemId, qty) in drop.Items)
        {
            if (qty > 0 && Items.IsDefined(itemId))
                AddItem(itemId, qty);
        }
        if (drop.Gold > 0)
            EarnGold(drop.Gold);
    }

    // ===================== Phase-5 provisions: crafting + meals =====================

    /// <summary>
    /// Command: craft <paramref name="count"/> batches of a recipe (raw→refined or a kitchen meal).
    /// Validates via <see cref="CraftingSystem"/> — the required station category must be unlocked
    /// (null = baseline), the inputs present, and the output must fit the Bulk carry cap. A rejected
    /// craft consumes nothing. On success consumes inputs, adds the output, spends the craft-minutes on
    /// the clock, and emits <see cref="RecipeCrafted"/>. Not saved here (persistence stays on the
    /// sleep/encounter cadence; crafted items ride the next save additively).
    /// </summary>
    public bool Craft(string recipeId, int count = 1) => Crafting.Craft(recipeId, count);

    /// <summary>Query: the crafting-bench view-model (every recipe with have/need + unlock + fit state).</summary>
    public CraftingView GetCraftingView() => Crafting.BuildView();

    /// <summary>
    /// Command: eat a meal — consume its Food item and apply its day-long buff to the roster (single
    /// active; eating replaces any prior meal). Validated by <see cref="MealSystem"/>; rejects cleanly
    /// (false, nothing consumed) when the squad is unavailable, the meal is unknown, or the item is
    /// absent. Emits <see cref="MealChanged"/>. Saves so the active meal survives a crash.
    /// </summary>
    public bool EatMeal(string mealId)
    {
        if (!_meals.EatMeal(mealId, Inventory))
            return false;
        _story.OnMealEaten(); // Share the Harvest: "Eat the meal he cooks"
        SaveGame();
        return true;
    }

    /// <summary>Query: the currently active meal buff id (null = none / baseline).</summary>
    public string? ActiveMealId => _meals.ActiveMealId;

    /// <summary>
    /// Command: use a per-fight consumable OUT OF COMBAT (no action cost) — consume one from the party Bulk
    /// inventory and apply its effect to a squad member. <paramref name="memberId"/> is the user;
    /// <paramref name="targetId"/> the recipient (defaults to the user — self-drink). Rejects cleanly
    /// (false, nothing consumed) when the squad is unavailable, either member is unknown, the id is not a
    /// consumable, or the party doesn't hold it. In-combat use goes through the combat action path
    /// (<see cref="ConsumableSystem.UseInCombat"/>), not this command.
    /// </summary>
    public bool UseItem(string memberId, string itemId, string? targetId = null)
    {
        if (Squad == null || Squad.FindMember(memberId) == null)
            return false;
        var recipient = Squad.FindMember(targetId ?? memberId);
        if (recipient == null)
            return false;
        return Consumables.UseOutOfCombat(itemId, recipient, Inventory);
    }

    // ===================== Quest log (Phase 6) =====================

    /// <summary>Command: start a quest by id (data-driven definitions in Quests registry).</summary>
    public void StartQuest(string questId) => _questLog.StartQuest(questId);

    /// <summary>Command: update quest objective progress.</summary>
    public void UpdateQuestProgress(string questId, int objectiveIndex, int amount)
        => _questLog.UpdateProgress(questId, objectiveIndex, amount);

    /// <summary>Command: complete a quest.</summary>
    public void CompleteQuest(string questId) => _questLog.CompleteQuest(questId);

    /// <summary>Query: whether a quest is currently active.</summary>
    public bool IsQuestActive(string questId) => _questLog.IsActive(questId);

    /// <summary>Query: whether a quest has been completed.</summary>
    public bool IsQuestCompleted(string questId) => _questLog.IsCompleted(questId);

    /// <summary>Query: the quest-panel view-model.</summary>
    public QuestView GetQuestView() => _questLog.GetView();

    /// <summary>
    /// Command / choke point: record one quest-relevant event (combat_victory, item_sold,
    /// crop_harvested, meal_eaten, smithy_craft, treat_wounds, …). Forwards to the story director, which
    /// advances matching event-count and one-shot objectives on the active data-driven quests and
    /// re-evaluates conditions. Exposed so a later dialogue/scene layer (e.g. TerritoryScene's
    /// elderwood_entered) can raise events too.
    /// </summary>
    public void RecordQuestEvent(string eventKey, int amount = 1) => _story.RecordQuestEvent(eventKey, amount);

    /// <summary>
    /// Command: deliver items from a named set toward an active quest's Deliver objective (the
    /// Give-Fenwick-3-crops interaction). Forwards to the story director, which validates the active
    /// Deliver objective + the party's holdings, consumes the items greedily across the set, and advances
    /// the objective. Rejects cleanly (false, nothing consumed) otherwise.
    /// </summary>
    public bool DeliverQuestItems(string setKey) => _story.DeliverQuestItems(setKey);

    // ===================== Calendar (Phase 6+ polish) =====================

    /// <summary>
    /// Query: the current season's 28-day calendar view-model for the calendar panel — today's day
    /// flagged, plus per-day marker lines for (1) befriendable characters whose birthday falls in
    /// THIS season, resolved from <see cref="Friendships"/> against the <see cref="Characters"/>
    /// registry for a display name, and (2) buildings currently under construction whose completion
    /// day (<c>Clock.Day + GetConstructionDaysRemaining</c>) lands within this season — a completion
    /// spilling past day 28 is next season's calendar and is skipped here. Engine-free view-model.
    /// </summary>
    public CalendarView GetCalendarView()
    {
        var marksByDay = new Dictionary<int, List<string>>();
        void AddMark(int day, string text)
        {
            if (day < 1 || day > DayClock.DaysPerSeason)
                return;
            if (!marksByDay.TryGetValue(day, out var list))
                marksByDay[day] = list = new List<string>();
            list.Add(text);
        }

        foreach (var profile in Friendships.All)
        {
            if (profile.BirthdaySeason != Clock.Season)
                continue;
            string name = CharacterRegistry.TryGet(profile.CharacterId, out var cp) ? cp.DefaultName : profile.CharacterId;
            AddMark(profile.BirthdayDay, $"{name}'s birthday");
        }

        foreach (var def in Buildings.All)
        {
            if (!Building.IsUnderConstruction(def.Id))
                continue;
            int completionDay = Clock.Day + Building.GetConstructionDaysRemaining(def.Id);
            if (completionDay <= DayClock.DaysPerSeason)
                AddMark(completionDay, $"{def.DisplayName} completes");
        }

        var days = new List<CalendarDayView>(DayClock.DaysPerSeason);
        for (int d = 1; d <= DayClock.DaysPerSeason; d++)
        {
            IReadOnlyList<string> marks = marksByDay.TryGetValue(d, out var list) ? list : Array.Empty<string>();
            days.Add(new CalendarDayView(d, d == Clock.Day, marks));
        }

        return new CalendarView(Clock.Season, Clock.Year, Clock.Day, days);
    }

    // ===================== New game / continue (title screen flow) =====================

    /// <summary>
    /// Start a new game from a clean slate: wipe any existing save (and its backup), RESET every
    /// stateful system to its new-game baseline, set the player name, and re-seed the starter
    /// inventory — leaving the game ready for the intro. Called by the title-screen New Game flow
    /// after name entry.
    ///
    /// The reset is essential, not cosmetic: <see cref="_Ready"/> auto-loads slot0.json at boot, so a
    /// same-session New Game after play would otherwise inherit the loaded clock date, gold, story
    /// flags, quest log, buildings, friendship, villager arrivals, squad HP/XP/levels, warehouse, and
    /// seen-dialogues — skipping the intro (intro_complete still set) and persisting the contamination
    /// on the next save. The reset list and order below MIRROR <see cref="SaveState.Restore"/> (the
    /// authoritative inventory of persisted systems): where a load overwrites each system from a DTO,
    /// a new game clears it to empty via that same system's null/baseline path.
    /// </summary>
    public void StartNewGame(string name)
    {
        PlayerName = name;

        // Clean-slate delete: BOTH the primary save and its one-generation backup (see
        // DeleteSaveFiles) — so no abandoned game can resurrect through LoadGame's backup fallback.
        DeleteSaveFiles();

        // Fresh deterministic world seed (forage daily passes anchor on it) — set before the forage /
        // territory resets below, which read it.
        _worldSeed = Random.Shared.Next(1, int.MaxValue);
        _forage.SetWorldSeed(_worldSeed);
        Territory.SetWorldSeed(_worldSeed);

        // Reset each stateful system to baseline, in SaveState.Restore order. Every call here is the
        // same clear-to-empty path a restore takes when its additive DTO field is null.
        Clock.RestoreState(DayClock.DayStartMinute, 1, Season.Spring, 1); // day 1, 6:00, Spring, Year 1
        Inventory.LoadState(null, null);            // clears every member's carry + the warehouse
        _wallet.LoadFrom(0);                        // gold back to 0
        Farm.LoadPlots(Array.Empty<Plot>());        // no planted plots
        Squad?.Reset(SquadStartLevel, PlayerName);  // fresh presets at start level, in place, renamed
        _treatWounds?.RestoreImmunities(null);      // no Treat Wounds immunity windows
        Territory.RestoreState(null);               // no gate selection / depleted / defeated sets
        Building.Restore(null);                     // every building back to not-commissioned
        _storyFlags.Restore(null);                  // clears intro_* and every story beat
        _villagers.Restore(null);                   // nobody arrived
        _meals.Restore(null);                       // no active meal buff
        _friendship.Restore(null);                  // zero friendship (re-anchors counters to day 1)
        _dialogue.Restore(null);                    // nothing seen — once-only sequences replay
        _questLog.Restore(null);                    // no quests started or completed
        _forage.Restore(null);                      // no forage spawned yet

        // Re-derive the cross-system state LoadGame settles after a restore: capability aggregator,
        // villager catch-up (no-op fresh), encumbrance against the rebuilt members, the fatigue latch,
        // and the transient day ledger / staged summary.
        _villagers.EvaluateArrivals();
        _effects.Recompute();
        Inventory.RecomputeEncumbrance();
        _squadFatigueLatched = false;
        _ledger.Reset();
        _pendingDaySummary = null;

        // Seed the starter inventory ONTO the now-empty pool (must follow the Inventory clear above),
        // then catch up quest auto-starts against the fresh flag/building state (a no-op here — kept
        // for parity with LoadGame so the two entry paths converge on identical quest state).
        SeedStarterInventory();
        _story.EvaluateQuests();
    }

    /// <summary>
    /// Continue an existing game: load the save file. Called by the title screen's Continue button.
    /// </summary>
    public void ContinueGame()
    {
        if (SaveExists())
            LoadGame();
        else
            SeedStarterInventory();
    }

    // ===================== Save / load =====================

    public bool SaveExists() => Godot.FileAccess.FileExists(SavePath);

    /// <summary>
    /// Remove the save file AND its one-generation backup (plus any stray temp) — the clean-slate
    /// delete for New Game. Deleting the primary alone would strand <see cref="BackupSavePath"/>
    /// holding the PREVIOUS game: <see cref="SaveGame"/> only rotates a backup when it REPLACES an
    /// existing primary, and the first save after a New Game does a plain move onto the freshly
    /// deleted primary (no rotation), so a later parse failure would resurrect the abandoned game via
    /// <see cref="LoadGame"/>'s backup fallback. Wiping both leaves no path back to the old save.
    /// </summary>
    private static void DeleteSaveFiles()
    {
        foreach (var path in new[] { SavePath, BackupSavePath, SavePath + ".tmp" })
            if (Godot.FileAccess.FileExists(path))
                DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(path));
    }

    /// <summary>
    /// Serialize all persisted state to <c>user://save/slot0.json</c>. Atomic: the JSON is written to
    /// a sibling temp file first, then swapped into place with a single System.IO.File.Replace (which
    /// also rotates whatever was previously at <see cref="SavePath"/> into <see cref="BackupSavePath"/>
    /// — one backup generation) so a crash mid-write can never truncate the only copy; the live save
    /// is either the old complete file or the new complete file, never a partial one. System.IO needs
    /// OS-absolute paths (it doesn't understand "user://"), hence the ProjectSettings.GlobalizePath
    /// calls — Godot's own FileAccess/DirAccess (used for the temp-file write and dir creation above)
    /// resolve "user://" directly and don't need globalizing.
    /// </summary>
    public void SaveGame()
    {
        var data = SaveState.Capture(
            Clock, Inventory, Farm, Squad, _treatWounds, Territory, _wallet, Building, _storyFlags, _villagers, _meals,
            playerName: PlayerName, friendship: _friendship, dialogue: _dialogue,
            questLog: _questLog, forage: _forage, worldSeed: _worldSeed);
        string json = SaveSerializer.Serialize(data);

        DirAccess.MakeDirRecursiveAbsolute(SaveDir);

        string tempPath = SavePath + ".tmp";
        using (var file = Godot.FileAccess.Open(tempPath, Godot.FileAccess.ModeFlags.Write))
        {
            if (file == null)
            {
                GD.PushError($"[GameState] Could not open temp save file: {Godot.FileAccess.GetOpenError()}");
                return;
            }
            file.StoreString(json);
            // Explicit scope (not a using-declaration): the handle MUST close here, before the
            // System.IO rename below — Windows can't move/replace a file that is still open.
        }

        string tempGlobal = ProjectSettings.GlobalizePath(tempPath);
        string mainGlobal = ProjectSettings.GlobalizePath(SavePath);
        string backupGlobal = ProjectSettings.GlobalizePath(BackupSavePath);
        try
        {
            if (File.Exists(mainGlobal))
                File.Replace(tempGlobal, mainGlobal, backupGlobal, ignoreMetadataErrors: true);
            else
                File.Move(tempGlobal, mainGlobal); // first-ever save: nothing to back up yet
        }
        catch (IOException ex)
        {
            GD.PushError($"[GameState] Could not finalize save file: {ex.Message}");
        }
    }

    /// <summary>
    /// Read and parse one save file (primary or backup). Null on a missing file, an I/O error, or a
    /// parse failure (<see cref="SaveSerializer.Deserialize"/> already logs the parse failure itself)
    /// — callers decide what to fall back to.
    /// </summary>
    private SaveData? TryReadSaveFile(string path)
    {
        if (!Godot.FileAccess.FileExists(path))
            return null;

        using var file = Godot.FileAccess.Open(path, Godot.FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PushError($"[GameState] Could not read save file '{path}': {Godot.FileAccess.GetOpenError()}");
            return null;
        }

        return SaveSerializer.Deserialize(file.GetAsText());
    }

    /// <summary>
    /// Load persisted state from disk. No-op if no save exists. Resilient: a primary save that fails
    /// to parse (truncated/corrupt) falls back to <see cref="BackupSavePath"/>; a save whose
    /// <see cref="SaveData.Version"/> is newer than this build's <see cref="SaveData.CurrentVersion"/>
    /// is refused outright (never partially loaded); and if nothing usable is found, this degrades to
    /// the same fresh-start state as a first boot (systems already sit at their freshly constructed
    /// defaults from _Ready, so re-seeding the starter inventory is the only catch-up needed) rather
    /// than leaving the game unbootable.
    /// </summary>
    public void LoadGame()
    {
        if (!SaveExists())
            return;

        var data = TryReadSaveFile(SavePath);
        if (data == null)
        {
            GD.PushWarning("[GameState] Primary save could not be loaded; falling back to slot0.json.bak.");
            data = TryReadSaveFile(BackupSavePath);
            if (data != null)
                GD.PushWarning("[GameState] Restored from the backup save (slot0.json.bak).");
        }

        if (data != null && data.Version > SaveData.CurrentVersion)
        {
            GD.PushWarning($"[GameState] Save file is version {data.Version}, newer than this build " +
                $"supports ({SaveData.CurrentVersion}) — refusing to load it to avoid corrupting it on the next save.");
            data = null;
        }

        if (data == null)
        {
            GD.PushError("[GameState] No valid save could be loaded (primary and backup both failed); starting fresh.");
            SeedStarterInventory();
            return;
        }

        PlayerName = data.PlayerName;

        // World seed first: forage restore + future deterministic passes read it. Pre-v12 saves
        // carry 0 — the freshly generated seed stands and persists on the next SaveGame.
        if (data.WorldSeed != 0)
            _worldSeed = data.WorldSeed;
        _forage.SetWorldSeed(_worldSeed);
        Territory.SetWorldSeed(_worldSeed);

        SaveState.Restore(
            data, Clock, Inventory, Farm, Squad, _treatWounds, Territory, _wallet, Building, _storyFlags, _villagers, _meals,
            _friendship, _dialogue, _questLog, _forage);

        // Catch up villager arrivals against the restored state: a pre-v5 save (no arrival section)
        // whose buildings/flags/date already satisfy a trigger arrives now; a v5 save is idempotent
        // (already-arrived ids are skipped). No-op in shipped play (empty catalog).
        _villagers.EvaluateArrivals();

        // Building state was just restored — recompute the derived effect aggregator so capability
        // queries (smithy tier, infirmary heal, farm caps, unlock sets) reflect the loaded outpost.
        _effects.Recompute();

        // Squad members are rebuilt fresh by RestoreMembers, discarding any condition applied during
        // the inventory restore — recompute encumbrance now against the final live instances so the
        // Encumbered condition is reapplied to the members combat will actually read.
        Inventory.RecomputeEncumbrance();

        // Re-arm the fatigue latch for the loaded day. A restored late-night clock re-runs the
        // midnight check on the next minute: members already Fatigued from the save are skipped
        // (ApplyFatigue is idempotent, and no notice fires when nothing was newly applied).
        _squadFatigueLatched = false;

        // The day ledger is transient by design (never saved): a load starts a clean tally, and
        // any summary staged by pre-load play is stale now.
        _ledger.Reset();
        _pendingDaySummary = null;

        // A restored save may already be past the trophy-count / eight-buildings thresholds (their
        // normal triggers — ItemAdded, CommissionBuilding — never fire during a restore), so
        // re-check both explicitly here (the story director owns the rules). Both are idempotent.
        _story.CheckEightTrophiesMilestone();
        _story.CheckEightBuildingsMilestone();

        // Re-apply the day-1 tutorial time freeze if the save was taken mid-day-1 (intro_complete set
        // but the scripted day close's first_rest not yet reached), and re-anchor Josen's arrival window.
        _story.OnLoaded(CurrentDayOrdinal);

        // Data-driven arc quests: catch up start/complete conditions against the restored state (a save
        // whose buildings/flags/prior-quest completions already satisfy the next quest starts it now;
        // flag-kind objectives re-tick). Idempotent — QuestLog skips already-active/completed quests.
        _story.EvaluateQuests();

        GameLoaded?.Invoke();
    }

    // ===================== Internals =====================

    /// <summary>
    /// Refinement 1 wiring: subscribe warehouse-reachability to SceneRouter's mode and apply the
    /// current mode immediately (boot/load defaults to the Outpost = accessible). Deferred from
    /// _Ready because SceneRouter autoloads after GameState. No-op if the router isn't present
    /// (headless spikes that drive Inventory.WarehouseAccessible directly).
    /// </summary>
    private void WireWarehouseAccess()
    {
        var router = SceneRouter.Instance;
        if (router == null)
            return;
        ApplyWarehouseAccess(router.CurrentMode);
        router.ModeChanged += ApplyWarehouseAccess;
    }

    /// <summary>The warehouse is reachable only in the Outpost mode; the field (Territory/Combat) sees
    /// member carry only.</summary>
    private void ApplyWarehouseAccess(SceneRouter.Mode mode)
        => Inventory.WarehouseAccessible = mode == SceneRouter.Mode.Outpost;

    private void OnClockMinuteChanged()
    {
        // PF2e's going-without-sleep rule, house-tuned to midnight (see FatigueMinuteOfDay). The
        // clock only moves one minute at a time (ticking and SpendTime alike), so the crossing can
        // never be skipped; the latch keeps the check once-per-day and ApplyFatigue is idempotent.
        if (!_squadFatigueLatched && Clock.MinuteOfDay >= FatigueMinuteOfDay)
        {
            _squadFatigueLatched = true;
            if (Squad?.ApplyFatigue() == true)
                SquadStatusNotice?.Invoke("The squad is exhausted — Fatigued");
        }

        MinuteChanged?.Invoke();
    }

    private void OnClockDayStarted()
    {
        _squadFatigueLatched = false;
        // Story day-start beats (Josen's post-Infirmary random arrival). Runs before EvaluateArrivals
        // so a flag it latches (josen_arrived) is reflected in the same day-start pass.
        _story?.OnDayStarted(CurrentDayOrdinal);
        // A new day is a villager-arrival trigger source (DateReached). Evaluate before announcing
        // the day so DayStarted subscribers observe any arrival already reflected.
        _villagers?.EvaluateArrivals();
        // Friendship daily/weekly counters roll with the calendar (talked-today clears every day,
        // gift cadence every 7 days from day 1).
        _friendship?.OnDayStarted();
        DayStarted?.Invoke();
    }

    private void OnClockDayEnded()
    {
        // 30:00 (6:00 AM) reached without sleeping — the all-nighter dawn rollover, NOT a rest:
        // no RestFully, no banked level-ups, no daily-prep refresh, and nobody is relocated (the
        // player greets the dawn wherever the night found them; gate/party state is untouched).
        // Fatigued backstop: the midnight latch normally applied it already, but any path that
        // missed the threshold (e.g. a restored save) is caught here, before the day saves.
        Squad?.ApplyFatigue();
        _ledger.MarkAllNighter();
        AdvanceDay();
        SquadStatusNotice?.Invoke($"Dawn breaks — the squad went all night without rest. {Clock.DateString()}");
    }

    /// <summary>
    /// Shared end-of-day tail for every path that advances the calendar (voluntary sleep, the
    /// 30:00 all-nighter rollover, the defeat wake). Order matters: overnight growth resolves for
    /// the day just played BEFORE the calendar advances, so watered crops "grow overnight"; the
    /// day summary is staged and the ledger reset BEFORE <see cref="DayClock.StartNextDay"/>, so
    /// the DayStarted subscribers (world scenes) can consume the summary and the new day's tally
    /// starts clean; then the state persists. Rest benefits are deliberately NOT here — only
    /// <see cref="Sleep"/> grants them (which passes its applied level-ups in).
    /// </summary>
    private void AdvanceDay(IReadOnlyList<SquadLevelUpView>? levelUps = null)
    {
        string dateEnded = Clock.DateString();
        Farm.OnDayEnded();
        Building.TickDay();

        // Phase-5: the active meal buff is day-long — it expires at every day rollover (voluntary
        // sleep, the all-nighter dawn, and the defeat wake all funnel through here). Clears the buff
        // off the roster's live instances and forgets the active meal.
        _meals?.ClearActive();

        _pendingDaySummary = _ledger.BuildSummary(
            dateEnded,
            levelUps,
            _ledger.AllNighter ? "The squad pushed through the night — Fatigued" : null);
        _ledger.Reset();

        Clock.StartNextDay();
        SaveGame();
    }

    private void SeedStarterInventory()
    {
        Inventory.AddItem(Items.TurnipSeed.Id, 5);
        Inventory.AddItem(Items.PotatoSeed.Id, 3);
        Inventory.AddItem(Items.Wood.Id, 10);
        Inventory.AddItem(Items.Stone.Id, 10);
    }
}
