using System.Collections.Generic;
using Godot;

namespace Delve.Village;

/// <summary>
/// The worn yards, roads and stream drawn by village_ground.gdshader. Each patch and road segment
/// carries the town tier that wears it in; <see cref="ApplyTier"/> hands the shader what exists.
/// </summary>
public partial class VillageGround : Node
{
    [Export] public GeometryInstance3D? Terrain { get; set; }

    /// <summary>Worn ellipses: centre X/Z and radius X/Z.</summary>
    [Export] public Vector4[] Patches { get; set; } = System.Array.Empty<Vector4>();
    [Export] public int[] PatchTiers { get; set; } = System.Array.Empty<int>();

    /// <summary>Road segments: start X/Z and end X/Z.</summary>
    [Export] public Vector4[] Roads { get; set; } = System.Array.Empty<Vector4>();
    [Export] public float[] RoadWidths { get; set; } = System.Array.Empty<float>();
    [Export] public int[] RoadTiers { get; set; } = System.Array.Empty<int>();

    /// <summary>Stream segments: start X/Z and end X/Z. The stream is there at every tier.</summary>
    [Export] public Vector4[] Stream { get; set; } = System.Array.Empty<Vector4>();

    /// <summary>Uniform array sizes in the shader.</summary>
    [Export] public int PatchSlots { get; set; } = 32;
    [Export] public int RoadSlots { get; set; } = 32;
    [Export] public int StreamSlots { get; set; } = 12;

    public void ApplyTier(int tier)
    {
        if (Terrain?.MaterialOverride is not ShaderMaterial ground) return;
        var patches = new List<Vector4>();
        for (int i = 0; i < Patches.Length; i++)
            if (TierOf(PatchTiers, i) <= tier) patches.Add(Patches[i]);
        var roads = new List<Vector4>();
        var widths = new List<float>();
        for (int i = 0; i < Roads.Length; i++)
            if (TierOf(RoadTiers, i) <= tier)
            {
                roads.Add(Roads[i]);
                widths.Add(i < RoadWidths.Length ? RoadWidths[i] : 1f);
            }
        ground.SetShaderParameter("patches", Padded(patches, PatchSlots));
        ground.SetShaderParameter("roads", Padded(roads, RoadSlots));
        while (widths.Count < RoadSlots) widths.Add(0);
        ground.SetShaderParameter("road_widths", widths.GetRange(0, RoadSlots).ToArray());
        ground.SetShaderParameter("stream", Padded(new List<Vector4>(Stream), StreamSlots));
    }

    private static int TierOf(int[] tiers, int index) => index < tiers.Length ? tiers[index] : 1;

    private static Vector4[] Padded(List<Vector4> values, int count)
    {
        while (values.Count < count) values.Add(Vector4.Zero);
        return values.GetRange(0, count).ToArray();
    }
}
