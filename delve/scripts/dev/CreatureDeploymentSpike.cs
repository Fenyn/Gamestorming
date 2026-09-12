using System;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Data;
using PF2e.Core;
using PF2e.MapGen;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Dev;

/// <summary>Exercises deployment with actual monster sizes, including non-anchor collisions.</summary>
public partial class CreatureDeploymentSpike : SpikeBase
{
    protected override Task RunSpikeAsync(DataManager data)
    {
        var large = Load(data, "Dire Wolf", "dire-wolf");
        var medium = Load(data, "Giant Viper", "giant-viper");
        Check("loaded Dire Wolf occupies 2x2", large.TileWidth == 2);
        Check("loaded Giant Viper occupies 1x1", medium.TileWidth == 1);

        var covered = new CombatSetup
        {
            GridWidth = 5, GridHeight = 5,
            Party = new() { (large, new PF2eVec(1, 1)) },
            Enemies = new() { (medium, new PF2eVec(2, 2)) },
        };
        var corrections = covered.Normalize();
        Check("non-anchor cell of Large reserves space against later Medium",
            corrections.Count == 1 && !Overlaps(covered.Party[0], covered.Enemies[0]));
        Check("legal Large anchor stays fixed", covered.Party[0].Pos == new PF2eVec(1, 1));
        Check("normalized deployment is stable", covered.Normalize().Count == 0);

        var incoming = new CombatSetup
        {
            GridWidth = 5, GridHeight = 5,
            Party = new() { (medium, new PF2eVec(2, 2)) },
            Allies = new() { (large, new PF2eVec(1, 1)) },
        };
        Check("Large checks occupied non-anchor cell before placement",
            incoming.Normalize().Count == 1 && !Overlaps(incoming.Party[0], incoming.Allies[0]));
        Check("repair picks a nearest one-step legal anchor",
            Math.Max(Math.Abs(incoming.Allies[0].Pos.x - 1), Math.Abs(incoming.Allies[0].Pos.y - 1)) == 1);

        var edge = new CombatSetup
        {
            GridWidth = 5, GridHeight = 4,
            Enemies = new() { (large, new PF2eVec(4, 3)) },
        };
        Check("Large at board edge repairs full footprint",
            edge.Normalize().Count == 1 && edge.Enemies[0].Pos == new PF2eVec(3, 2));

        var layout = new MapLayout { Name = "deployment-wall", Seed = 0 };
        layout.Initialize(5, 5);
        for (int y = 0; y < 5; y++)
            for (int x = 0; x < 5; x++) layout.SetTile(x, y, TileRole.Ground);
        layout.SetTile(2, 2, TileRole.Wall);
        var wall = new CombatSetup { Layout = layout, Enemies = new() { (large, new PF2eVec(1, 1)) } };
        Check("Large moves when only non-anchor tile is a wall", wall.Normalize().Count == 1);
        bool walkable = true;
        for (int y = 0; y < large.TileWidth; y++)
            for (int x = 0; x < large.TileWidth; x++)
                walkable &= layout.IsWalkable(wall.Enemies[0].Pos.x + x, wall.Enemies[0].Pos.y + y);
        Check("every repaired footprint tile is walkable", walkable);

        var blocked = new CombatSetup
        {
            GridWidth = 2, GridHeight = 2,
            Party = new() { (medium, new PF2eVec(1, 1)) },
            Enemies = new() { (large, new PF2eVec(0, 0)) },
        };
        Check("free anchor cannot hide no fitting Large footprint", FailsClearly(blocked));
        var tooNarrow = new CombatSetup
        {
            GridWidth = 1, GridHeight = 4,
            Enemies = new() { (large, new PF2eVec(0, 0)) },
        };
        Check("board narrower than creature fails clearly", FailsClearly(tooNarrow));
        return Task.CompletedTask;
    }

    private static ICharacter Load(DataManager data, string name, string slug) => CreatureFactory.Create(
        data.ResolveCreature(new CreatureRef { DisplayName = name, Slug = slug, Pack = "pathfinder-monster-core" })
            ?? throw new InvalidOperationException($"Missing actual creature {name}"), teamId: 2);

    private static bool Overlaps((ICharacter Unit, PF2eVec Pos) a, (ICharacter Unit, PF2eVec Pos) b)
        => a.Pos.x < b.Pos.x + b.Unit.TileWidth && b.Pos.x < a.Pos.x + a.Unit.TileWidth
        && a.Pos.y < b.Pos.y + b.Unit.TileWidth && b.Pos.y < a.Pos.y + a.Unit.TileWidth;

    private static bool FailsClearly(CombatSetup setup)
    {
        try { setup.Normalize(); return false; }
        catch (InvalidOperationException e)
        {
            return e.Message.Contains("2x2 footprint") && e.Message.Contains("Dire Wolf");
        }
    }
}
