using System;
using Godot;

namespace Delve.UI;

/// <summary>Miniature scenery and atmosphere for one run-map biome.</summary>
public partial class MapSceneryTheme : Resource
{
    [Export] public string Id { get; set; } = "";
    [Export] public Texture2D[] Trees { get; set; } = Array.Empty<Texture2D>();
    [Export] public Texture2D Ground { get; set; } = null!;
    [Export] public Color GroundTint { get; set; } = Colors.White;
    [Export] public Color TreeTint { get; set; } = Colors.White;
    [Export] public Color FogColor { get; set; }
    [Export] public float FogDensity { get; set; } = 0.2f;
    [Export] public float Spacing { get; set; } = 46f;
    [Export] public float TreeHeight { get; set; } = 76f;
    [Export] public float ClearingChance { get; set; } = 0.15f;
    [Export] public int Pools { get; set; }
    [Export] public Color WaterColor { get; set; }
}
