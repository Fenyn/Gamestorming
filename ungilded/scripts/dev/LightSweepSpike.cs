using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Autoload;
using Ungilded.Combat;

namespace Ungilded.Dev;

/// <summary>
/// Checks the normal pages of <see cref="NormalFolders"/>: a missing page is a warning, a page whose
/// size differs from its frame fails. Rendered, it stands <see cref="Folder"/>'s first idle frame on
/// a floor and moves one omni light left of it, right, in front and behind, as the camera sees it.
/// It does this without the normal page, with it, and with it and FlipH, saves the twelve stills as
/// one sheet (<see cref="ShotPath"/>, rows in that order, columns left, right, front, behind) and
/// checks that the left light brightens the screen-left half more than the right light does, and
/// the other way round.
/// </summary>
public partial class LightSweepSpike : SpikeBase
{
    private const string HasNormalParameter = "has_normal_tex";

    [Export] public BillboardSpriteAnimator? Sprite { get; set; }
    [Export] public OmniLight3D? Light { get; set; }
    [Export] public Camera3D? Camera { get; set; }
    [Export] public string Folder { get; set; } = "";
    [Export] public string[] NormalFolders { get; set; } = [];
    [Export] public string ShotPath { get; set; } = "";

    /// <summary>Metres from the sprite's feet to the light, along the ground and up.</summary>
    [Export] public float LightDistance { get; set; } = 1.2f;
    [Export] public float LightHeight { get; set; } = 1.0f;

    /// <summary>Height of the frame's middle above the feet, metres, where each tile is centred.</summary>
    [Export] public float TileCentreHeight { get; set; } = 0.6f;
    [Export] public Vector2I TileSize { get; set; } = new(400, 360);
    [Export] public float SettleSeconds { get; set; } = 0.4f;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        CheckPages();
        if (Headless)
        {
            GD.Print("[sweep] rendered only, skipped");
            return;
        }
        if (Sprite == null || Light == null || Camera == null) { Check("stage nodes are bound", false); return; }
        Sprite.ConfigureEnemy(Folder);
        Sprite.Frozen = true;
        // The animator binds the frame's pages before the next draw; the rows below override that.
        await WaitSeconds(SettleSeconds);
        Check($"{Folder} has a normal page", SpriteNormalPages.For(Sprite.Texture) != null);

        var right = Camera.GlobalBasis.X.Slide(Vector3.Up).Normalized();
        var toward = Camera.GlobalBasis.Z.Slide(Vector3.Up).Normalized();
        var places = new (string Name, Vector3 Ground)[] { ("left", -right), ("right", right), ("front", toward), ("behind", -toward) };
        var rows = new (string Name, bool Page, bool Flip)[] { ("no page", false, false), ("page", true, false), ("page flipped", true, true) };

        var sheet = Image.CreateEmpty(TileSize.X * places.Length, TileSize.Y * rows.Length, false, Image.Format.Rgba8);
        var material = (ShaderMaterial)Sprite.MaterialOverride;
        for (int r = 0; r < rows.Length; r++)
        {
            Sprite.FlipH = rows[r].Flip;
            material.SetShaderParameter(HasNormalParameter, rows[r].Page);
            var samples = new Dictionary<string, List<(bool Left, float Luma)>>();
            for (int c = 0; c < places.Length; c++)
            {
                var feet = Sprite.GetParentNode3D().GlobalPosition;
                Light.GlobalPosition = feet + places[c].Ground * LightDistance + Vector3.Up * LightHeight;
                await WaitSeconds(SettleSeconds);
                using var image = Capture();
                var centre = Camera.UnprojectPosition(feet + Vector3.Up * TileCentreHeight);
                var from = new Vector2I((int)centre.X - TileSize.X / 2, (int)centre.Y - TileSize.Y / 2);
                sheet.BlitRect(image, new Rect2I(from, TileSize), new Vector2I(c * TileSize.X, r * TileSize.Y));
                samples[places[c].Name] = Sample(image, rows[r].Flip);
                GD.Print($"[sweep] {rows[r].Name} {places[c].Name}: mean {samples[places[c].Name].Average(s => s.Luma):0.000}");
            }
            CheckSides(rows[r].Name, samples["left"], samples["right"]);
        }
        DirAccess.MakeDirRecursiveAbsolute(ProjectSettings.GlobalizePath(ShotPath.GetBaseDir()));
        Check($"{ShotPath.GetFile()} saved", sheet.SavePng(ShotPath) == Error.Ok);
        GD.Print($"[capture] {ProjectSettings.GlobalizePath(ShotPath)}");
    }

    private void CheckPages()
    {
        int wrongSize = 0;
        foreach (string folder in NormalFolders)
        {
            bool isFile = folder.EndsWith(".png");
            var files = isFile ? new[] { folder.GetFile() } : DirAccess.GetFilesAt(folder);
            string directory = isFile ? folder.GetBaseDir() : folder;
            foreach (string file in files.Where(f => f.EndsWith(".png") && !f.GetBaseName().EndsWith(SpriteNormalPages.Suffix)))
            {
                var frame = ResourceLoader.Load<Texture2D>(directory.PathJoin(file));
                var page = SpriteNormalPages.For(frame);
                if (page == null)
                {
                    GD.PushWarning($"[pages] {directory.PathJoin(file)} has no normal page");
                    continue;
                }
                if (page.GetSize() == frame.GetSize()) continue;
                GD.Print($"[pages] {SpriteNormalPages.PathFor(frame.ResourcePath)} is {page.GetSize()}, frame {frame.GetSize()}");
                wrongSize++;
            }
        }
        Check("normal pages match their frames' size", wrongSize == 0);
    }

    private Image Capture()
    {
        var image = GetViewport().GetTexture().GetImage();
        image.Convert(Image.Format.Rgba8);
        if (ProjectSettings.GetSetting("rendering/viewport/hdr_2d").AsBool()) image.LinearToSrgb();
        return image;
    }

    /// <summary>Screen luma at the centre of each opaque texel of the frame, and whether that texel
    /// is on the screen-left half of the body.</summary>
    private List<(bool Left, float Luma)> Sample(Image image, bool flipped)
    {
        var result = new List<(bool, float)>();
        using var frame = Sprite!.Texture.GetImage();
        frame.Convert(Image.Format.Rgba8);
        int w = frame.GetWidth(), h = frame.GetHeight();
        var used = frame.GetUsedRect();
        float middle = used.Position.X + used.Size.X * 0.5f;
        var right = Camera!.GlobalBasis.X;
        var up = Camera.GlobalBasis.Y;
        float pixel = Sprite.PixelSize;
        for (int v = 0; v < h; v++)
            for (int column = 0; column < w; column++)
            {
                int u = flipped ? w - 1 - column : column;
                if (frame.GetPixel(u, v).A < 0.5f) continue;
                var world = Sprite.GlobalPosition + right * ((column + 0.5f - w * 0.5f) * pixel) + up * ((h * 0.5f - v - 0.5f) * pixel);
                var p = Camera.UnprojectPosition(world);
                if (p.X < 0 || p.Y < 0 || p.X >= image.GetWidth() || p.Y >= image.GetHeight()) continue;
                var c = image.GetPixel((int)p.X, (int)p.Y);
                float screenMiddle = flipped ? w - middle : middle;
                result.Add((column + 0.5f < screenMiddle, 0.299f * c.R + 0.587f * c.G + 0.114f * c.B));
            }
        return result;
    }

    private void CheckSides(string row, List<(bool Left, float Luma)> left, List<(bool Left, float Luma)> right)
    {
        float leftHalf = 0, rightHalf = 0;
        int leftCount = 0, rightCount = 0;
        for (int i = 0; i < Mathf.Min(left.Count, right.Count); i++)
        {
            float d = left[i].Luma - right[i].Luma;
            if (left[i].Left) { leftHalf += d; leftCount++; }
            else { rightHalf -= d; rightCount++; }
        }
        leftHalf /= Mathf.Max(leftCount, 1);
        rightHalf /= Mathf.Max(rightCount, 1);
        GD.Print($"[sweep] {row}: left light gain on left half {leftHalf:0.000}, right light gain on right half {rightHalf:0.000}");
        Check($"{row}: a side light brightens its own side", leftHalf > 0f && rightHalf > 0f);
    }
}
