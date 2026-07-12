using System;
using System.Collections.Generic;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Territory;
using Godot;
using PF2e.Core;
using PF2e.Data;

namespace Bulwark.Autoload;

/// <summary>
/// The single authoritative mutable state root. Thin Node adapter per CLAUDE.md: it hosts the plain
/// C# game systems (<see cref="DayClock"/>, <see cref="Inventory"/>, <see cref="FarmSystem"/>),
/// ticks the clock each frame, wires their events up as a single subscription hub for UI/world
/// scenes, and owns the file-path side of save/load. All mutation goes through intent-named command
/// methods that validate and let the systems raise change events — UI never mutates directly.
/// </summary>
public partial class GameState : Node
{
    public static GameState Instance { get; private set; } = null!;

    private const string SaveDir = "user://save";
    private const string SavePath = "user://save/slot0.json";

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

    /// <summary>Territory loop (M3): travel/party selection, resource nodes, roaming encounters.</summary>
    public TerritorySystem Territory { get; private set; } = null!;

    /// <summary>
    /// The live squad — four preset PCs built ONCE per save and reused across encounters so HP,
    /// conditions and spell-slot usage persist between fights (attrition). Null only when PF2e
    /// content failed to load (headless tooling without the data drive).
    /// </summary>
    public SquadRoster? Squad { get; private set; }

    // Out-of-combat Treat Wounds (validation, immunity clock, view-models). Private: UI goes
    // through the TreatWounds command and GetSquadPanelView query below.
    private TreatWoundsSystem? _treatWounds;

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

    /// <summary>Raised after a save file is loaded (initial autoload or explicit LoadGame).</summary>
    public event Action? GameLoaded;

    /// <summary>Raised after any squad-state change (encounter completion, rest, restore).</summary>
    public event Action? SquadChanged;

    /// <summary>Raised after a Treat Wounds command resolves, with the outcome view for the UI.</summary>
    public event Action<TreatWoundsResultView>? TreatWoundsResolved;

    /// <summary>Raised after a resource node's depleted state changes (harvest or respawn).</summary>
    public event Action<string>? TerritoryNodeChanged;

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

    public override void _Ready()
    {
        Instance = this;

        Clock = new DayClock { RealSecondsPerGameMinute = RealSecondsPerGameMinute };
        Inventory = new Inventory();
        Farm = new FarmSystem(Inventory, () => Clock.Season);

        // The squad needs the PF2e packs (equipment/conditions/spells). DataManager is the first
        // autoload, so content is already loaded — the guard only trips when the data drive is
        // missing, in which case the cozy layer still runs without a squad.
        var dataManager = GetNodeOrNull<DataManager>("/root/DataManager");
        if (dataManager != null && dataManager.IsLoaded)
        {
            Squad = SquadRoster.BuildNew(SquadStartLevel);
            Squad.Changed += () => SquadChanged?.Invoke();

            _treatWounds = new TreatWoundsSystem(Squad, Clock);
            _treatWounds.Resolved += view =>
            {
                _ledger.RecordTreatWounds();
                TreatWoundsResolved?.Invoke(view);
            };
        }
        else
        {
            GD.PushWarning("[GameState] PF2e content not loaded — squad unavailable this session.");
        }

        // Territory loop runs even without a squad (harvest still works); encounters need both the
        // squad and the creature resolver, so BeginTerritoryEncounter degrades to a clean refusal.
        Territory = new TerritorySystem(
            Inventory, Clock, Squad,
            Squad != null ? @ref => dataManager!.ResolveCreature(@ref) : null);
        Territory.NodeChanged += id => TerritoryNodeChanged?.Invoke(id);
        Territory.ResourceHarvested += view => ResourceHarvested?.Invoke(view);

        // Re-expose system events through the hub (minutes also feed the fatigue latch; a new
        // day resets it).
        Clock.MinuteChanged += OnClockMinuteChanged;
        Clock.HourChanged += () => HourChanged?.Invoke();
        Clock.DayStarted += OnClockDayStarted;
        Clock.DayEnded += OnClockDayEnded;
        Farm.PlotChanged += tile => PlotChanged?.Invoke(tile);
        Inventory.InventoryChanged += id => InventoryChanged?.Invoke(id);

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
            _ledger.RecordCropHarvested();
        return harvested;
    }

    public void AddItem(string itemId, int qty) => Inventory.AddItem(itemId, qty);
    public bool RemoveItem(string itemId, int qty) => Inventory.RemoveItem(itemId, qty);

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
        _ledger.RecordXpAwarded(xpAwarded);
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

    /// <summary>
    /// Command: harvest a resource node in the current territory with the active tool. Validates
    /// tool gate + depletion, charges the node's harvest minutes, adds the yield to the inventory,
    /// depletes the node (respawn per its definition on day change). Emits
    /// <see cref="TerritoryNodeChanged"/> + <see cref="ResourceHarvested"/>.
    /// </summary>
    public bool HarvestResourceNode(string nodeId, ToolKind tool) => Territory.Harvest(nodeId, tool);

    /// <summary>
    /// Command: a roamer touched the player — build the pending territory encounter (weighted table
    /// roll, creatures resolved through DataManager, party = Veteran + gate selection, sit-outs
    /// absent) with its return context. The scene then routes to combat via SceneRouter.GoToCombat,
    /// which pauses the day clock (the existing combat seam).
    /// </summary>
    public bool BeginTerritoryEncounter(string roamerId, Vector2 playerPosition)
        => Territory.BeginEncounter(roamerId, playerPosition);

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

        // Existing post-combat contract: stabilize, clear encounter state, bank XP, save.
        CompleteEncounter(result, encounter.Enemies);
        _ledger.RecordEncounter(victory);

        if (victory)
        {
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

    // ===================== Save / load =====================

    public bool SaveExists() => Godot.FileAccess.FileExists(SavePath);

    /// <summary>Serialize all persisted state to <c>user://save/slot0.json</c>.</summary>
    public void SaveGame()
    {
        var data = SaveState.Capture(Clock, Inventory, Farm, Squad, _treatWounds, Territory);
        string json = SaveSerializer.Serialize(data);

        DirAccess.MakeDirRecursiveAbsolute(SaveDir);
        using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
        if (file == null)
        {
            GD.PushError($"[GameState] Could not open save file: {Godot.FileAccess.GetOpenError()}");
            return;
        }
        file.StoreString(json);
    }

    /// <summary>Load persisted state from disk. No-op if no save exists.</summary>
    public void LoadGame()
    {
        if (!SaveExists())
            return;

        using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PushError($"[GameState] Could not read save file: {Godot.FileAccess.GetOpenError()}");
            return;
        }

        var data = SaveSerializer.Deserialize(file.GetAsText());
        if (data == null)
        {
            GD.PushError("[GameState] Save file could not be parsed.");
            return;
        }

        SaveState.Restore(data, Clock, Inventory, Farm, Squad, _treatWounds, Territory);

        // Re-arm the fatigue latch for the loaded day. A restored late-night clock re-runs the
        // midnight check on the next minute: members already Fatigued from the save are skipped
        // (ApplyFatigue is idempotent, and no notice fires when nothing was newly applied).
        _squadFatigueLatched = false;

        // The day ledger is transient by design (never saved): a load starts a clean tally, and
        // any summary staged by pre-load play is stale now.
        _ledger.Reset();
        _pendingDaySummary = null;

        GameLoaded?.Invoke();
    }

    // ===================== Internals =====================

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
