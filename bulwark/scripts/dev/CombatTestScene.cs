using System.Collections.Generic;
using Bulwark.Autoload;
using Bulwark.Combat;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Presets;
using Godot;
using PF2e;
using PF2e.Core;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Bulwark.Dev;

/// <summary>
/// F5 target for the playable combat slice: the canonical party of four versus five Goblin Warriors
/// on a 14x12 grid, handed to the combat scene. The party comes from GameState's LIVE squad roster
/// (HP / conditions / spell slots carry in and out — attrition), with a fresh-preset fallback so the
/// scene still runs standalone (F6). The encounter result is reported back to GameState so downed
/// allies stabilize, encounter-scoped state clears, and XP banks on victory.
///
/// Set <see cref="UseGeneratedMap"/> in the inspector to fight the same encounter on a generated 3D
/// battle map instead of the flat checker board: the layout comes from the biome catalog and both
/// sides deploy on their generated deployment zones. Off by default, so F5 is unchanged.
/// </summary>
public partial class CombatTestScene : Node
{
    /// <summary>Fight on a generated battle map instead of the flat board. Off = the original F5 board.</summary>
    [Export] public bool UseGeneratedMap { get; set; }

    /// <summary>Biome id to generate from when <see cref="UseGeneratedMap"/> is on ("forest", "sewer").</summary>
    [Export] public string Biome { get; set; } = "forest";

    /// <summary>Map seed. Same seed + biome always gives the same terrain.</summary>
    [Export] public int MapSeed { get; set; } = 20260804;

    public override void _Ready()
    {
        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[CombatTest] DataManager not loaded — aborting.");
            return;
        }

        // Consume the live squad instances (built once per save); fall back to throwaway presets
        // when the squad is unavailable (standalone runs without a GameState-owned roster).
        var squad = GameState.Instance?.Squad;
        ICharacter? veteran = squad?.FindMember(SquadRoster.PlayerId);
        ICharacter? scout = squad?.FindMember(SquadRoster.ElaraId);
        ICharacter? medic = squad?.FindMember(SquadRoster.TharrId);
        ICharacter? scholar = squad?.FindMember(SquadRoster.FenwickId);
        veteran ??= PresetCharacters.BuildPlayer(level: GameState.SquadStartLevel, teamId: 1);
        scout ??= PresetCharacters.BuildScout(level: GameState.SquadStartLevel, teamId: 1);
        medic ??= PresetCharacters.BuildTharr(level: GameState.SquadStartLevel, teamId: 1);
        scholar ??= PresetCharacters.BuildScholar(level: GameState.SquadStartLevel, teamId: 1);

        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior);
        if (goblinDef == null)
        {
            GD.PushError("[CombatTest] Could not resolve the Goblin Warrior — aborting.");
            return;
        }

        var enemies = new List<ICharacter>();
        for (int i = 0; i < CombatBoards.EnemyAnchors.Length; i++)
            enemies.Add(CreatureFactory.Create(goblinDef, teamId: 2));

        var partySlots = new[] { veteran, scout, medic, scholar };
        var setup = UseGeneratedMap
            ? BuildGeneratedSetup(partySlots, enemies)
            : BuildFlatSetup(partySlots, enemies);
        if (setup == null) return;

        var scene = GD.Load<PackedScene>("res://scenes/combat/combat.tscn").Instantiate<CombatScene>();
        AddChild(scene);

        // Report the outcome to the state root: stabilization, cleanup and XP happen there.
        scene.EncounterFinished += result =>
            GameState.Instance?.CompleteEncounter(result, enemies);

        scene.StartEncounter(setup);
    }

    /// <summary>The original flat 14x12 board with its hand-authored marching-order anchors.</summary>
    private static CombatSetup BuildFlatSetup(ICharacter[] partySlots, List<ICharacter> enemies)
    {
        var setup = new CombatSetup
        {
            GridWidth = CombatBoards.StandardWidth,
            GridHeight = CombatBoards.StandardHeight,
            RngSeed = 1337,
        };
        for (int i = 0; i < enemies.Count; i++)
            setup.Enemies.Add((enemies[i], CombatBoards.EnemyAnchors[i]));

        // Dead squad members sit the fight out (they only return via a future revival mechanic);
        // each survivor keeps their marching-order anchor.
        for (int i = 0; i < partySlots.Length; i++)
        {
            if (partySlots[i].Health == null || !partySlots[i].Health!.IsDead)
                setup.Party.Add((partySlots[i], CombatBoards.PartyAnchors[i]));
        }
        return setup;
    }

    /// <summary>
    /// The same encounter on a generated battle map. Anchors come from the layout's own deployment
    /// zones (team 0 is the player side, team 1 the enemy side in map-generation terms), so both sides
    /// start on walkable ground the generator marked as theirs — no fixed anchor table can do that on
    /// terrain it has never seen.
    /// </summary>
    private CombatSetup? BuildGeneratedSetup(ICharacter[] partySlots, List<ICharacter> enemies)
    {
        var layout = MapGenerator.GenerateValidated(Biome, MapSeed);
        if (layout == null)
        {
            GD.PushError($"[CombatTest] Could not generate a '{Biome}' map for seed {MapSeed} — aborting.");
            return null;
        }

        var survivors = new List<ICharacter>(partySlots.Length);
        foreach (var member in partySlots)
        {
            if (member.Health == null || !member.Health!.IsDead)
                survivors.Add(member);
        }

        var setup = new CombatSetup
        {
            Layout = layout,
            BiomeId = Biome,
            RngSeed = 1337,
        };

        var partyAnchors = DeploymentPlanner.GetAnchors(layout, teamId: 0, count: survivors.Count);
        for (int i = 0; i < survivors.Count; i++)
            setup.Party.Add((survivors[i], AnchorAt(partyAnchors, i)));

        var enemyAnchors = DeploymentPlanner.GetAnchors(layout, teamId: 1, count: enemies.Count);
        for (int i = 0; i < enemies.Count; i++)
            setup.Enemies.Add((enemies[i], AnchorAt(enemyAnchors, i)));

        GD.Print($"[CombatTest] generated '{Biome}' map {layout.Width}x{layout.Height} seed {layout.Seed} "
                 + $"({partyAnchors.Count} party / {enemyAnchors.Count} enemy anchors).");
        return setup;
    }

    /// <summary>
    /// The i-th anchor, falling back to the last one when the zone held fewer walkable tiles than the
    /// team has members. A duplicate anchor is legal input: <c>CombatSetup.Normalize</c> spreads the
    /// stack onto the nearest free walkable cells and reports each move.
    /// </summary>
    private static PF2eVec AnchorAt(List<PF2eVec> anchors, int index) =>
        anchors.Count == 0 ? default : anchors[System.Math.Min(index, anchors.Count - 1)];
}
