using System.Linq;
using System.Threading.Tasks;
using Godot;

namespace Delve.Dev;

/// <summary>Every 3D model in rows on open grass south-west of town, shot at the stop camera, for asset reviews.</summary>
public partial class HubMockSpike
{
    private static readonly string[] LineupProps =
        { "well", "cart", "anvil", "lamp", "sign", "board", "table", "log", "stump", "woodpile", "fence", "crate", "barrel", "crop_bed0", "grindstone", "scarecrow" };

    private async Task RunLineup()
    {
        var origin = new Vector3(-22, 0, 37);
        // Clear the forest off the lineup ground.
        foreach (var (tree, twin) in _treeSwaps.ToList())
            if (Mathf.Abs(tree.Position.X - origin.X) < 22 && tree.Position.Z > origin.Z - 14 && tree.Position.Z < origin.Z + 14)
            {
                tree.QueueFree();
                twin.QueueFree();
                _treeSwaps.Remove((tree, twin));
                _forest.RemoveAll(f => f.Tree == tree);
            }
        var lineup = new Node3D();
        _outpost.AddChild(lineup);
        float x = -10;
        for (int i = 0; i < LineupProps.Length; i++)
        {
            if (Model(LineupProps[i]) is not { } model) continue;
            bool back = i % 2 == 0;
            Stand(lineup, model, origin + new Vector3(x, 0, back ? -1.6f : 2.2f), Yaw);
            x += 1.6f;
        }
        foreach (var (name, dx) in new[] { ("tree_cards", -6f), ("tree_cards2", 0f), ("tree_pine", 7f) })
            if (Model(name) is { } tree) Stand(lineup, tree, origin + new Vector3(dx, 0, -7f), 0);
        var houses = new Node3D();
        _outpost.AddChild(houses);
        foreach (var (row, z) in new[] { (new[] { "house_04", "house_05", "house_06" }, -8f), (new[] { "house_01", "house_02", "house_03" }, 6f) })
        {
            float hx = -13;
            foreach (string name in row)
            {
                var (house, _) = House3D(new Site(3, 3, Vector2.Zero, Building: name));
                house.Reparent(houses);
                var spot = origin + new Vector3(hx + Shapes[name].X / 2f, 0, z);
                house.Position = spot with { Y = _terrain.HeightAt(spot) };
                house.RotationDegrees = Vector3.Zero;
                hx += Shapes[name].X + 1.5f;
                GD.Print($"[lineup] {name} at {house.GlobalPosition} children {house.GetChildCount()} visible {house.Visible}");
            }
        }
        houses.Hide();

        _props3D = _trees3D = _solid = true;
        lineup.Show();
        await VillageShot(3, Time.Afternoon, "lineup_props", origin + new Vector3(0, 1.2f, -2.5f), 34f, 34.7f, System.Array.Empty<(string, string, Vector3, Job, string, int, int, Facing)>());
        lineup.Hide();
        houses.Show();
        await VillageShot(3, Time.Afternoon, "lineup_houses", origin + new Vector3(0, 2f, 0), 34f, 46.3f, System.Array.Empty<(string, string, Vector3, Job, string, int, int, Facing)>());
        await VillageShot(3, Time.Evening, "lineup_houses_evening", origin + new Vector3(0, 2f, 0), 34f, 46.3f, System.Array.Empty<(string, string, Vector3, Job, string, int, int, Facing)>());
        houses.Hide();
        _props3D = _trees3D = _solid = false;
    }

    private void Stand(Node3D parent, Node3D model, Vector3 spot, float yaw)
    {
        parent.AddChild(model);
        model.Position = spot with { Y = _terrain.HeightAt(spot) };
        model.RotationDegrees = new Vector3(0, yaw, 0);
    }
}
