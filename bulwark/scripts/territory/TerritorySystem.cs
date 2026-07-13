using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Territory;

/// <summary>
/// The territory-loop system: travel + party selection, resource-node harvesting, and roaming-enemy
/// encounters. Pure C# (no scene tree) — GameState owns the single instance and wraps every mutation
/// in intent-named commands; the forest scene renders passively from queries + events.
///
/// State model:
///  - Location: <see cref="CurrentTerritoryId"/> (null = at the outpost). Travel in either direction
///    costs <see cref="TravelMinutes"/> game-minutes (constant).
///  - Party selection: up to <see cref="MaxCompanions"/> living companions picked at the gate; the
///    avatar (the player) always goes. The selection persists for the visit and rides the save
///    additively; on load the player is always back at the outpost (location is NOT persisted).
///  - Nodes: depleted on harvest; nodes whose definition has RespawnsDaily respawn when a new day
///    starts (DayClock.DayStarted), mirroring how FarmSystem hooks the overnight boundary.
///  - Roamers: a beaten roamer is despawned for the rest of the day (cleared on day start).
///  - Encounters: <see cref="BeginEncounter"/> rolls the roamer's weighted table, resolves creature
///    refs through the injected resolver (DataManager-backed), and builds the CombatSetup +
///    return context the combat scene consumes.
/// </summary>
public sealed class TerritorySystem
{
    /// <summary>Game-minutes one gate travel costs, each direction (documented constant).</summary>
    public const int TravelMinutes = 30;

    /// <summary>Max companions the player may take through the gate (the player is always along).</summary>
    public const int MaxCompanions = 3;

    /// <summary>Defeat penalty: each Resource-category stack loses count / 4 (integer floor).</summary>
    public const int DefeatPenaltyDivisor = 4;

    /// <summary>Combat grid used for territory encounters (aliases of the standard board in
    /// <see cref="CombatBoards"/> — the M1 combat slice).</summary>
    public const int GridWidth = CombatBoards.StandardWidth;
    public const int GridHeight = CombatBoards.StandardHeight;

    private readonly Inventory _inventory;
    private readonly DayClock _clock;
    private readonly SquadRoster? _squad;
    private readonly Func<CreatureRef, EnemyDefinition?>? _creatureResolver;
    private readonly Random _random = new();

    private readonly List<string> _companions = new();
    private readonly HashSet<string> _depletedNodes = new();   // "territoryId:nodeId"
    private readonly HashSet<string> _defeatedRoamers = new(); // "territoryId:roamerId"
    private string? _travelToast;

    /// <summary>Raised after a node's depleted state changes (harvest or respawn), with the node id.</summary>
    public event Action<string>? NodeChanged;

    /// <summary>Raised after a successful harvest, with the HUD view.</summary>
    public event Action<HarvestResultView>? ResourceHarvested;

    public TerritorySystem(
        Inventory inventory, DayClock clock, SquadRoster? squad,
        Func<CreatureRef, EnemyDefinition?>? creatureResolver)
    {
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _clock = clock ?? throw new ArgumentNullException(nameof(clock));
        _squad = squad;
        _creatureResolver = creatureResolver;

        _clock.DayStarted += OnDayStarted;
    }

    // ===================== Queries =====================

    /// <summary>The territory the player is in, or null at the outpost.</summary>
    public string? CurrentTerritoryId { get; private set; }

    /// <summary>Companion member ids selected at the gate (the player is implicit).</summary>
    public IReadOnlyList<string> SelectedCompanionIds => _companions;

    /// <summary>Encounter built by <see cref="BeginEncounter"/>, consumed by the combat scene.</summary>
    public TerritoryEncounter? PendingEncounter { get; private set; }

    public bool IsNodeDepleted(string territoryId, string nodeId)
        => _depletedNodes.Contains(Key(territoryId, nodeId));

    public bool IsRoamerDefeated(string territoryId, string roamerId)
        => _defeatedRoamers.Contains(Key(territoryId, roamerId));

    /// <summary>One-shot arrival notice ("Traveled to … — 30 min"), consumed by the next scene.</summary>
    public string? ConsumeTravelToast()
    {
        string? toast = _travelToast;
        _travelToast = null;
        return toast;
    }

    /// <summary>Build the gate panel view: leader plus the three selectable companions.</summary>
    public PartySelectView BuildPartySelectView(string territoryId)
    {
        var view = new PartySelectView
        {
            DestinationName = Territories.TryGet(territoryId, out var def) ? def.DisplayName : territoryId,
            TravelMinutes = TravelMinutes,
        };
        if (_squad == null)
            return view;

        foreach (var member in _squad.Members)
        {
            bool dead = member.Health == null || member.Health.IsDead;
            if (member.Id == SquadRoster.PlayerId)
            {
                view.LeaderName = member.Name;
                continue;
            }
            view.Companions.Add(new CompanionOptionView
            {
                Id = member.Id,
                Name = member.Name,
                HpText = dead ? "Dead" : $"HP {member.Health!.CurrentHP}/{member.Health.MaxHP}",
                CanJoin = !dead,
            });
        }
        return view;
    }

    // ===================== Travel =====================

    /// <summary>
    /// Travel from the outpost to a territory with up to three living companions. Validates the
    /// destination, the selection (count, duplicates, ids, alive, not the player) and that the
    /// Veteran himself can march. Spends <see cref="TravelMinutes"/> and always completes — a
    /// march that crosses the 30:00 dawn rollover simply arrives in the new morning (the rollover
    /// relocates nobody).
    /// </summary>
    public bool Travel(string territoryId, IReadOnlyList<string> companionIds)
    {
        if (CurrentTerritoryId != null || !Territories.IsDefined(territoryId))
            return false;
        if (_squad == null)
            return false;

        var veteran = _squad.FindMember(SquadRoster.PlayerId);
        if (veteran?.Health == null || veteran.Health.IsDead)
            return false;

        if (companionIds.Count > MaxCompanions)
            return false;
        if (companionIds.Distinct().Count() != companionIds.Count)
            return false;
        foreach (var id in companionIds)
        {
            if (id == SquadRoster.PlayerId)
                return false; // the avatar is not a companion slot
            var member = _squad.FindMember(id);
            if (member?.Health == null || member.Health.IsDead)
                return false;
        }

        _clock.SpendTime(TravelMinutes);

        CurrentTerritoryId = territoryId;
        _companions.Clear();
        _companions.AddRange(companionIds);
        _travelToast = $"Traveled to {Territories.Get(territoryId).DisplayName} — {TravelMinutes} min";
        return true;
    }

    /// <summary>
    /// Travel with the gate's all-hands default party: the player plus up to
    /// <see cref="MaxCompanions"/> living non-player ROSTER members (marching order), forming a
    /// party of at most four. Delegates to <see cref="Travel"/> — same validation, same 30-minute
    /// cost; the explicit selection path stays intact for future capability-limited trips.
    ///
    /// The roster is a POOL that grows past four via party-join (SquadRoster.InsertMember), but an
    /// adventuring party is always ≤4: with the default four-member roster this takes all three
    /// non-player companions (byte-identical to before); with a larger pool it caps at the first
    /// <see cref="MaxCompanions"/> living companions rather than over-filling the party. Explicit
    /// selection (<see cref="Travel"/> + <see cref="BuildPartySelectView"/>) is how the player picks
    /// WHICH members go once the pool exceeds four.
    /// </summary>
    public bool TravelWithFullParty(string territoryId)
    {
        if (_squad == null)
            return false;

        var companions = new List<string>();
        foreach (var member in _squad.Members)
        {
            if (companions.Count >= MaxCompanions)
                break; // an adventuring party is capped at Veteran + MaxCompanions, even with a larger roster
            if (member.Id == SquadRoster.PlayerId)
                continue;
            if (member.Health != null && !member.Health.IsDead)
                companions.Add(member.Id);
        }
        return Travel(territoryId, companions);
    }

    /// <summary>Travel back to the outpost (same constant cost, always completes).</summary>
    public bool TravelToOutpost()
    {
        if (CurrentTerritoryId == null)
            return false;

        _clock.SpendTime(TravelMinutes);
        CurrentTerritoryId = null;
        _travelToast = $"Traveled to the outpost — {TravelMinutes} min";
        return true;
    }

    /// <summary>
    /// Called by the voluntary sleep command and the defeat wake: either way, the player wakes at
    /// the outpost with the gate selection cleared for the next embark. (The 30:00 all-nighter
    /// rollover deliberately does NOT call this — nobody is relocated by staying up.)
    /// </summary>
    public void OnSlept()
    {
        CurrentTerritoryId = null;
        _companions.Clear();
    }

    // ===================== Harvest =====================

    /// <summary>
    /// Harvest a resource node in the current territory with the active tool. Validates location,
    /// node id, depletion and the tool gate (no time is spent on a failed attempt); then charges the
    /// node's harvest minutes, adds the yield to the shared inventory, depletes the node, and raises
    /// <see cref="NodeChanged"/> + <see cref="ResourceHarvested"/>.
    /// </summary>
    public bool Harvest(string nodeId, ToolKind tool)
    {
        if (CurrentTerritoryId == null || !Territories.TryGet(CurrentTerritoryId, out var territory))
            return false;

        var placement = territory.Nodes.FirstOrDefault(n => n.NodeId == nodeId);
        if (placement == null || !ResourceNodes.TryGet(placement.ResourceId, out var def))
            return false;

        string key = Key(territory.Id, nodeId);
        if (_depletedNodes.Contains(key))
            return false;
        if (tool != def.Tool)
            return false;

        _clock.SpendTime(def.HarvestMinutes);
        _inventory.AddItem(def.YieldItemId, def.YieldCount);
        _depletedNodes.Add(key);
        NodeChanged?.Invoke(nodeId);

        ResourceHarvested?.Invoke(new HarvestResultView
        {
            NodeName = def.DisplayName,
            ItemName = Items.TryGet(def.YieldItemId, out var item) ? item.DisplayName : def.YieldItemId,
            Count = def.YieldCount,
            MinutesSpent = def.HarvestMinutes,
        });
        return true;
    }

    // ===================== Encounters =====================

    /// <summary>
    /// Build the pending encounter for a roamer contact: roll its weighted table, resolve and
    /// instantiate the creatures (team 2), and assemble the party from the LIVE squad — the player
    /// plus the gate-selected companions, living members only; everyone else sits out. Returns false
    /// (no state change) when out of territory, the roamer is unknown/already beaten today, the
    /// squad or creature content is unavailable, or an encounter is already pending.
    /// </summary>
    public bool BeginEncounter(string roamerId, Vector2 playerPosition)
    {
        if (CurrentTerritoryId == null || !Territories.TryGet(CurrentTerritoryId, out var territory))
            return false;
        if (PendingEncounter != null || _squad == null || _creatureResolver == null)
            return false;
        if (IsRoamerDefeated(territory.Id, roamerId))
            return false;

        var roamer = territory.Roamers.FirstOrDefault(r => r.RoamerId == roamerId);
        if (roamer == null || roamer.Encounters.Count == 0)
            return false;

        var encounterId = PickWeighted(roamer.Encounters);
        if (!EncounterTables.TryGet(encounterId, out var encounter))
            return false;

        var enemies = BuildEnemies(encounter);
        if (enemies == null || enemies.Count == 0)
            return false;

        var party = BuildParty();
        if (party.Count == 0)
            return false;

        var setup = new CombatSetup { GridWidth = GridWidth, GridHeight = GridHeight };
        for (int i = 0; i < party.Count && i < CombatBoards.PartyAnchors.Length; i++)
            setup.Party.Add((party[i], CombatBoards.PartyAnchors[i]));
        for (int i = 0; i < enemies.Count && i < CombatBoards.EnemyAnchors.Length; i++)
            setup.Enemies.Add((enemies[i], CombatBoards.EnemyAnchors[i]));

        PendingEncounter = new TerritoryEncounter
        {
            TerritoryId = territory.Id,
            RoamerId = roamerId,
            EncounterId = encounter.Id,
            EncounterName = encounter.DisplayName,
            ReturnPosition = playerPosition,
            Setup = setup,
            Enemies = enemies,
        };
        return true;
    }

    /// <summary>
    /// Close out the pending encounter: on victory the roamer despawns for the day and the player
    /// returns to the territory (return context in the result); on defeat the visit ends — location
    /// and gate selection reset (GameState runs the wake-at-outpost flow). Returns the closed
    /// encounter (null when none was pending).
    /// </summary>
    public TerritoryEncounter? CompleteEncounter(bool victory)
    {
        var encounter = PendingEncounter;
        PendingEncounter = null;
        if (encounter == null)
            return null;

        if (victory)
        {
            _defeatedRoamers.Add(Key(encounter.TerritoryId, encounter.RoamerId));
        }
        else
        {
            CurrentTerritoryId = null;
            _companions.Clear();
        }
        return encounter;
    }

    /// <summary>
    /// Defeat penalty: every Resource-category stack loses count / <see cref="DefeatPenaltyDivisor"/>
    /// (integer floor — small stacks lose nothing). Crops, seeds and tools are untouched. Returns the
    /// summary the outpost wake toast shows.
    /// </summary>
    public DefeatSummaryView ApplyDefeatPenalty()
    {
        var summary = new DefeatSummaryView();

        // Snapshot first: RemoveItem mutates the stacks dictionary we would otherwise iterate.
        var stacks = _inventory.Stacks.ToList();
        foreach (var (itemId, count) in stacks)
        {
            if (!Items.TryGet(itemId, out var item) || item.Category != ItemCategory.Resource)
                continue;

            int lost = count / DefeatPenaltyDivisor;
            if (lost <= 0)
                continue;

            _inventory.RemoveItem(itemId, lost);
            summary.Losses.Add(new DefeatLossView { ItemName = item.DisplayName, Lost = lost });
        }
        return summary;
    }

    // ===================== Save bridge =====================

    /// <summary>Snapshot the persisted territory state (selection + depleted/defeated sets).</summary>
    public TerritoryDto CaptureState() => new()
    {
        SelectedCompanionIds = new List<string>(_companions),
        DepletedNodeIds = new List<string>(_depletedNodes),
        DefeatedRoamerIds = new List<string>(_defeatedRoamers),
    };

    /// <summary>
    /// Overwrite territory state from a save. Null = pre-M3 save = everything fresh. Location is
    /// deliberately NOT restored: the player always loads back at the outpost (documented M3 rule),
    /// so the persisted selection simply stands ready for the next gate confirm.
    /// </summary>
    public void RestoreState(TerritoryDto? dto)
    {
        CurrentTerritoryId = null;
        PendingEncounter = null;
        _companions.Clear();
        _depletedNodes.Clear();
        _defeatedRoamers.Clear();
        if (dto == null)
            return;

        _companions.AddRange(dto.SelectedCompanionIds.Where(id => !string.IsNullOrEmpty(id)));
        foreach (var key in dto.DepletedNodeIds)
            _depletedNodes.Add(key);
        foreach (var key in dto.DefeatedRoamerIds)
            _defeatedRoamers.Add(key);
    }

    // ===================== Internals =====================

    private static string Key(string territoryId, string localId) => $"{territoryId}:{localId}";

    private void OnDayStarted()
    {
        // Roamers respawn every morning; nodes respawn per their definition flag.
        _defeatedRoamers.Clear();

        // Decide first, mutate second, notify last — subscribers reading IsNodeDepleted from a
        // NodeChanged handler must observe the settled post-respawn state.
        var respawned = new List<(string Key, string NodeId)>();
        foreach (var key in _depletedNodes)
        {
            var (territoryId, nodeId) = SplitKey(key);
            if (territoryId == null || !Territories.TryGet(territoryId, out var territory))
            {
                respawned.Add((key, nodeId ?? "")); // stale key — drop it
                continue;
            }
            // Daily nodes (and stale placements) respawn; one-shot nodes (RespawnsDaily=false)
            // keep their key and stay depleted.
            var placement = territory.Nodes.FirstOrDefault(n => n.NodeId == nodeId);
            if (placement == null || !ResourceNodes.TryGet(placement.ResourceId, out var def)
                || def.RespawnsDaily)
            {
                respawned.Add((key, nodeId!));
            }
        }

        foreach (var (key, _) in respawned)
            _depletedNodes.Remove(key);
        foreach (var (_, nodeId) in respawned)
        {
            if (!string.IsNullOrEmpty(nodeId))
                NodeChanged?.Invoke(nodeId);
        }
    }

    private static (string?, string?) SplitKey(string key)
    {
        int idx = key.IndexOf(':');
        return idx <= 0 ? (null, null) : (key[..idx], key[(idx + 1)..]);
    }

    private string PickWeighted(IReadOnlyList<WeightedEncounter> entries)
    {
        int total = 0;
        foreach (var e in entries)
            total += Math.Max(1, e.Weight);

        int roll = _random.Next(total);
        foreach (var e in entries)
        {
            roll -= Math.Max(1, e.Weight);
            if (roll < 0)
                return e.EncounterId;
        }
        return entries[^1].EncounterId;
    }

    private List<ICharacter>? BuildEnemies(Bulwark.Data.EncounterDefinition encounter)
    {
        var enemies = new List<ICharacter>();
        foreach (var line in encounter.Creatures)
        {
            var def = _creatureResolver!(line.Creature);
            if (def == null)
                return null; // content unavailable — fail the whole encounter cleanly

            for (int i = 0; i < line.Count; i++)
                enemies.Add(CreatureFactory.Create(def, teamId: 2));
        }
        return enemies;
    }

    /// <summary>Veteran first, then the selected companions in pick order — living members only.</summary>
    private List<ICharacter> BuildParty()
    {
        var party = new List<ICharacter>();
        var veteran = _squad!.FindMember(SquadRoster.PlayerId);
        if (veteran?.Health != null && !veteran.Health.IsDead)
            party.Add(veteran);

        foreach (var id in _companions)
        {
            var member = _squad.FindMember(id);
            if (member?.Health != null && !member.Health.IsDead)
                party.Add(member);
        }
        return party;
    }
}
