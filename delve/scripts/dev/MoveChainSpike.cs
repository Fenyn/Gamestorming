using System.Collections.Generic;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using Delve.Presets;
using Godot;
using PF2e.Core;
using PF2e.Grid;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>
/// Headless regression for multi-Stride smart moves. On several generated forest maps, with the
/// standard party and goblins on their deployment zones, it builds every party member's
/// <see cref="MovePlan"/> and, for every two- and three-action band tile, checks that each leg the
/// plan yields is one legal Stride from the previous leg's end (the executor re-paths per leg, so a
/// leg it cannot path is a walk that stops early). It then executes a sample of two-leg routes and
/// checks the mover ends on the clicked tile with two actions spent.
/// </summary>
public partial class MoveChainSpike : SpikeBase
{
    private static readonly int[] MapSeeds = { 20260804, 11, 23, 37, 41, 59 };

    /// <summary>Two-leg routes executed per party member on the first map.</summary>
    private const int ExecutedRoutesPerMember = 3;

    protected override string Banner => "==================== MOVE CHAIN SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        PresetSpells.EnsureRegistered();
        var goblinDef = data.ResolveCreature(EncounterTables.GoblinWarrior)!;

        int routes = 0;
        int brokenLegs = 0;
        int executed = 0;
        int strandings = 0;

        foreach (int mapSeed in MapSeeds)
        {
            var layout = MapGenerator.GenerateValidated("forest", mapSeed);
            var party = new List<ICharacter>
            {
                PresetCharacters.BuildPlayer(level: 2, teamId: 1),
                PresetCharacters.BuildElara(level: 2, teamId: 1),
                PresetCharacters.BuildTharr(level: 2, teamId: 1),
                PresetCharacters.BuildFenwick(level: 2, teamId: 1),
            };
            var setup = new CombatSetup { Layout = layout, BiomeId = "forest", RngSeed = mapSeed };
            var partyAnchors = DeploymentPlanner.GetAnchors(layout, teamId: 0, count: party.Count);
            for (int i = 0; i < party.Count; i++)
                setup.Party.Add((party[i], partyAnchors[System.Math.Min(i, partyAnchors.Count - 1)]));
            var enemyAnchors = DeploymentPlanner.GetAnchors(layout, teamId: 1, count: 5);
            for (int i = 0; i < 5; i++)
                setup.Enemies.Add((CreatureFactory.Create(goblinDef, teamId: 2), enemyAnchors[System.Math.Min(i, enemyAnchors.Count - 1)]));

            var session = new CombatSession();
            session.Setup(setup);
            session.SetPresenter(_ => Task.CompletedTask);
            try
            {
                foreach (var member in party)
                {
                    member.Actions!.RefillActions();
                    var plan = session.PlayerActions.GetMovePlan(member);
                    int speed = MovementActions.SpeedInTiles(member);
                    var twoLegRoutes = new List<PF2eVec>();

                    foreach (var (tile, option) in plan.Options)
                    {
                        if (option.Kind != MoveKind.Stride || option.Actions < 2) continue;
                        routes++;
                        if (plan.PathTo(tile, out var legs) == null || legs.Count != option.Actions || !legs[^1].Equals(tile))
                        {
                            brokenLegs++;
                            continue;
                        }
                        if (option.Actions == 2) twoLegRoutes.Add(tile);

                        var start = member.GridPosition;
                        foreach (var leg in legs)
                        {
                            if (Pathfinder.FindPath(session.Grid, start, leg, MovementActions.BuildRequest(member, speed)) == null)
                            {
                                brokenLegs++;
                                if (brokenLegs <= 5)
                                    GD.Print($"[MoveChain] map {mapSeed} {member.Name} {member.GridPosition} -> {tile}: leg {start} -> {leg} is not one Stride");
                                break;
                            }
                            start = leg;
                        }
                    }

                    if (mapSeed != MapSeeds[0]) continue;
                    var origin = member.GridPosition;
                    int sample = System.Math.Min(ExecutedRoutesPerMember, twoLegRoutes.Count);
                    for (int i = 0; i < sample; i++)
                    {
                        // Spread the sample across the band rather than taking its first tiles.
                        var dest = twoLegRoutes[i * twoLegRoutes.Count / sample];
                        plan.PathTo(dest, out var legs);
                        member.Actions.RefillActions();
                        foreach (var leg in legs)
                            if (!await session.PlayerActions.ExecuteStride(member, leg, triggersReactions: false)) break;
                        executed++;
                        bool arrived = member.GridPosition.Equals(dest) && member.Actions.TotalActionsRemaining == 1;
                        if (!arrived)
                        {
                            strandings++;
                            GD.Print($"[MoveChain] {member.Name} {origin} -> {dest}: ended at {member.GridPosition} with {member.Actions.TotalActionsRemaining} actions left");
                        }
                        session.Grid.MoveCreature(member, origin);
                    }
                }
            }
            finally
            {
                session.Teardown();
            }
        }

        Check($"every leg of a multi-Stride route is one legal Stride from the previous leg's end ({routes} routes, {brokenLegs} broken)",
            routes > 0 && brokenLegs == 0);
        Check($"executed two-leg routes end on the clicked tile with two actions spent ({executed} walked, {strandings} stranded)",
            executed > 0 && strandings == 0);
    }
}
