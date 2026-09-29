using Delve.Terrain;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The biome lighting setups for spikes that build a bare <see cref="TerrainStage"/> in code.
/// Mirrors the Looks exports wired on combat.tscn's TerrainStage node; keep the two in step.
/// </summary>
internal static class DevLooks
{
    internal static void Apply(TerrainStage stage)
    {
        stage.Looks = new Godot.Collections.Dictionary<string, PackedScene>
        {
            ["forest"] = GD.Load<PackedScene>("res://scenes/looks/forest.tscn"),
            ["sewer"] = GD.Load<PackedScene>("res://scenes/looks/sewer.tscn"),
        };
        stage.DefaultLook = GD.Load<PackedScene>("res://scenes/looks/default.tscn");
    }
}
