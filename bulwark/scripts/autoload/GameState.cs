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
    /// their persisted level on load.</summary>
    private const int SquadStartLevel = 2;

    /// <summary>Real seconds per in-game minute (fed to <see cref="DayClock"/>). ~15 real min/day at 0.75.</summary>
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

    /// <summary>Set when the player collapsed at 2 AM instead of sleeping voluntarily (see M3 TODO in DoSleep).</summary>
    public bool CollapsedLastNight { get; private set; }

    // One-shot hand-offs across the combat → world scene swaps (consumed by the arriving scene).
    private DefeatSummaryView? _pendingDefeatSummary;
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
            _treatWounds.Resolved += view => TreatWoundsResolved?.Invoke(view);
        }
        else
        {
            GD.PushWarning("[GameState] PF2e content not loaded — squad unavailable this session.");
        }

        // Territory loop runs even without a squad (harvest still works); encounters need both the
        // squad and the creature resolver, so BeginTerritoryEncounter degrades to a clean refusal.
        Territory = new TerritorySystem(
            Inventory, Clock, Squad,
            Squad != null ? @ref => ResolveCreature(dataManager!, @ref) : null);
        Territory.NodeChanged += id => TerritoryNodeChanged?.Invoke(id);
        Territory.ResourceHarvested += view => ResourceHarvested?.Invoke(view);

        // Re-expose system events through the hub.
        Clock.MinuteChanged += () => MinuteChanged?.Invoke();
        Clock.HourChanged += () => HourChanged?.Invoke();
        Clock.DayStarted += () => DayStarted?.Invoke();
        Clock.DayEnded += OnClockDayEnded;
        Farm.PlotChanged += tile => PlotChanged?.Invoke(tile);
        Inventory.InventoryChanged += id => InventoryChanged?.Invoke(id);

        if (SaveExists())
            LoadGame();
        else
            SeedStarterInventory();
    }

    public override void _Process(double delta)
    {
        Clock.Tick(delta); // no-op while paused (SceneRouter pauses during combat)
    }

    // ===================== Commands (validate → delegate → systems raise events) =====================

    public bool TillPlot(Vector2I tile) => Farm.TillPlot(tile);
    public bool PlantCrop(Vector2I tile, string cropId) => Farm.PlantCrop(tile, cropId);
    public bool WaterPlot(Vector2I tile) => Farm.WaterPlot(tile);
    public bool HarvestPlot(Vector2I tile) => Farm.HarvestPlot(tile);

    public void AddItem(string itemId, int qty) => Inventory.AddItem(itemId, qty);
    public bool RemoveItem(string itemId, int qty) => Inventory.RemoveItem(itemId, qty);

    /// <summary>Voluntary sleep at the outpost: resolve overnight growth, advance the day, save.</summary>
    public void Sleep() => DoSleep(collapsed: false);

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

        Squad.CompleteEncounter(result, defeatedEnemies);
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
    /// Command: travel from the outpost gate to a territory with up to 3 living companions (the
    /// Veteran avatar always goes). Spends the constant 30 game-minute travel cost. The caller
    /// (world scene) routes via SceneRouter on success — commands never change scenes.
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

        if (victory)
        {
            _pendingTerritoryReturn = (encounter.TerritoryId, encounter.ReturnPosition);
            return new TerritoryEncounterOutcome { Victory = true, TerritoryId = encounter.TerritoryId };
        }

        // Defeat wake: penalty, then advance to next morning without full-rest benefits.
        _pendingDefeatSummary = Territory.ApplyDefeatPenalty();
        Territory.OnSlept();
        CollapsedLastNight = false;
        Farm.OnDayEnded();
        Clock.StartNextDay();
        SaveGame();
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

    // ===================== Save / load =====================

    public bool SaveExists() => Godot.FileAccess.FileExists(SavePath);

    /// <summary>Serialize all persisted state to <c>user://save/slot0.json</c>.</summary>
    public void SaveGame()
    {
        var data = SaveState.Capture(
            Clock, Inventory, Farm, CollapsedLastNight, Squad, _treatWounds, Territory);
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

        CollapsedLastNight = SaveState.Restore(
            data, Clock, Inventory, Farm, Squad, _treatWounds, Territory);
        GameLoaded?.Invoke();
    }

    // ===================== Internals =====================

    private void OnClockDayEnded()
    {
        // Player was still out when the day ended at 2 AM — force a collapse-sleep.
        DoSleep(collapsed: true);
    }

    private void DoSleep(bool collapsed)
    {
        CollapsedLastNight = collapsed;

        // Wherever the night caught the player, they wake at the outpost with the gate
        // selection cleared (a 2 AM collapse can happen mid-territory).
        Territory.OnSlept();

        // Banked level-ups apply BEFORE the nightly rest so RestFully refills HP/slots/font to
        // the NEW maxima and re-prepares the refreshed daily loadout (e.g. the Scholar's rank-3
        // Fireballs at L5). See SquadRoster.ApplyBankedLevelUps for the cap/consumption contract.
        var levelUps = Squad?.ApplyBankedLevelUps();

        // Full night's rest for the squad: HP to full, spell slots refilled / re-prepared,
        // Wounded + Fatigued removed, Doomed/Drained tick down (see SquadRoster.RestFully).
        Squad?.RestFully();

        // Order matters: overnight growth resolves for the day just played BEFORE the calendar
        // advances, so watered crops "grow overnight". Then start the new day, then persist it.
        Farm.OnDayEnded();
        Clock.StartNextDay();
        SaveGame();

        // Announce after the night fully resolved (rest applied, day advanced, save written) so
        // subscribers observe the settled post-sleep state.
        if (levelUps is { Count: > 0 })
            SquadLeveledUp?.Invoke(levelUps);

        // TODO (M3): when the squad exists outside combat, a collapse should apply the engine
        // Fatigued condition to each squad member for tomorrow's fights. CollapsedLastNight is the
        // flag that will drive it; nothing consumes it yet.
    }

    /// <summary>Resolve a data-driven creature ref the way CombatTestScene does: display-name
    /// lookup first, direct pack-file load as the fallback. Null when unavailable.</summary>
    private static EnemyDefinition? ResolveCreature(DataManager data, CreatureRef @ref)
    {
        try
        {
            return data.FindCreature(@ref.DisplayName) ?? data.LoadCreatureFile(@ref.Pack, @ref.Slug);
        }
        catch (Exception e)
        {
            GD.PushError($"[GameState] Could not resolve creature '{@ref.DisplayName}': {e.Message}");
            return null;
        }
    }

    private void SeedStarterInventory()
    {
        Inventory.AddItem(Items.TurnipSeed.Id, 5);
        Inventory.AddItem(Items.PotatoSeed.Id, 3);
        Inventory.AddItem(Items.Wood.Id, 10);
        Inventory.AddItem(Items.Stone.Id, 10);
    }
}
