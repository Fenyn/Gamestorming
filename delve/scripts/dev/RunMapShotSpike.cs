using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Data;
using Delve.Flow;
using Delve.Presets;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>
/// Rendered smoke test for the run map (scenes/dev/run_map_shot_spike.tscn). Stands the map panel
/// up on its own canvas layer and captures the chart twice: fresh at the entrance with the start
/// row pulsing, then three floors in so the walked trail, the open choices and the party marker
/// are all on screen at once.
///
/// Captures go to user://dev_shots (a run artifact, never repo content); each save prints its
/// globalized OS path. Must run rendered, NOT --headless:
///   godot --path delve res://scenes/dev/run_map_shot_spike.tscn
/// </summary>
public partial class RunMapShotSpike : SpikeBase
{
    private const string OutDir = "user://dev_shots";

    /// <summary>Capture size, matching the other shot spikes' review grid.</summary>
    private const int ShotWidth = 1600;
    private const int ShotHeight = 900;

    /// <summary>Seed search start. The spike walks up from here to the first map that holds a
    /// Lair, so every generated kind is on screen and the shot stays comparable across passes.</summary>
    private const int BaseSeed = 1;

    /// <summary>Floors walked before the mid-run capture.</summary>
    private const int StepsIn = 3;

    /// <summary>The map screen. Assigned in run_map_shot_spike.tscn.</summary>
    [Export] public PackedScene? MapScene { get; set; }

    protected override string Banner => "==================== RUN MAP SHOT SPIKE ====================";

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (MapScene == null)
        {
            AbortFail("[mapshot] MapScene is not assigned - aborting.");
            return;
        }

        foreach (NodeKind kind in System.Enum.GetValues<NodeKind>())
            Check($"{kind} has a tooltip blurb", NodeKindInfo.Get(kind).Blurb.Length > 0);

        var layer = new CanvasLayer();
        AddChild(layer);
        var panel = MapScene.Instantiate<RunMapPanel>();
        layer.AddChild(panel);

        var party = Party.Build(
            PresetCharacters.PlayerId, System.Array.Empty<string>(), new UnlockState(), Party.DefaultLevel);
        var cfg = new RunMapConfig();
        int seed = BaseSeed;
        while (!HasElite(RunMapGenerator.Generate(seed, cfg)))
            seed++;
        GD.Print($"[mapshot] seed {seed} (first from {BaseSeed} with a Lair on the map).");
        var state = RunState.Start(seed, party, cfg);
        DirAccess.MakeDirRecursiveAbsolute(OutDir);

        panel.Render(state);
        await Settle();
        Capture("run_map_start.png");

        for (int i = 0; i < StepsIn; i++)
            Check($"step {i + 1} advances", state.Reachable().Count > 0 && state.Advance(state.Reachable()[0]));

        panel.Render(state);
        await Settle();
        Capture("run_map_mid.png");

        // One shot per remaining stratum, so all three backdrop moods sit side by side.
        for (int stratum = 2; stratum <= FloorThemes.Count; stratum++)
        {
            state.AdvanceStratum();
            panel.Render(state);
            await Settle();
            Capture($"run_map_stratum{stratum}.png");
        }
    }

    private static bool HasElite(RunMap map)
    {
        foreach (var node in map.Nodes)
        {
            if (node.Kind == NodeKind.Elite) return true;
        }
        return false;
    }

    private void Capture(string file)
    {
        Image img = GetViewport().GetTexture().GetImage();
        // hdr_2d viewports hand back linear-space data; convert or the PNG comes out crushed dark.
        img.Convert(Image.Format.Rgba8);
        img.LinearToSrgb();
        img.Resize(ShotWidth, ShotHeight, Image.Interpolation.Bilinear);
        string path = $"{OutDir}/{file}";
        Error err = img.SavePng(path);
        GD.Print($"[mapshot] {file}: {err} ({ProjectSettings.GlobalizePath(path)})");
        Check($"{file} saved", err == Error.Ok);
    }

    /// <summary>Enough rendered frames for the layout to settle and the pulse animation to be
    /// visibly mid-swing.</summary>
    private async Task Settle()
    {
        for (int i = 0; i < 4; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
