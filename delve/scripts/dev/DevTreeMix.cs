using Delve.Terrain;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The halo tree mix for spikes that build a bare <see cref="TerrainStage"/> in code. Mirrors the
/// exports wired on combat.tscn's TerrainStage node — keep the two in step, or spike shots stop
/// looking like the game.
/// </summary>
internal static class DevTreeMix
{
    internal static void Apply(TerrainStage stage)
    {
        stage.HaloTreeScenes = new[]
        {
            GD.Load<PackedScene>("res://scenes/props/tree_canopy.tscn"),
            GD.Load<PackedScene>("res://scenes/props/tree_conifer.tscn"),
            GD.Load<PackedScene>("res://scenes/props/tree_bush.tscn"),
            GD.Load<PackedScene>("res://scenes/props/tree_dead.tscn"),
            GD.Load<PackedScene>("res://scenes/props/tree_giant.tscn"),
        };
        stage.HaloTreeWeights = new[] { 3f, 3f, 1.5f, 0.8f, 0.2f };
        stage.HaloTreeMinRings = new[] { 4f, 4f, 0f, 4f, 6f };
        stage.BoardTreeScenes = new[]
        {
            GD.Load<PackedScene>("res://scenes/props/tree_canopy.tscn"),
            GD.Load<PackedScene>("res://scenes/props/tree_conifer.tscn"),
        };
        stage.BoardTreeWeights = new[] { 3f, 2f };
    }
}
