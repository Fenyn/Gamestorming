using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Run;
using Delve.Village;
using Godot;

namespace Delve.Dev;

/// <summary>
/// The camp village at every town tier and time of day. Checks that each tier shows exactly the
/// gates in its range, that day-only pieces go in at dusk and that the lamps light only in the
/// evening. With a window it also renders the overview at each tier and time, and each stop at the
/// Hamlet, for comparison with the approved mock frames.
/// </summary>
public partial class VillageShotSpike : SpikeBase
{
    [Export] public PackedScene VillageScene { get; set; } = null!;
    [Export] public float SettleSeconds { get; set; } = 0.6f;

    /// <summary>Stop id and the time it was approved at in the mock.</summary>
    private static readonly (string Stop, CampTimeOfDay Time)[] HamletStops =
    {
        ("hearth", CampTimeOfDay.Morning), ("river", CampTimeOfDay.Afternoon), ("road", CampTimeOfDay.Evening),
        ("east", CampTimeOfDay.Afternoon), ("hill", CampTimeOfDay.Evening), ("delve", CampTimeOfDay.Evening),
    };

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var layer = new CanvasLayer();
        AddChild(layer);
        var stage = VillageScene.Instantiate<VillageStage>();
        layer.AddChild(stage);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        CheckTiers(stage);
        CheckTime(stage);
        CheckCamera(stage);
        if (DisplayServer.GetName() != "headless") await Shots(stage);

        layer.QueueFree();
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private void CheckTiers(VillageStage stage)
    {
        var gates = GetTree().GetNodesInGroup(TierGate.Group).OfType<TierGate>().ToList();
        Check("village has tier gates", gates.Count > 0);
        stage.ApplyTime(CampTimeOfDay.Morning);
        foreach (var tier in new[] { TownTier.Camp, TownTier.Outpost, TownTier.Hamlet })
        {
            stage.ApplyTier(tier);
            int t = (int)tier;
            Check($"{tier}: every gate in range shows, every other hides", gates.All(g => g.Visible == (g.From <= t && t <= g.To)));
            int pieces = gates.Where(g => g.Visible).Sum(g => g.GetChildCount());
            GD.Print($"[village] {tier}: {gates.Count(g => g.Visible)} gates open, {pieces} gated pieces");
        }
    }

    private void CheckTime(VillageStage stage)
    {
        stage.ApplyTier(TownTier.Hamlet);
        var lamps = GetTree().GetNodesInGroup(EveningLight.Group).OfType<EveningLight>().ToList();
        var dayOnly = GetTree().GetNodesInGroup(TierGate.Group).OfType<TierGate>().Where(g => g.DayOnly).ToList();
        Check("village has evening lamps", lamps.Count > 0);
        stage.ApplyTime(CampTimeOfDay.Afternoon);
        Check("lamps are dark by day", lamps.All(l => l.LightEnergy == 0));
        Check("day-only pieces are out by day", dayOnly.All(g => g.Visible));
        stage.ApplyTime(CampTimeOfDay.Evening);
        Check("lamps are lit in the evening", lamps.All(l => l.LightEnergy > 0));
        Check("day-only pieces are in by evening", dayOnly.All(g => !g.Visible));
        stage.ApplyTime(CampTimeOfDay.Morning);
        Check("morning puts the lamps out again", lamps.All(l => l.LightEnergy == 0));
    }

    private static readonly string[] Roster =
    {
        "player", "elara", "tharr", "fenwick", "raven", "thistle", "arkus", "aldric", "spore",
        "josen", "grub", "sera", "oskar", "hazel", "wynn", "vasska", "hilde", "flick",
    };

    private void CheckCamera(VillageStage stage)
    {
        Check("the village opens on the hearth", stage.Camera.Stop?.Id == "hearth");
        stage.StepStop(1);
        Check("E steps east to the hill", stage.Camera.Stop?.Id == "hill");
        for (int i = 0; i < 6; i++) stage.StepStop(-1);
        Check("Q stops at the west end, the river", stage.Camera.Stop?.Id == "river");

        var next = new InputEventAction { Action = "menu_next", Pressed = true };
        stage.Browsing = false;
        stage._UnhandledInput(next);
        Check("E does nothing while an overlay is open", stage.Camera.Stop?.Id == "river");
        stage.Browsing = true;
        stage._UnhandledInput(next);
        Check("E steps again once the overlay closes", stage.Camera.Stop?.Id == "hearth");

        string pressed = "";
        stage.StationPressed += id => pressed = id;
        foreach (var station in stage.Stations) station.EmitSignal(VillageStation.SignalName.Pressed, station.Id);
        Check("every station reports its click through the stage", pressed == stage.Stations.Last().Id && stage.Stations.Length == 3);
        Check("the Delve trail is a station", stage.Stations.Any(s => s.Id == "delve"));
    }

    private async Task Shots(VillageStage stage)
    {
        await Strip(stage, "player", "hearth", 8, 0.08f);
        await Strip(stage, "grub", "river", 8, 0.12f);
        await Strip(stage, "flick", "road", 8, 0.1f);
        foreach (var tier in new[] { TownTier.Camp, TownTier.Outpost, TownTier.Hamlet })
            foreach (var time in new[] { CampTimeOfDay.Morning, CampTimeOfDay.Afternoon, CampTimeOfDay.Evening })
                await Shot(stage, tier, time, "overview");
        foreach (var (stop, time) in HamletStops)
            await Shot(stage, TownTier.Hamlet, time, stop);
        await Shot(stage, TownTier.Camp, CampTimeOfDay.Morning, "hearth");
        await Shot(stage, TownTier.Outpost, CampTimeOfDay.Afternoon, "hearth");
    }

    private async Task Shot(VillageStage stage, TownTier tier, CampTimeOfDay time, string stopId)
    {
        stage.ApplyTier(tier);
        stage.Residents.Place(Roster, time, tier);
        stage.ApplyTime(time);
        if (stage.StopFor(stopId) is not { } stop)
        {
            Check($"stop {stopId} exists", false);
            return;
        }
        stage.FrameStop(stop);
        await ToSignal(GetTree().CreateTimer(SettleSeconds), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        string name = $"village_{stopId}_{tier.ToString().ToLowerInvariant()}_{time.ToString().ToLowerInvariant()}";
        Check($"{name} saved", SaveViewportCapture($"user://dev_shots/{name}.png", new Vector2I(1920, 1080)) == Error.Ok);
    }

    /// <summary>A row of frames cropped round one resident at the Hamlet by day, to show it moves through whole clips.</summary>
    private async Task Strip(VillageStage stage, string residentId, string stopId, int frames, float seconds)
    {
        stage.ApplyTier(TownTier.Hamlet);
        stage.Residents.Place(Roster, CampTimeOfDay.Morning, TownTier.Hamlet);
        stage.ApplyTime(CampTimeOfDay.Morning);
        stage.FrameStop(stage.StopFor(stopId)!);
        await ToSignal(GetTree().CreateTimer(SettleSeconds), SceneTreeTimer.SignalName.Timeout);
        var figure = stage.Residents.Figures.FirstOrDefault(f => f.Id == residentId);
        if (figure == null)
        {
            Check($"strip: {residentId} is placed", false);
            return;
        }
        // Start on a work clip, so the strip shows the work moving.
        for (int wait = 0; wait < 600 && figure.Routine!.Pose != ResidentPose.Work; wait++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check($"strip: {residentId} gets to work", figure.Routine!.Pose == ResidentPose.Work);
        var cell = new Vector2I(240, 240);
        using var strip = Image.CreateEmpty(cell.X * frames, cell.Y, false, Image.Format.Rgba8);
        for (int i = 0; i < frames; i++)
        {
            await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            using var image = GetViewport().GetTexture().GetImage();
            image.Convert(Image.Format.Rgba8);
            if (ProjectSettings.GetSetting("rendering/viewport/hdr_2d").AsBool()) image.LinearToSrgb();
            var scale = new Vector2(image.GetWidth(), image.GetHeight()) / stage.Viewport.Size;
            var at = stage.Camera.UnprojectPosition(figure.GlobalPosition + Vector3.Up * 0.8f) * scale;
            if (i == 0) Check($"strip: {residentId} is in frame", new Rect2(Vector2.Zero, new Vector2(image.GetWidth(), image.GetHeight())).HasPoint(at));
            var corner = new Vector2I((int)at.X - cell.X / 2, (int)at.Y - cell.Y / 2)
                .Clamp(Vector2I.Zero, new Vector2I(image.GetWidth(), image.GetHeight()) - cell);
            strip.BlitRect(image, new Rect2I(corner, cell), new Vector2I(i * cell.X, 0));
        }
        string directory = OS.GetEnvironment("DELVE_SHOT_DIRECTORY");
        string path = directory.Length > 0 ? directory.PathJoin($"village_strip_{residentId}.png") : $"user://dev_shots/village_strip_{residentId}.png";
        Check($"strip {residentId} saved", strip.SavePng(path) == Error.Ok);
    }
}
