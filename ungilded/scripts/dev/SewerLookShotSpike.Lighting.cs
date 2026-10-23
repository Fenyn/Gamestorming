using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Combat;
using Ungilded.Content;

namespace Ungilded.Dev;

public partial class SewerLookShotSpike
{
    /// <summary>Dolly of the two-hero shot, wide enough to take in the torch behind them.</summary>
    [Export] public float LitDolly { get; set; } = 0.7f;

    /// <summary>Heights above the Friend's feet, metres, where <c>[light]</c> samples his sprite.</summary>
    [Export] public float[] LitSampleHeights { get; set; } = { 0.15f, 0.55f, 0.95f };

    /// <summary>Distance from the Friend, metres, within which <c>[torch]</c> prints a torch's energy.</summary>
    [Export] public float LitTorchMetres { get; set; } = 8f;

    /// <summary>Metres beside the Friend's feet, along the camera's right, where <c>[light]</c> samples the floor.</summary>
    [Export] public float LitFloorOffset { get; set; } = 0.9f;

    /// <summary>Saves both heroes with the HUD hidden as <c>sewer_lit.png</c> and prints the Friend's
    /// sprite colour at <see cref="LitSampleHeights"/>. With UNGILDED_LIGHT_TERMS set it repeats the
    /// shot under each light alone (<c>sewer_lit_ambient.png</c>, <c>_key</c>, <c>_torch</c>,
    /// <c>_lantern</c>). Last it saves the Player standing in a torch pool (<see cref="PoolShot"/>).</summary>
    private async Task LitShots(CombatScene scene)
    {
        var units = scene.FindChildren("*", nameof(Node3D), true, false).OfType<UnitVisual3D>().ToList();
        var friend = units.FirstOrDefault(u => u.Character.Id == PrologueCast.FriendId);
        var player = units.FirstOrDefault(u => u.Character.Id == PrologueCast.PlayerId);
        var rig = Rig();
        if (friend == null || player == null || rig == null) { Check("both heroes are on the board", false); return; }
        rig.FocusForInspection((friend.GlobalPosition + player.GlobalPosition) * 0.5f);
        rig.SetDolly(LitDolly);
        await WaitSeconds(rig.FocusSeconds + SettleSeconds);
        Check("two-hero lit shot saved", Save("sewer_lit.png"));
        PrintSamples("all", friend);

        var lights = GetTree().Root.FindChildren("*", nameof(Light3D), true, false).OfType<Light3D>().Where(l => l.Visible).ToList();
        var lantern = friend.FindChildren("*", nameof(Sprite3D), true, false).OfType<HandLantern>().FirstOrDefault()?.Light;
        var torches = lights.OfType<OmniLight3D>().Where(l => l.IsVisibleInTree() && l != lantern).ToList();
        PrintTorchEnergy(torches, friend.GlobalPosition);
        if (!string.IsNullOrEmpty(System.Environment.GetEnvironmentVariable("UNGILDED_LIGHT_TERMS")))
            await LightTerms(friend, lights, lantern);
        if (torches.Count > 0) await PoolShot(player, rig, torches);
        else GD.Print("[torch] none on the board, no pool shot");
    }

    private async Task LightTerms(Node3D friend, List<Light3D> lights, Light3D? lantern)
    {
        var environment = GetTree().Root.FindChildren("*", nameof(WorldEnvironment), true, false).OfType<WorldEnvironment>().First().Environment;
        float ambientEnergy = environment.AmbientLightEnergy;

        var terms = new Dictionary<string, System.Func<Light3D, bool>>
        {
            ["ambient"] = _ => false,
            ["key"] = l => l is DirectionalLight3D,
            ["torch"] = l => l is OmniLight3D && l != lantern,
            ["lantern"] = l => l == lantern,
        };
        foreach (var (term, keep) in terms)
        {
            environment.AmbientLightEnergy = term == "ambient" ? ambientEnergy : 0f;
            foreach (var light in lights) light.Visible = keep(light);
            await WaitSeconds(PollSeconds);
            Save($"sewer_lit_{term}.png");
            PrintSamples(term, friend);
        }
        environment.AmbientLightEnergy = ambientEnergy;
        foreach (var light in lights) light.Visible = true;
    }

    /// <summary>Metres out from the wall, below the torch nearest the Player, where the pool shot stands him.</summary>
    [Export] public float PoolStandMetres { get; set; } = 1.5f;

    /// <summary>Stands the Player's token in the pool of the nearest torch, saves <c>sewer_lit_pool.png</c>
    /// and puts him back. Only the visual moves; the board does not.</summary>
    private async Task PoolShot(Node3D player, OrbitCameraRig rig, List<OmniLight3D> torches)
    {
        var home = player.GlobalPosition;
        var torch = torches.OrderBy(t => t.GlobalPosition.DistanceTo(home)).FirstOrDefault();
        if (torch?.GetParent() is not Node3D mount) { Check("a torch stands near the Player", false); return; }
        var outward = (torch.GlobalPosition - mount.GlobalPosition) with { Y = 0f };
        var stand = (torch.GlobalPosition + outward.Normalized() * PoolStandMetres) with { Y = home.Y };
        player.GlobalPosition = stand;
        rig.FocusForInspection(stand);
        await WaitSeconds(rig.FocusSeconds + SettleSeconds);
        Check("pool shot saved", Save("sewer_lit_pool.png"));
        player.GlobalPosition = home;
    }

    /// <summary>Prints the energy of the torches within <see cref="LitTorchMetres"/> of the Friend at
    /// the moment of the shot, nearest first, so two shots can be told apart by flicker.</summary>
    private void PrintTorchEnergy(IEnumerable<OmniLight3D> torches, Vector3 from)
    {
        var near = torches.Select(t => (Torch: t, Metres: t.GlobalPosition.DistanceTo(from)))
            .Where(t => t.Metres <= LitTorchMetres).OrderBy(t => t.Metres)
            .Select(t => $"{t.Metres:0.0} m energy {t.Torch.LightEnergy:0.00}");
        GD.Print($"[torch] {string.Join("  ", near)}");
    }

    private void PrintSamples(string term, Node3D friend)
    {
        var camera = GetViewport().GetCamera3D();
        using var image = GetViewport().GetTexture().GetImage();
        image.Convert(Image.Format.Rgba8);
        if (ProjectSettings.GetSetting("rendering/viewport/hdr_2d").AsBool()) image.LinearToSrgb();
        var points = LitSampleHeights.Select(h => ($"{h:0.00} m", friend.GlobalPosition + Vector3.Up * h))
            .Append(("floor", friend.GlobalPosition + camera.GlobalBasis.X.Slide(Vector3.Up).Normalized() * LitFloorOffset));
        var parts = points.Select(point =>
        {
            var p = camera.UnprojectPosition(point.Item2);
            Color sum = new(0, 0, 0, 0);
            int n = 0;
            for (int dy = -3; dy <= 3; dy++)
                for (int dx = -3; dx <= 3; dx++)
                {
                    int x = (int)p.X + dx, y = (int)p.Y + dy;
                    if (x < 0 || y < 0 || x >= image.GetWidth() || y >= image.GetHeight()) continue;
                    sum += image.GetPixel(x, y);
                    n++;
                }
            var c = n > 0 ? sum / n : sum;
            return $"{point.Item1} ({c.R * 255:0},{c.G * 255:0},{c.B * 255:0})";
        });
        GD.Print($"[light] {term}: {string.Join("  ", parts)}");
    }
}
