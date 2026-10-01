using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The Blender houses (scratchpad blender/houses.py): gable-front, laid out on a 1.5 u panel grid,
/// loaded from GLB. Their glass swaps to the pack's authored lit window in the evening, and a warm
/// light spills from the front.
/// </summary>
public partial class HubMockSpike
{
    /// <summary>Footprint width and depth of each house GLB (houses.py).</summary>
    private static readonly Dictionary<string, Vector2> Shapes = new()
    {
        ["house_01"] = new(4.5f, 4.5f), ["house_02"] = new(4.5f, 6.0f), ["house_03"] = new(6.0f, 6.0f),
        ["house_04"] = new(7.5f, 6.0f), ["house_05"] = new(9.0f, 6.0f), ["house_06"] = new(6.0f, 7.5f),
    };

    /// <summary>Door centre across each house front (houses.py door panel), for the worn patch at the step.</summary>
    private static readonly Dictionary<string, float> DoorX = new()
    {
        ["house_01"] = 0f, ["house_02"] = 0f, ["house_03"] = -0.75f, ["house_04"] = 0f, ["house_05"] = -2.25f, ["house_06"] = -0.75f,
    };

    private readonly List<(Site Site, Node3D House, OmniLight3D Light)> _houses = new();
    private readonly List<BaseMaterial3D> _glass = new();
    private Texture2D? _windowDay, _windowLit;
    private bool _solid;

    private (Node3D House, OmniLight3D Light) House3D(Site site)
    {
        var house = Model(site.Building) ?? new Node3D();
        _outpost.AddChild(house);
        float depth = Shapes[site.Building].Y;
        var spot = new Vector3(site.At.X, 0, site.At.Y - 0.3f - depth / 2f);
        house.Position = spot with { Y = _terrain.HeightAt(new Vector3(site.At.X, 0, site.At.Y)) };
        house.RotationDegrees = new Vector3(0, site.Yaw * 0.6f, 0);
        var light = new OmniLight3D { LightColor = new Color(1f, 0.72f, 0.4f), OmniRange = 4.5f, LightEnergy = 0f };
        house.AddChild(light);
        light.Position = new Vector3(0, 1.6f, depth / 2f + 1.0f);
        Dress(house, site.Building);
        return (house, light);
    }

    /// <summary>Each trade's goods at its door, in the house's local frame (+Z is the front).</summary>
    private static readonly Dictionary<string, (string Model, float X, float Z, float Yaw)[]> Dressing = new()
    {
        ["house_01"] = new[] { ("crate", 3.0f, 1.9f, 10f), ("crate", 3.0f, 0.9f, -5f), ("crate", 3.9f, 1.5f, 20f), ("barrel", -3.0f, -0.6f, 0f), ("barrel", -3.0f, -1.5f, 0f), ("sacks", 2.65f, 3.15f, 20f) },
        ["house_02"] = new[] { ("barrel", 2.9f, 3.6f, 0f), ("crate", -2.9f, 3.4f, 15f), ("stump", -2.0f, 4.2f, 0f),
            ("herb_pot", -1.5f, 4.85f, 0f), ("herb_pot", 1.5f, 4.85f, 40f) },
        ["house_03"] = new[] { ("log", -1.8f, 4.0f, 0f), ("barrel", 3.6f, 2.4f, 0f) },
        ["house_04"] = new[] { ("table", -2.4f, 4.4f, 0f), ("log", -2.4f, 5.5f, 0f), ("barrel", 3.4f, 3.4f, 0f), ("barrel", 3.4f, 2.6f, 0f) },
        ["house_05"] = new[] { ("anvil", 6.1f, 0.8f, 90f), ("barrel", 7.0f, -1.6f, 0f), ("woodpile", 6.4f, -2.2f, 0f), ("tool_rack", 4.62f, 0.2f, 90f) },
        ["house_06"] = new[] { ("woodpile", 3.7f, 0.5f, 0f), ("barrel", 2.6f, 4.15f, 0f), ("stump", -1.2f, 4.25f, 0f) },
    };

    private void Dress(Node3D house, string building)
    {
        foreach (var (name, x, z, yaw) in Dressing.GetValueOrDefault(building, System.Array.Empty<(string, float, float, float)>()))
            if (Model(name) is { } prop)
            {
                house.AddChild(prop);
                prop.Position = new Vector3(x, 0, z);
                prop.RotationDegrees = new Vector3(0, yaw, 0);
            }
        // Grass tufts where the plinth meets the lawn.
        if (_outpost.GetNodeOrNull<Sprite3D>("CampGrass0") is not { } tuft) return;
        var size = Shapes[building];
        float lift = tuft.Position.Y - _terrain.HeightAt(tuft.Position);
        foreach (var (sx, sz) in new[] { (-1f, 1f), (1f, 1f), (-1f, -1f), (1f, -1f), (-0.5f, 1f), (0.6f, 1f) })
        {
            var grass = (Sprite3D)tuft.Duplicate();
            house.AddChild(grass);
            grass.Show();
            grass.Position = new Vector3(sx * (size.X / 2f + 0.2f), lift, sz * (size.Y / 2f + 0.2f));
        }
    }

    /// <summary>Shows the cards or the 3D houses; evening lights the glass and the door light.</summary>
    private void ShowHouses(int tier, Time time, bool close, Vector3 target)
    {
        foreach (var (site, sprite, _) in _sites)
            if (site.Building.Length > 0 && _solid) sprite.Visible = false;
        bool evening = time == Time.Evening;
        _windowDay ??= Pack("ih_window");
        _windowLit ??= Pack("ih_window_lit");
        // Lit panes show the pack's lit-window art as drawn (unshaded, no emission); the house light does the glow.
        foreach (var glass in _glass)
        {
            glass.AlbedoTexture = evening ? _windowLit : _windowDay;
            glass.ShadingMode = evening ? BaseMaterial3D.ShadingModeEnum.Unshaded : BaseMaterial3D.ShadingModeEnum.PerPixel;
        }
        foreach (var (site, house, light) in _houses)
        {
            house.Visible = _solid && tier >= site.From && tier <= site.To && !(close && InFront(house, target));
            light.LightEnergy = house.Visible && evening ? 1.4f : 0f;
        }
        foreach (var (_, node) in _shadows) node.Visible = node.Visible && !_solid;
    }
}
