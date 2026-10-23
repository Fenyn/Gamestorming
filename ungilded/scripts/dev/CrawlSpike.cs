using System.Threading.Tasks;
using Godot;
using Godot.Collections;
using Ungilded.Autoload;
using Ungilded.Story;

namespace Ungilded.Dev;

/// <summary>
/// Checks that every crawl scenery in <see cref="Sceneries"/> covers the screen at every window
/// size in <see cref="WindowSizes"/>, before and after its drift: each layer whose drift is
/// horizontal spans the whole width and height at rest and at full drift. Rendered, it also captures
/// each scenery at rest and at full drift over a sentinel colour and fails on any sentinel pixel,
/// saving the frames to <see cref="ShotDirectory"/> as <c>crawl_&lt;scenery&gt;_&lt;w&gt;x&lt;h&gt;_rest.png</c>
/// and <c>_drift.png</c>.
/// </summary>
public partial class CrawlSpike : SpikeBase
{
    [Export] public Array<PackedScene> Sceneries { get; set; } = new();
    [Export] public Array<Vector2I> WindowSizes { get; set; } = new();
    [Export] public Control? Holder { get; set; }
    [Export] public ColorRect? Sentinel { get; set; }
    [Export] public string ShotDirectory { get; set; } = "";
    [Export] public float SettleSeconds { get; set; } = 0.3f;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        if (Holder == null || Sentinel == null) { Check("stage nodes are bound", false); return; }
        foreach (var windowSize in WindowSizes)
        {
            if (!Headless)
            {
                DisplayServer.WindowSetSize(windowSize);
                await WaitSeconds(SettleSeconds);
            }
            var area = Headless ? ViewportFor(windowSize) : Holder.Size;
            if (Headless)
            {
                Holder.SetAnchorsPreset(Control.LayoutPreset.TopLeft);
                Holder.Size = area;
            }
            GD.Print($"[crawl] window {windowSize.X}x{windowSize.Y}: viewport {area.X}x{area.Y}");
            foreach (var scene in Sceneries)
            {
                var scenery = scene.Instantiate<CrawlScenery>();
                Holder.AddChild(scenery);
                string name = scene.ResourcePath.GetFile().GetBaseName().TrimPrefix("crawl_");
                string label = $"{name} at {area.X}x{area.Y}";
                foreach (float progress in new[] { 0f, 1f })
                {
                    scenery.Progress = progress;
                    CheckLayout(scenery, label, progress, area);
                    if (!Headless)
                    {
                        await WaitSeconds(SettleSeconds);
                        CheckPixels($"{name}_{(int)area.X}x{(int)area.Y}_{(progress == 0f ? "rest" : "drift")}", label, progress);
                    }
                }
                scenery.QueueFree();
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            }
        }
    }

    /// <summary>The stretched viewport the project settings give a window of <paramref name="windowSize"/>:
    /// the design size grown on the wider axis.</summary>
    private static Vector2 ViewportFor(Vector2I windowSize)
    {
        var design = new Vector2(
            ProjectSettings.GetSetting("display/window/size/viewport_width").AsInt32(),
            ProjectSettings.GetSetting("display/window/size/viewport_height").AsInt32());
        float scale = Mathf.Min(windowSize.X / design.X, windowSize.Y / design.Y);
        return (new Vector2(windowSize.X, windowSize.Y) / scale).Floor();
    }

    private void CheckLayout(CrawlScenery scenery, string label, float progress, Vector2 area)
    {
        foreach (var layer in scenery.Layers)
        {
            if (!layer.Tiles || layer.Drift.Y != 0f) continue;
            var rect = new Rect2(layer.Position, layer.Size * layer.Scale);
            bool covers = rect.Position.X <= 0f && rect.End.X >= area.X && rect.Position.Y <= 0f && rect.End.Y >= area.Y;
            Check($"{label} {layer.Name} covers the screen at drift {progress:0}: {rect}", covers);
        }
    }

    private bool IsSentinel(Color c)
    {
        var s = Sentinel!.Color;
        return Mathf.Abs(c.R - s.R) < 0.05f && Mathf.Abs(c.G - s.G) < 0.05f && Mathf.Abs(c.B - s.B) < 0.05f;
    }

    private void CheckPixels(string file, string label, float progress)
    {
        using var image = GetViewport().GetTexture().GetImage();
        image.Convert(Image.Format.Rgba8);
        if (ProjectSettings.GetSetting("rendering/viewport/hdr_2d").AsBool()) image.LinearToSrgb();
        int hits = 0;
        for (int y = 0; y < image.GetHeight(); y += 4)
            for (int x = 0; x < image.GetWidth(); x += 4)
                if (IsSentinel(image.GetPixel(x, y))) hits++;
        Check($"{label} shows no uncovered pixel at drift {progress:0} ({hits} sentinel samples)", hits == 0);
        string path = ShotDirectory.PathJoin($"crawl_{file}.png");
        SaveViewportCapture(path);
    }
}
